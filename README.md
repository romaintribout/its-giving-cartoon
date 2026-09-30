# It's Giving Cartoon

A movie search app for kids, built as a playground to explore MongoDB vector search.

## Goal

Find kid-friendly movies by describing what you want to watch (e.g. "a funny adventure with animals"), using semantic search instead of plain keyword matching.

## Tech

- **MongoDB 8.3**, self-managed Community Edition, with `mongot` for search
  - `$vectorSearch` for semantic search
  - `$rankFusion` / `$scoreFusion` for hybrid search (full-text + vector)
- **Docker** to run MongoDB locally (`mongot` runs on Linux only)
- **OpenTofu** + **GitHub Actions** to provision the server on Infomaniak Public Cloud (see [ADR 0001](ADR/0001-provision-server-with-opentofu.md))

## Status

Work in progress. The server infrastructure (a Linux VM on Infomaniak Public Cloud) is provisioned from CI. The VM is not configured yet, and the app has no features yet.

## Infrastructure

The OpenTofu code in `infra/` creates one Ubuntu VM in Infomaniak Public Cloud (region `dc3-a`) with a private network, router, floating IP, a security group that only allows SSH from `SSH_ALLOWED_CIDRS`, a 20 GB data volume, and an SSH key pair. The state lives in the `its-giving-cartoon-tfstate` bucket on Infomaniak Object Storage.

The workflow `.github/workflows/infra.yml` runs when `infra/` or the workflow file changes:

- **Pull request**: `fmt -check`, `validate`, and `plan`, with the plan posted as a single PR comment that is updated on each push. Nothing is applied. PRs from forks are skipped.
- **Push to `main`**: `plan`, then `apply` of that exact plan after a reviewer approves the `production` environment. `main` runs never overlap.

The state has no lock: Infomaniak Object Storage does not support the conditional writes that OpenTofu's `use_lockfile` needs. The workflow's `concurrency` group is what keeps two applies from running at once, so only apply from CI.

### One-time bootstrap

Run these once, with the `openstack` CLI logged in to the Infomaniak project (source your `openrc` file or set `OS_CLOUD`).

1. Create an Application Credential for CI. Note its `id` and `secret`:

   ```sh
   openstack application credential create its-giving-cartoon-ci \
     --description "GitHub Actions for its-giving-cartoon"
   ```

2. Create EC2 credentials for Object Storage. Note the `access` and `secret` values:

   ```sh
   openstack ec2 credentials create
   ```

3. Create the state bucket:

   ```sh
   openstack container create its-giving-cartoon-tfstate
   ```

4. Add the repository secrets and variable (Settings → Secrets and variables → Actions, or with `gh`):

   ```sh
   gh secret set OS_APPLICATION_CREDENTIAL_ID      # application credential id
   gh secret set OS_APPLICATION_CREDENTIAL_SECRET  # application credential secret
   gh secret set AWS_ACCESS_KEY_ID                 # EC2 "access"
   gh secret set AWS_SECRET_ACCESS_KEY             # EC2 "secret"
   gh secret set SSH_PUBLIC_KEY < ~/.ssh/id_ed25519.pub
   gh variable set SSH_ALLOWED_CIDRS --body '["203.0.113.4/32"]'
   ```

   `SSH_ALLOWED_CIDRS` is a JSON list of the ranges allowed to reach SSH.

5. Create the `production` environment (Settings → Environments → New environment), enable **Required reviewers**, and add yourself. Add no secrets to it: the credentials are repository secrets, and `production` only gates the `apply` job. Putting the secrets in the environment would make PR plans wait for approval too.

### Day-to-day workflow

1. Change `infra/` in a branch and open a PR.
2. Read the plan in the PR comment.
3. Merge the PR.
4. Approve the `production` deployment in the Actions tab. The job log ends with the server's `public_ip`.

Then connect with `ssh ubuntu@<public_ip>`.

If the apply fails because the saved plan is stale, re-run the workflow.

### Running OpenTofu locally

```sh
source openrc.sh                      # or: export OS_CLOUD=<cloud name>
export AWS_ACCESS_KEY_ID=... AWS_SECRET_ACCESS_KEY=...
export TF_VAR_ssh_public_key="$(cat ~/.ssh/id_ed25519.pub)"
export TF_VAR_ssh_allowed_cidrs='["203.0.113.4/32"]'
cd infra && tofu init && tofu plan
```

Apply only from CI.

### Rotating credentials

1. Create a new Application Credential and EC2 credentials (steps 1 and 2 above).
2. Update the matching repository secrets.
3. Re-run the latest `main` workflow to check the plan still works.
4. Delete the old ones:

   ```sh
   openstack application credential delete <old-id>
   openstack ec2 credentials delete <old-access-key>
   ```

### Destroying the data volume

The data volume has `prevent_destroy`, so OpenTofu refuses to delete it. To remove it on purpose, first merge a PR that removes the `lifecycle` block.
