# Locaweb Platform - Design Document (Draft)

## Objective

Design a "lite" Internal Developer Platform for CloudStack-based customers that is faster to provision, lighter on resources, simpler to understand, and fully self-hosted (no centralized dependencies).

## Goals

- **Faster provisioning:** Reduce time-to-ready with fewer components and opinionated defaults.
- **Lower overhead:** Minimize control plane size and reduce auxiliary services.
- **Simple mono-repo:** Consolidate platform and blueprint logic into a single repository.
- **Simpler cluster bootstrap:** Avoid external Ansible playbooks for k3s; use a simpler provisioning path.
- **Self-hosted only:** No external dependencies managed by the provider (e.g., external Keycloak).
- **DR recovery flag:** Single toggle to restore from an external S3 DR bucket.
- **Blueprint compatibility:** Preserve blueprint semantics as much as possible.

## Non-Goals

- Multi-cloud support in the lite offering.
- Feature completeness beyond the lite scope.
- Providing a hosted control plane or central shared services.
- Migration tooling from any predecessor platform.

## Target Users

Customers who want to run a CloudStack-based Kubernetes platform with minimal operational overhead.

## Assumptions

- CloudStack is the target infrastructure.
- A single control plane is acceptable as the default; HA is optional.
- External S3 bucket is available for DR.

## Architecture Overview

Two logical layers are used, implemented in a single repository:


1. **Platform Layer**
   - Minimal Terraform to provision a single Kubernetes cluster on CloudStack.
   - Small addon profile focused on cluster basics.
2. **Application Blueprint Layer**
   - Blueprints (values) and Helm charts for workload rendering.
   - Argo CD ApplicationSet can be the deployment pattern if GitOps is desired.

## Required Addons (Lite Default)

The following are required for the platform to function:

- **CNI:** Cilium for pod networking.
- **Cloud Controller:** CloudStack CCM (ckp) for Service load balancers.
- **CSI:** CloudStack CSI for persistent volumes.
- **Ingress:** Traefik for HTTP entrypoints.
- **Certificates:** cert-manager + cluster issuers for TLS automation.
- **Reboots:** kured for safe node reboots.
- **Backup/DR:** k8up controller + CRDs to enable the `recovery` flag workflows.

## Observability (Lightweight, Required)

Provide basic metrics, logs, and baked-in alerting (Slack/Teams) with minimal resource use:

- **Metrics:** VictoriaMetrics single-node (vmsingle) or similar, with vmagent scraping.
- **Alerting:** vmalert + Alertmanager with preconfigured Slack/Teams receivers.
- **Logs:** Loki with promtail or Grafana Alloy for lightweight log shipping.
- **Dashboards:** Grafana (single instance, no operator) with a small default set.

Notes:

- Prefer a minimal stack over kube-prometheus-stack.
- Keep retention small by default; allow opt-in expansion.
- Include a compact set of default alerts (node readiness, storage pressure, cert expiry, backup failures, ingress errors).

## Optional Addons (Opt-In)

- **GitOps:** Argo CD + ApplicationSet for blueprint sync.
- **Secrets:** Sealed Secrets or External Secrets when external stores are required.
- **Policy:** Kyverno for policy enforcement when needed.
- **Autoscaling:** KEDA for event-driven workloads.
- **Security Scanning:** Trivy operator.
- **Datastores/Operators:** CNPG, Percona XtraDB, Percona MongoDB, ECK, Dragonfly, RabbitMQ.
- **DNS Automation:** External DNS for managed DNS providers.

## Self-Hosted Dependencies

- **Auth:** Replace external Keycloak with in-cluster IdP (Dex or Keycloak-in-cluster).
- **Secrets:** Prefer Kubernetes native secrets or sealed secrets in-cluster.

## DR Recovery Flag

Introduce a single `recovery` flag at platform or blueprint level.

Expected behavior:

- When `recovery=true`, operators and jobs switch to restore mode using the external S3 bucket.
- Applies to: k8up volumes, CloudNativePG, Percona XtraDB, ECK, Percona MongoDB (via jobs/cronjobs).

