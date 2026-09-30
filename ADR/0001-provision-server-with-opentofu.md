# 1. Provision the server with OpenTofu from GitHub Actions

Date: 2026-09-30

## Status

Accepted

## Context

The app needs MongoDB 8.3 Community with `mongot` for vector search.
`mongot` runs on Linux only, and Infomaniak offers no managed MongoDB 8.3,
so we self-host on a Linux VM in Infomaniak Public Cloud (OpenStack-based).

We want the infrastructure to be reproducible, reviewed like code, and
deployed from CI instead of from a laptop. We set up the pipeline now,
before the app exists, to learn the workflow early.

## Decision

- Use **OpenTofu** to describe the infrastructure.
- Use the **`openstack` provider**. The `Infomaniak/infomaniak` provider
  mainly targets managed Kubernetes, which we don't need.
- Scope: one Linux VM, network, subnet, router, floating IP, security group,
  data volume, and SSH key pair. Server configuration is out of scope
  (see a future ADR).
- Store the state in the **`s3` backend** on Infomaniak Object Storage.
  The bucket is created once by hand, since the state cannot create it.
- Authenticate CI with a dedicated **OpenStack Application Credential**,
  stored as secrets in a GitHub Environment named `production`.
  Infomaniak does not support GitHub OIDC.
- GitHub Actions workflow:
  - on pull request: `fmt`, `validate`, `plan`, with the plan posted on the PR
  - on push to `main`: `plan`, then `apply` after manual approval
  - `concurrency` so that only one run touches the state at a time
- Keep the code in `infra/` in this repository.

Note (implementation): the credentials are **repository secrets**, not
`production` environment secrets. The `production` environment holds no
secrets and only gates the `apply` job with a required reviewer. The
reviewers of an environment gate every job that uses it, so keeping the
secrets there would make pull request plans wait for approval too.

## Consequences

- Every infrastructure change goes through a PR with a visible plan.
- A long-lived secret lives in GitHub. It is scoped to one project and can
  be revoked, but it must be rotated manually.
- State locking (`use_lockfile`) does not work on Infomaniak Object Storage:
  it needs conditional PUTs, which Infomaniak does not support (tested).
  `concurrency` is the only protection against parallel applies, so
  applies must only run from CI. That is acceptable for a solo project.
- The state bucket is a manual, one-time step that must be documented.
- The VM exists but is not configured. It is not useful until the
  configuration ADR is written and implemented.
