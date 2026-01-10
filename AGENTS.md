# Agent Guidelines

## Terraform Provider Versioning

When adding or updating Terraform providers:

1. **Always use `~> major.minor.patch` constraint** - This pins to the minor version while allowing patch upgrades. For example: `~> 5.82.0` allows `5.82.x` but not `5.83.0`.

2. **Look up the latest version** - Before adding a new provider, always check for the most recent stable version. Do not guess or use outdated versions.
