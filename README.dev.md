# Locaweb Platform

## Overview

This repository contains the Locaweb Internal Developer Platform, including cluster provisioning, platform add-ons, and application blueprints.

## Layout

- `terraform/` Terraform root stack for cluster provisioning
- `modules/` Reusable Terraform modules (e.g., `cloudstack-k3s`)
- `charts/` Helm charts for platform and workloads
- `blueprints/` Example application blueprints
- `schemas/` JSON schemas for blueprint values
- `docs/` Design and operational documentation
- `tools/` Helper scripts

## Tooling

- Terraform/OpenTofu: `~> 1.6.0`
- CloudStack provider: `~> 0.5.0`
- Local tools: `curl`, `jq`, `kubectl`, `ssh`

## CloudStack Constraints

- Per-cluster network is created from a predefined network offering.
- Control planes default to `large`.
- Agents default to `xlarge` with at least 4 nodes.

## Getting Started

1. Review `docs/DESIGN.md` for architecture and requirements.
2. Copy `terraform/terraform.tfvars.example` to `terraform/terraform.tfvars` and customize.
3. Provide sensitive inputs via environment variables:
   ```bash
   export TF_VAR_cloudstack_api_key="your-api-key"
   export TF_VAR_cloudstack_secret_key="your-secret-key"
   ```
4. Run Terraform or OpenTofu to provision the cluster:
   ```bash
   cd terraform
   terraform init
   terraform plan
   terraform apply
   ```

## Sensitive Variables

Sensitive inputs (API keys, secrets) must be provided via `TF_VAR_*` environment variables rather than in `.tfvars` files. This prevents accidental commits of credentials to version control.

| Variable | Environment Variable |
|----------|---------------------|
| `cloudstack_api_key` | `TF_VAR_cloudstack_api_key` |
| `cloudstack_secret_key` | `TF_VAR_cloudstack_secret_key` |

## CI and Module Usage

If this repository is used as a module or executed in CI/CD, avoid writing kubeconfig and SSH keys to the repo. See `docs/DESIGN.md` for recommended handling patterns (sensitive outputs, temp paths, or external secrets managers).

## Addons

Required addons are installed as separate Helm releases to keep one namespace per component.
CloudStack CCM/CSI are installed from local charts in `charts/cloudstack-ccm` and `charts/cloudstack-csi`.
Default cert-manager ClusterIssuer is installed from `charts/cert-manager-issuers`.
K3s upgrades are handled by system-upgrade-controller with plans in `charts/k3s-upgrade-plans`.

## k3s Airgap Install

k3s artifacts are downloaded once on the Terraform host and uploaded to nodes before install.