## Mono-Repo Layout (Proposed)

```
.
├── platform/            # Terraform and cluster provisioning
├── charts/              # Helm charts for platform and workloads
├── blueprints/          # Example blueprints (values)
├── schemas/             # JSON schemas for blueprints
├── docs/                # Design and operational docs
└── tools/               # Helper scripts
```

## Tooling Compatibility

- Terraform/OpenTofu: target `~> 1.6.0` for compatibility with OpenTofu 1.6.x.

## Provisioning Flow (High Level)

1. Provision a minimal Kubernetes cluster on CloudStack.
2. Install the minimal addon profile via Terraform + Helm provider.
3. Apply blueprints via Helm/Argo CD.
4. If `recovery=true`, bootstrap restore workflows from the DR bucket.

## CloudStack Offerings and Network

- A dedicated CloudStack network is created per cluster using a predefined network offering.
- Instance offerings are constrained to known sizes (micro, small, medium, large, xlarge, 2xlarge, 4xlarge).
- Control planes should use at least `large`.
- Agents should use at least `xlarge`.
- Agent count must be at least 4; control planes must be 1 or 3.
- Instance IPs are allocated by CloudStack; static IPs are not used.

## Helm Coordination

Terraform generates a kubeconfig from the control plane and uses it for Helm releases:

- k3s token is generated automatically.
- k3s installs via uploaded airgap artifacts and writes kubeconfig on the control plane.
- Terraform fetches kubeconfig over SSH and uses it for Helm installs.
- Terraform waits for all nodes (control planes + agents) to be Ready before installing addons.

## Sensitive Artifacts Handling

The default flow writes generated kubeconfig and SSH key material locally. This is convenient but has risks:

- Files can be accidentally committed unless excluded.
- When used as a module, file paths resolve under the caller's workspace, which may be unexpected.
- CI/CD runs need a deterministic and safe location for artifacts.

Recommended alternatives:

1) **Configurable output paths (preferred for local use)**
   - Make kubeconfig and SSH key paths configurable (e.g., `kubeconfig_output_path`, `ssh_private_key_path`).
   - Default to a temp or tool-managed directory (e.g., `$TF_DATA_DIR`, `/tmp`).
   - Ensure `.gitignore` excludes any generated location if it resides in the repo.

2) **Sensitive outputs + external storage (preferred for CI and module usage)**
   - Expose SSH private key as a `sensitive` output.
   - In CI, write kubeconfig and SSH key to ephemeral workspace files and store them as short-lived artifacts or inject directly into Helm/Kubernetes providers.
   - For module use, the parent stack consumes outputs and decides where to persist (or avoids persistence entirely).

3) **Managed secrets backend**
   - Store kubeconfig and SSH key in a secrets manager (Vault, AWS Secrets Manager, etc.).
   - The CI pipeline or parent module fetches them at runtime and avoids writing to disk when possible.

## k3s Upgrades (System Upgrade Controller)

Use system-upgrade-controller to reconcile k3s version changes:

- `k3s_version` is pinned and used for initial install and ongoing upgrades.
- All nodes are labeled `k3s-upgrade=true` by default to ensure new nodes are always covered.
- Upgrade Plans are managed by Terraform and target control planes and agents separately.

## k3s Provisioning (Simplified)

Goal: remove external Ansible playbooks and use a simpler, more direct bootstrap.

Preferred approach:

- **Cloud-init + airgap artifacts:** Use instance user-data to write config, then upload airgap artifacts and run the install script via SSH.
- **Single control plane default:** Agents join using a shared token and control plane IP.
- **Optional HA:** Add extra control planes and an internal load balancer only when enabled.

Implementation notes:

