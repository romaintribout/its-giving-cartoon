# Tasks

## 1. OpenTofu configuration

- [x] 1.1 Create `infra/versions.tf` with the pinned OpenTofu and `openstack` provider versions, an empty provider block, and the `s3` backend (path-style, `skip_*` flags, `use_lockfile = true`). Verify that `tofu init -backend=false` succeeds and commit `.terraform.lock.hcl`
- [x] 1.2 Create `infra/variables.tf` (region, flavor, image, external network, volume size, `ssh_public_key`, `ssh_allowed_cidrs`) with the defaults from design.md. Verify that `tofu validate` passes
- [x] 1.3 Create `infra/main.tf` with the key pair, network, subnet, router + interface, security group with SSH rules per CIDR, instance, data volume with `prevent_destroy`, volume attachment, floating IP + association. Verify that `tofu fmt -check` and `tofu validate` pass
- [x] 1.4 Create `infra/outputs.tf` with `public_ip`. Verify that `tofu validate` passes
- [x] 1.5 Add `.gitignore` entries for `.terraform/`, `*.tfstate*`, `tfplan`, `*.tfvars`. Verify with `git status` that none of these would be committed

## 2. One-time cloud bootstrap (manual)

- [x] 2.1 Confirm flavor, image, and external network names in the region (`openstack flavor list`, `openstack image list`, `openstack network list --external`) and the Object Storage S3 endpoint and region. Update defaults in `variables.tf` and `versions.tf` if needed
- [x] 2.2 Create the Application Credential, EC2 credentials, and the state bucket. Verify by running `tofu init` and `tofu plan` locally with those credentials; the plan should list all resources to create
- [x] 2.3 Test `use_lockfile`: hold a lock with a running `tofu plan` (or `tofu console`) and run a second `tofu plan` in parallel; it must fail with a lock error. If Infomaniak does not support it, remove `use_lockfile` and record that in design.md and README
- [ ] 2.4 Document the bootstrap steps (credential, EC2 keys, bucket, repository secrets including `SSH_ALLOWED_CIDRS`, `production` environment with required reviewer, credential rotation) in a new "Infrastructure" section of `README.md`. Verify that each command in it runs as written

## 3. GitHub Actions workflow

- [x] 3.1 Create `.github/workflows/infra.yml` with `pull_request` and `push`-to-`main` triggers filtered on `infra/**` and the workflow file, `permissions`, and conditional `concurrency` (serialized `infra-main` on `main`, per-PR group with cancellation otherwise). Verify with `actionlint`
- [x] 3.2 Add the `plan` job: setup-opentofu, `fmt -check`, `init`, `validate`, `plan -out=tfplan` (`-lock=false` on PRs), skip for fork PRs, post or update the plan comment with `gh pr comment --edit-last --create-if-none` on PRs, upload `tfplan` on `main`. Verify with `actionlint`
- [x] 3.3 Add the `apply` job: `needs: plan`, `environment: production`, `main` only, download `tfplan`, `init`, `apply tfplan`, print `public_ip`. Verify with `actionlint`
- [x] 3.4 Add a short "Day-to-day workflow" note to the README's Infrastructure section (open a PR, read the plan comment, merge, approve the deployment) and update the README Status line
- [x] 3.5 Store `SSH_ALLOWED_CIDRS` as a secret, mask each CIDR in both jobs with `::add-mask::`, and replace the CIDRs with `***` in the PR plan comment. Verify with `actionlint` and a local test of the replacement

## 4. ADR note

- [x] 4.1 Add a short note to `ADR/0001-provision-server-with-opentofu.md` saying that the credentials are repository secrets and `production` only gates `apply`, and why. Verify that the ADR and README agree

## 5. End-to-end check

- [x] 5.1 Open a PR with the changes. Verify that the workflow runs, `fmt`/`validate` pass, and a plan comment appears. Push a new commit and verify that the same comment is updated, not duplicated
- [ ] 5.2 Merge the PR. Verify that `apply` waits for approval, then approve it and check that it succeeds and prints `public_ip`
- [ ] 5.3 Verify the server: `ssh ubuntu@<public_ip>` works from an allowed CIDR, `lsblk` shows the data volume, and `nc -zv <public_ip> 27017` fails
- [ ] 5.4 Re-run the `main` workflow without changes. Verify that the plan reports no changes
