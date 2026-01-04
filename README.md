# Locaweb Platform

## Overview

This repository contains the Locaweb Internal Developer Platform, including cluster provisioning, platform add-ons, and application blueprints.

## Layout

- `platform/` Terraform for CloudStack provisioning and cluster bootstrap
- `charts/` Helm charts for platform and workloads
- `blueprints/` Example application blueprints
- `schemas/` JSON schemas for blueprint values
- `docs/` Design and operational documentation
- `tools/` Helper scripts

## Tooling

- Terraform/OpenTofu: `~> 1.6.0`
- CloudStack provider: `~> 0.5.0`
- Local tools: `curl`, `jq`, `kubectl`, `ssh`

## Getting Started

1. Review `docs/DESIGN.md` for architecture and requirements.
2. Use `platform/terraform/terraform.tfvars.example` as a starting point for configuration.
3. Run Terraform or OpenTofu to provision the cluster.

## CI and Module Usage

If this repository is used as a module or executed in CI/CD, avoid writing kubeconfig and SSH keys to the repo. See `docs/DESIGN.md` for recommended handling patterns (sensitive outputs, temp paths, or external secrets managers).

## Addons

Required addons are installed as separate Helm releases to keep one namespace per component.
CloudStack CCM/CSI are installed from local charts in `charts/cloudstack-ccm` and `charts/cloudstack-csi`.
Default cert-manager ClusterIssuer is installed from `charts/cert-manager-issuers`.
K3s upgrades are handled by system-upgrade-controller with plans in `charts/k3s-upgrade-plans`.

## k3s Airgap Install

k3s artifacts are downloaded once on the Terraform host and uploaded to nodes before install.
