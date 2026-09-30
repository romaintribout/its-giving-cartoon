# Design

## Context

The repository has no code yet, only a README and `ADR/0001-provision-server-with-opentofu.md`. See proposal.md (Why) for motivation and `specs/infrastructure-provisioning/spec.md` for the required behavior.

Constraints:
- Infomaniak Public Cloud is OpenStack. Identity endpoint `https://api.pub1.infomaniak.cloud/identity/v3`. Object Storage exposes an S3-compatible API.
- Infomaniak does not support GitHub OIDC, so CI needs a long-lived credential.
- `mongot` needs Linux; the VM will later run MongoDB 8.3 and `mongot` in Docker.

## Goals / Non-Goals

**Goals:**
- A small, flat OpenTofu configuration that a newcomer can read in a few minutes.
- A single workflow file that covers PR checks and gated applies.
- The data volume survives VM replacement.

**Non-Goals:**
- Server configuration (Docker, MongoDB, `mongot`, mounting the volume, OS hardening).
- Modules, multiple environments, or workspaces.
- DNS, TLS, backups, monitoring.
- Drift detection on a schedule.

## Decisions

### Flat layout in `infra/`
Files: `versions.tf` (OpenTofu + provider versions, backend), `variables.tf`, `main.tf` (all resources), `outputs.tf`, `.terraform.lock.hcl` committed.
*Alternative:* one module per resource group. Rejected: too much structure for about ten resources.

### `openstack` provider, configured only through environment variables
The provider block stays empty. CI sets `OS_AUTH_TYPE=v3applicationcredential`, `OS_AUTH_URL`, `OS_REGION_NAME`, `OS_APPLICATION_CREDENTIAL_ID`, `OS_APPLICATION_CREDENTIAL_SECRET`. The same code then works locally with a sourced `openrc` file.
*Alternative:* the `Infomaniak/infomaniak` provider. Rejected in the ADR, since it targets managed Kubernetes.

### Resources
- `openstack_compute_keypair_v2` from variable `ssh_public_key`.
- `openstack_networking_network_v2` + `subnet_v2` (`10.0.0.0/24`, public DNS resolvers) + `router_v2` on the external network (`ext-floating1`, variable) + `router_interface_v2`.
- `openstack_networking_secgroup_v2` with one ingress rule per CIDR in `ssh_allowed_cidrs` on TCP 22. We keep OpenStack's default egress rules and add no other ingress rules.
- `openstack_compute_instance_v2`: image `Ubuntu 24.04 LTS`, flavor from variable, attached to the private network and the security group. No `user_data` (configuration is out of scope).
- `openstack_blockstorage_volume_v3` (variable size, default 20 GB) with `lifecycle { prevent_destroy = true }`, plus `openstack_compute_volume_attach_v2`. Keeping the volume separate from the VM means the VM can be replaced without losing data.
- `openstack_networking_floatingip_v2` + `openstack_networking_floatingip_associate_v2` on the VM's port.
- Output `public_ip`.

Variables that are not secrets have defaults: region `dc3-a`, flavor `a2-ram4-disk20-perf1` (2 vCPU, 4 GB, a starting point for MongoDB + `mongot`), image name, volume size. `ssh_public_key` and `ssh_allowed_cidrs` have no defaults.

### `s3` backend on Infomaniak Object Storage
The backend block in `versions.tf` sets the bucket, key `infra/terraform.tfstate`, `endpoints.s3`, `region`, `use_path_style = true`, and the `skip_*` flags that non-AWS S3 needs (`skip_credentials_validation`, `skip_region_validation`, `skip_requesting_account_id`, `skip_metadata_api_check`, `skip_s3_checksum`). Access keys come from `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`, created with `openstack ec2 credentials create`. `use_lockfile = true` is set and tested once (see Risks).
*Alternative:* HTTP backend or a GitLab-style managed backend. Rejected: we would add another service.

