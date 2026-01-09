# Keycloak-Config-CLI: Group Management Conclusions

## Overview

This document summarizes findings about managing Keycloak groups, subgroups, members, and roles using keycloak-config-cli and the Keycloak Admin API, particularly in an Argo CD GitOps context.

---

## 1. Group Membership Model

### Membership is Managed at the User Level, Not Group Level

keycloak-config-cli manages group membership through **user imports**, not group definitions:

```json
{
  "users": [
    {
      "username": "alice",
      "groups": ["/Engineering/Backend"]
    }
  ]
}
```

**Limitation**: There is no `members` field on group configuration. You cannot define "these users belong to this group" at the group level.

### Full Sync at User Level

When a user is imported, their group memberships are fully synchronized:

- Groups in config but not assigned → added
- Groups assigned but not in config → removed

---

## 2. Subgroups and Membership Inheritance

### Membership is Direct, Not Inherited

| User is member of | Member of `/Parent`? | Member of `/Parent/Child`? |
| ----------------- | -------------------- | -------------------------- |
| `/Parent`         | Yes                  | No                         |
| `/Parent/Child`   | **No**               | Yes                        |

**Key point**: Being a member of `/Parent/Child` does NOT make you a member of `/Parent`.

### Roles ARE Inherited

While membership is direct, roles cascade down the group hierarchy:

```text
/Engineering              → realmRoles: ["view-dashboards"]
  └── /Backend            → realmRoles: ["deploy-api"]
```

A user in `/Engineering/Backend` gets both `view-dashboards` and `deploy-api` roles.

### Subgroup Deletion Behavior

When a subgroup is deleted:

- Users lose their membership in that subgroup
- Users lose roles inherited through that subgroup
- Users are NOT automatically moved to the parent group

---

## 3. Realm Roles vs Client Roles

| Aspect         | Realm Roles                | Client Roles                       |
| -------------- | -------------------------- | ---------------------------------- |
| Scope          | Global across realm        | Scoped to specific client          |
| Token location | `realm_access.roles`       | `resource_access.<client>.roles`   |
| Use case       | Organization-wide identity | Application-specific permissions   |

Both can be assigned at any group level and inherit downward.

### Example Configuration

```json
{
  "groups": [
    {
      "name": "Engineering",
      "realmRoles": ["developer"],
      "clientRoles": {
        "grafana": ["viewer"],
        "argocd": ["readonly"]
      },
      "subGroups": [
        {
          "name": "Leads",
          "clientRoles": {
            "grafana": ["admin"],
            "argocd": ["admin"]
          }
        }
      ]
    }
  ]
}
```

---

## 4. Token Claims and Downstream Systems

### Default Behavior

| System       | Default Claim | Sees Role Inheritance? |
| ------------ | ------------- | ---------------------- |
| oauth2-proxy | `groups`      | No                     |
| Grafana      | `groups`      | No                     |
| Argo CD      | `groups`      | No                     |
| Kubernetes   | `groups`      | No                     |

**Important**: Most systems use the `groups` claim by default, which shows direct membership only (no inheritance).

### To Use Role Inheritance

Configure systems to read from `realm_access.roles` instead of `groups`:

**Grafana**:

```ini
role_attribute_path = contains(realm_access.roles[*], 'admin') && 'Admin' || 'Viewer'
```

**Kubernetes**:

```yaml
--oidc-groups-claim=realm_access.roles
```

---

## 5. Declarative vs Imperative Operations

### keycloak-config-cli is Declarative

You define the complete desired state. With `import.managed.group=full`:

- Groups not in config are **deleted**
- You must list all subgroups to preserve them

### Managed Mode Options

| Mode        | Add Groups | Update Groups | Delete Groups          |
| ----------- | ---------- | ------------- | ---------------------- |
| `full`      | Yes        | Yes           | Yes (if not in config) |
| `no-delete` | Yes        | Yes           | No                     |

---

## 6. Recommended Patterns

### Adding/Updating Subgroups: Use keycloak-config-cli

With `no-delete` mode, you can add or update without knowledge of other subgroups:

```bash
IMPORT_MANAGED_GROUP=no-delete
```

```json
{
  "realm": "myRealm",
  "groups": [
    {
      "name": "Engineering",
      "subGroups": [
        {
          "name": "Backend",
          "realmRoles": ["developer"]
        }
      ]
    }
  ]
}
```

### Deleting Subgroups: Use Direct API

keycloak-config-cli cannot delete a single subgroup without knowledge of others. Use the API:

```bash
curl -X DELETE -H "Authorization: Bearer $TOKEN" \
  "$KEYCLOAK_URL/admin/realms/$REALM/groups/$SUBGROUP_ID"
```

---

## 7. Service Account Authentication

Use client credentials grant for machine-to-machine auth:

