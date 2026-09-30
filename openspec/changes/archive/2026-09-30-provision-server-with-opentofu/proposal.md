# Proposal

## Why

The app needs MongoDB 8.3 Community with `mongot`, which runs on Linux only, and Infomaniak offers no managed MongoDB 8.3. We need a Linux VM in Infomaniak Public Cloud, and we want it reproducible, reviewed like code, and deployed from CI rather than from a laptop (see `ADR/0001-provision-server-with-opentofu.md`). Setting up the pipeline now, before the app exists, lets us learn the workflow early.

## What Changes

- Add OpenTofu code in `infra/` that uses the `openstack` provider to create one Linux VM and what it needs: network, subnet, router, floating IP, security group, data volume, and SSH key pair.
- Store OpenTofu state in the `s3` backend on Infomaniak Object Storage. The state bucket is created once by hand; the steps are documented.
- Add a GitHub Actions workflow:
  - on pull requests touching `infra/`: `fmt -check`, `validate`, and `plan`, with the plan posted as a PR comment
  - on push to `main` touching `infra/`: `plan`, then `apply` after manual approval through the `production` GitHub Environment
  - a `concurrency` group so only one run touches the state at a time
- Authenticate CI with a dedicated OpenStack Application Credential, stored as GitHub repository secrets. The `production` GitHub Environment holds no secrets and only gates `apply` behind a required reviewer. This deviates from the ADR wording: an environment's reviewers gate every job that uses it, so PR plans would otherwise need manual approval too.
- Document the one-time setup (bucket, application credential, GitHub secrets, `production` environment with a required reviewer) and the day-to-day workflow in `README.md`.

Out of scope: configuring the VM (installing Docker, MongoDB, `mongot`). That comes with a future ADR.

## Capabilities

### New Capabilities
- `infrastructure-provisioning`: the cloud resources that make up the server, where state lives, and how CI plans and applies infrastructure changes.

### Modified Capabilities
<!-- None: no existing specs. -->

## Impact

- New directories and files: `infra/` (OpenTofu code), `.github/workflows/infra.yml`.
- New external dependencies: OpenTofu, the `openstack` provider, Infomaniak Public Cloud and Object Storage.
- New GitHub repository secrets: OpenStack Application Credential, Object Storage S3 keys, SSH public key.
- Cost: one running VM, one volume, one floating IP, and a small bucket on Infomaniak.
- `README.md` gains an infrastructure section.