### Secrets: repository secrets plus an approval-only environment
Repository secrets: `OS_APPLICATION_CREDENTIAL_ID`, `OS_APPLICATION_CREDENTIAL_SECRET`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `SSH_PUBLIC_KEY`. Repository variable (not secret): `SSH_ALLOWED_CIDRS`, as a JSON list passed through `TF_VAR_ssh_allowed_cidrs`. The `production` environment holds no secrets and has one required reviewer. Only the apply job uses it.
*Alternatives:* (a) all secrets in `production`, which makes PR plans wait for approval too, since reviewers gate every job that uses the environment; (b) two environments with copies of the same secrets, which doubles rotation. Chosen with the user; it deviates from the ADR's wording, so the ADR gets a short note.
GitHub does not pass repository secrets to workflows triggered from forks. The PR job also skips itself when `head.repo.full_name != github.repository`.

### One workflow, `.github/workflows/infra.yml`
- Triggers: `pull_request` and `push` on `main`, both filtered on `infra/**` and `.github/workflows/infra.yml`.
- `permissions: contents: read, pull-requests: write`.
- Setup with `opentofu/setup-opentofu` (pinned version); `working-directory: infra`.
- **`plan` job** (both triggers): `tofu fmt -check -recursive`, `tofu init`, `tofu validate`, `tofu plan -out=tfplan`. On PRs it runs with `-lock=false`, since it never writes the state. On PRs it posts the output of `tofu show -no-color tfplan`, wrapped in a collapsible `<details>` block, using `gh pr comment --edit-last --create-if-none`, so there is one comment per PR that gets updated. On `main` it uploads `tfplan` as an artifact.
- **`apply` job** (`main` only, `needs: plan`, `environment: production`): downloads `tfplan`, `tofu init`, `tofu apply tfplan`, then prints `tofu output public_ip`. Applying the saved plan means the change that was reviewed is exactly what runs. If the state changed in between, OpenTofu rejects the stale plan.
- `concurrency: { group: infra-main, cancel-in-progress: false }` only when `github.ref == 'refs/heads/main'`. PR runs use a per-PR group with `cancel-in-progress: true`.
*Alternative:* a third-party wrapper (Atlantis, tf-via-pr action). Rejected: extra dependencies for little gain.

## Risks / Trade-offs

- [Long-lived credential in GitHub] → Application Credential limited to this OpenStack project, documented rotation steps in README.
- [S3 lockfile support on Infomaniak unverified] → `concurrency` serializes `main` runs; one manual test of `use_lockfile` during implementation. If unsupported, remove it and document that.
- [GitHub concurrency keeps only one pending run; a third queued run replaces the second] → Acceptable: the newest run plans against the latest `main`, which includes the skipped commit.
- [Saved plan becomes stale while waiting for approval] → The apply fails cleanly; re-run the workflow.
- [Plan output in PR comments could leak sensitive values] → No secrets are OpenTofu variables except the SSH public key, which is not sensitive. Mark any future secret variables `sensitive = true`.
- [`prevent_destroy` blocks intentional teardown] → Documented: remove the lifecycle rule in a PR first.
- [Flavor may be too small for MongoDB + `mongot` later] → It is a variable; resizing is a one-line PR.

## Migration Plan

Greenfield. One-time manual bootstrap (documented in README):
1. Create an Application Credential in the Infomaniak project.
2. Create EC2 credentials and the state bucket in Object Storage.
3. Add the repository secrets and the `SSH_ALLOWED_CIDRS` variable, and create the `production` environment with a required reviewer.
4. Open the PR, check the plan comment, merge, approve the apply.

Rollback: revert the PR, then approve the resulting apply. The data volume is protected by `prevent_destroy`.

## Open Questions

- Exact flavor, image, and external network names available in the chosen region. Check with `openstack flavor list`, `openstack image list`, and `openstack network list --external` during implementation; only defaults change.
- ~~The exact S3 endpoint and region string for Infomaniak Object Storage in `dc3-a`.~~ Resolved: endpoint `https://s3.pub1.infomaniak.cloud`, region `us-east-1` (the S3 API rejects `dc3-a` with `AuthorizationHeaderMalformed`).
