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
- AWS provider: `~> 6.28.0`
- Local tools: `curl`, `jq`, `kubectl`, `ssh`

## CloudStack Constraints

- Per-cluster network is created from a predefined network offering.
- Control planes default to `large`.
- Agents default to `xlarge` with at least 4 nodes.

## Getting Started

1. Review `docs/DESIGN.md` for architecture and requirements.
2. Copy `terraform/terraform.tfvars.example` to `terraform/terraform.tfvars` and customize.
3. Set environment variables for provider authentication:

   ```bash
   # CloudStack provider
   export CLOUDSTACK_API_URL="https://painel-cloud.locaweb.com.br/client/api"
   export CLOUDSTACK_API_KEY="your-api-key"
   export CLOUDSTACK_SECRET_KEY="your-secret-key"

   # AWS provider
   export AWS_ACCESS_KEY_ID="your-aws-access-key-id"
   export AWS_SECRET_ACCESS_KEY="your-aws-secret-access-key"
   ```

4. Run Terraform or OpenTofu to provision the cluster:

   ```bash
   cd terraform
   terraform init
   terraform plan \
     -var="cloudstack_ccm_api_key=your-ccm-api-key" \
     -var="cloudstack_ccm_secret_key=your-ccm-secret-key"
   terraform apply \
     -var="cloudstack_ccm_api_key=your-ccm-api-key" \
     -var="cloudstack_ccm_secret_key=your-ccm-secret-key"
   ```

## Credential Management

### Provider Credentials (Environment Variables)

Provider credentials are read from standard environment variables. This approach:

- Leverages native provider authentication mechanisms.
- Works consistently across local development and CI/CD pipelines.
- Allows credentials to be injected from external sources (Vault, CI secrets, etc.).

| Provider    | Environment Variable       | Purpose                          |
| ----------- | -------------------------- | -------------------------------- |
| CloudStack  | `CLOUDSTACK_API_URL`       | CloudStack API endpoint          |
| CloudStack  | `CLOUDSTACK_API_KEY`       | CloudStack provider auth         |
| CloudStack  | `CLOUDSTACK_SECRET_KEY`    | CloudStack provider auth         |
| AWS         | `AWS_ACCESS_KEY_ID`        | AWS provider auth                |
| AWS         | `AWS_SECRET_ACCESS_KEY`    | AWS provider auth                |

### CCM Credentials (Command-Line Variables)

CloudStack Cloud Controller Manager (CCM) requires separate credentials passed via `-var` parameters:

| Variable                    | Purpose                              |
| --------------------------- | ------------------------------------ |
| `cloudstack_ccm_api_key`    | CloudStack API key for CCM           |
| `cloudstack_ccm_secret_key` | CloudStack secret key for CCM        |

These credentials are used by the CCM running inside the Kubernetes cluster and may differ from the provider credentials (e.g., a dedicated service account with restricted permissions).

## CI and Module Usage

If this repository is used as a module or executed in CI/CD, avoid writing kubeconfig and SSH keys to the repo. See `docs/DESIGN.md` for recommended handling patterns (sensitive outputs, temp paths, or external secrets managers).

## Addons

Required addons are installed as separate Helm releases to keep one namespace per component.
CloudStack CCM/CSI are installed from local charts in `charts/cloudstack-ccm` and `charts/cloudstack-csi`.
Default cert-manager ClusterIssuer is installed from `charts/cert-manager-issuers`.
K3s upgrades are handled by system-upgrade-controller with plans in `charts/k3s-upgrade-plans`.

## k3s Airgap Install

k3s artifacts are downloaded once on the Terraform host and uploaded to nodes before install.