```bash
TOKEN=$(curl -s -X POST "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "grant_type=client_credentials" \
  | jq -r '.access_token')
```

**Required roles** for group management: `realm-management/manage-users`

---

## 8. Argo CD Integration

### PostSync Hook: Add/Update Subgroup

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: sync-subgroup
  annotations:
    argocd.argoproj.io/hook: PostSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: keycloak-config-cli
        image: adorsys/keycloak-config-cli:latest
        env:
        - name: KEYCLOAK_URL
          value: "https://keycloak.example.com"
        - name: KEYCLOAK_USER
          valueFrom:
            secretKeyRef:
              name: keycloak-admin
              key: username
        - name: KEYCLOAK_PASSWORD
          valueFrom:
            secretKeyRef:
              name: keycloak-admin
              key: password
        - name: IMPORT_MANAGED_GROUP
          value: "no-delete"
        - name: IMPORT_FILES_LOCATIONS
          value: "/config/*"
        volumeMounts:
        - name: config
          mountPath: /config
      volumes:
      - name: config
        configMap:
          name: subgroup-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: subgroup-config
data:
  realm.json: |
    {
      "realm": "myRealm",
      "groups": [
        {
          "name": "Engineering",
          "subGroups": [
            {
              "name": "Backend",
              "realmRoles": ["developer"],
              "clientRoles": {
                "grafana": ["editor"],
                "argocd": ["readonly"]
              }
            }
          ]
        }
      ]
    }
```

### PostDelete Hook: Remove Subgroup

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: cleanup-subgroup
  annotations:
    argocd.argoproj.io/hook: PostDelete
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: cleanup
        image: curlimages/curl:8.5.0
        env:
        - name: KEYCLOAK_URL
          value: "https://keycloak.example.com"
        - name: REALM
          value: "myRealm"
        - name: PARENT_GROUP
          value: "Engineering"
        - name: SUBGROUP_TO_DELETE
          value: "Backend"
        - name: CLIENT_ID
          valueFrom:
            secretKeyRef:
              name: keycloak-sa
              key: client-id
        - name: CLIENT_SECRET
          valueFrom:
            secretKeyRef:
              name: keycloak-sa
              key: client-secret
        command:
        - /bin/sh
        - -c
        - |
          set -e

          TOKEN=$(curl -sf -X POST "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" \
            -d "client_id=$CLIENT_ID" \
            -d "client_secret=$CLIENT_SECRET" \
            -d "grant_type=client_credentials" \
            | jq -r '.access_token')

          PARENT_ID=$(curl -sf -H "Authorization: Bearer $TOKEN" \
            "$KEYCLOAK_URL/admin/realms/$REALM/groups?search=$PARENT_GROUP&exact=true" \
            | jq -r '.[0].id')

          SUBGROUP_ID=$(curl -sf -H "Authorization: Bearer $TOKEN" \
            "$KEYCLOAK_URL/admin/realms/$REALM/groups/$PARENT_ID/children" \
            | jq -r --arg name "$SUBGROUP_TO_DELETE" '.[] | select(.name == $name) | .id')

          if [ -n "$SUBGROUP_ID" ] && [ "$SUBGROUP_ID" != "null" ]; then
            curl -sf -X DELETE -H "Authorization: Bearer $TOKEN" \
              "$KEYCLOAK_URL/admin/realms/$REALM/groups/$SUBGROUP_ID"
            echo "Deleted subgroup $SUBGROUP_TO_DELETE"
          fi
```

---

## 9. Summary Table

| Operation               | Tool                              | Notes                     |
| ----------------------- | --------------------------------- | ------------------------- |
| Add subgroup with roles | keycloak-config-cli (`no-delete`) | Declarative, idempotent   |
| Update subgroup         | keycloak-config-cli (`no-delete`) | Preserves other subgroups |
| Delete single subgroup  | Direct API                        | Imperative, surgical      |
| Add users to group      | keycloak-config-cli (user import) | Full sync per user        |
| Remove users from group | keycloak-config-cli or API        | Via user import or API    |
| Clear all group members | Direct API (pre-import script)    | Not natively supported    |

---

## 10. Key Files in keycloak-config-cli

| File                             | Purpose                                  |
| -------------------------------- | ---------------------------------------- |
| `GroupImportService.java`        | Group creation, update, deletion logic   |
| `GroupRepository.java`           | Keycloak API calls for groups            |
| `UserImportService.java:177-224` | User group membership sync               |
| `ImportConfigProperties.java`    | Managed mode configuration               |

---

## References

- keycloak-config-cli: <https://github.com/adorsys/keycloak-config-cli>
- Keycloak Admin REST API: <https://www.keycloak.org/docs-api/latest/rest-api/>
- Argo CD Resource Hooks: <https://argo-cd.readthedocs.io/en/stable/user-guide/resource_hooks/>
