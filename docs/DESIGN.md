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

## k3s Upgrades (System Upgrade Controller)

Use system-upgrade-controller to reconcile k3s version changes:

- `k3s_version` is pinned and used for initial install and ongoing upgrades.
- All nodes are labeled `k3s-upgrade=true` by default to ensure new nodes are always covered.
- Upgrade Plans are managed by Terraform and target control planes and agents separately.

## k3s Provisioning (Simplified)

Goal: remove external Ansible playbooks and use a simpler, more direct bootstrap.

Preferred approach:

- **Cloud-init + k3s install script:** Use instance user-data to install k3s on control plane and agents with `INSTALL_K3S_EXEC` flags.
- **Single control plane default:** Agents join using a shared token and control plane IP.
- **Optional HA:** Add extra control planes and an internal load balancer only when enabled.

Implementation notes:

- Keep configuration in Terraform variables and render into user-data templates.
- Use a local cloud-init template for control planes and agents (no external repo dependency).
- Avoid SSH-based orchestration as the default path; keep it as a fallback only if needed.

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
      disable:
        - servicelb
        - traefik
      flannel-backend: none
runcmd:
  - "curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC='server' sh -"
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
      flannel-backend: none
runcmd:
  - "curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC='agent' sh -"
```

Flags and conventions:

- Disable embedded ServiceLB and Traefik to use the platform Traefik ingress and CloudStack CCM.
- Use `flannel-backend=none` when Cilium is the CNI.
- Configure control plane taints by default; allow override for single-node setups.
- Keep all parameters templated in Terraform to avoid external dependencies.

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