- Keep configuration in Terraform variables and render into user-data templates.
- Use a local cloud-init template for control planes and agents (no external repo dependency).
- Download k3s artifacts once, then upload to all nodes.
- Install k3s with `INSTALL_K3S_SKIP_DOWNLOAD=true` to avoid external fetches.
- Artifact downloads use the official k3s release URLs and run on the Terraform host.
- SSH connectivity to all nodes is required for artifact upload and installation.

### Cloud-Init Template Sketch

Control plane user-data:

```yaml
#cloud-config
write_files:
  - path: /etc/rancher/k3s/config.yaml
    permissions: "0600"
    content: |
      token: ${K3S_TOKEN}
      tls-san:
        - ${CONTROL_PLANE_IP}
      node-taint:
        - "node-role.kubernetes.io/control-plane=true:NoSchedule"
        - "CriticalAddonsOnly=true:NoExecute"
      disable:
        - servicelb
        - traefik
        - local-storage
      disable-kube-proxy: true
      disable-cloud-controller: true
      disable-network-policy: true
      embedded-registry: true
      flannel-backend: none
      kube-apiserver-arg:
        - oidc-issuer-url=${OIDC_ISSUER_URL}
        - oidc-client-id=${OIDC_CLIENT_ID}
        - oidc-username-claim=preferred_username
        - oidc-username-prefix=oidc:
        - request-timeout=300s
```

Agent user-data:

```yaml
#cloud-config
write_files:
  - path: /etc/rancher/k3s/config.yaml
    permissions: "0600"
    content: |
      server: https://${CONTROL_PLANE_IP}:6443
      token: ${K3S_TOKEN}
      node-label:
        - "node-role.kubernetes.io/worker=true"
        - "k3s-upgrade=true"
      node-taint:
        - "node.cilium.io/agent-not-ready=true:NoExecute"
      flannel-backend: none
```

Flags and conventions:

- Disable embedded ServiceLB and Traefik to use the platform Traefik ingress and CloudStack CCM.
- Use `flannel-backend=none` when Cilium is the CNI.
- Configure control plane taints by default; allow override for single-node setups.
- Keep all parameters templated in Terraform to avoid external dependencies.
- OIDC values may be left empty until the IdP is deployed; k3s will still start with OIDC disabled.

### API Load Balancer (Default)

The API load balancer is always provisioned and used for agent joins:

- Use `api_lb_allowed_cidrs` to restrict API access.
- Set `control_plane_ips` and `control_plane_count` to scale control planes.

### Ingress Public IP (Default)

Ingress always provisions a public IP and opens `80/443`:

- Use `ingress_allowed_cidrs` to restrict HTTP/HTTPS access.
- The reserved IP is wired to Traefik `service.spec.loadBalancerIP`.

### PROXY Protocol (Required)

Enable PROXY protocol on Traefik entrypoints to preserve the real client IP:

- `ingress_proxy_protocol_enabled=true` enables PROXY protocol parsing.
- Set `ingress_proxy_protocol_trusted_ips` to restrict trusted sources; leave empty to allow all.

### Addon Installation Flow (Initial)

- Use Terraform Helm provider to install each required addon as a separate release.
- Each addon runs in its own namespace to simplify isolation and policy controls.
- Traefik is wired with `service.spec.loadBalancerIP` using the allocated ingress IP.

Baseline configuration defaults:

- **Cilium:** operator replicas = 1 with minimal resource requests/limits.
- **kured:** maintenance window `5:00-6:59 UTC`, `period=15m`, tolerations for control plane nodes.
- **k8up:** operator timezone set to UTC with small resource requests.
- **CloudStack CCM/CSI:** installed via local charts in `charts/cloudstack-ccm` and `charts/cloudstack-csi`.
- **cert-manager issuers:** local chart `charts/cert-manager-issuers` installs a default ACME ClusterIssuer.

## Risks

- Reduced observability may impact incident response.
- Fewer HA guarantees when running single control plane.
- Customers may expect features outside the lite scope.

## Open Questions

- Required HA level for control plane and etcd.
- Which optional addons should be enabled by default.
- Whether to include Argo CD by default for GitOps.
- Preferred in-cluster IdP choice.
