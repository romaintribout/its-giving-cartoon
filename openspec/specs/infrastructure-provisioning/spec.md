# infrastructure-provisioning Specification

## Purpose

Describes the cloud server that hosts the app and its database, and how infrastructure changes are reviewed and applied from CI instead of from a developer's laptop.

## Requirements

### Requirement: Server resources are declared as code
The infrastructure SHALL be declared in the repository and SHALL create one Linux VM in Infomaniak Public Cloud, with a private network, subnet, router connected to the external network, floating IP, security group, data volume attached to the VM, and SSH key pair.

#### Scenario: Apply from an empty project
- **WHEN** the infrastructure is applied against an OpenStack project that has none of these resources
- **THEN** the VM is running, reachable on its floating IP, and has the data volume attached

#### Scenario: Re-apply without changes
- **WHEN** the infrastructure is applied again with no code change
- **THEN** the plan reports no changes

### Requirement: Only SSH is exposed to the internet
The security group SHALL allow inbound SSH (TCP 22) only from a configurable list of CIDR ranges, and SHALL NOT allow any other inbound traffic from the internet. Outbound traffic SHALL be allowed.

#### Scenario: SSH from an allowed address
- **WHEN** a client in an allowed CIDR range connects on TCP 22 with the matching private key
- **THEN** the connection succeeds

#### Scenario: MongoDB port is not reachable
- **WHEN** a client on the internet connects to the floating IP on TCP 27017
- **THEN** the connection is refused or times out

### Requirement: Server outputs are exposed
Applying the infrastructure SHALL output the server's public IP address.

#### Scenario: Read the public IP
- **WHEN** an apply completes
- **THEN** the floating IP address is available as an output and shown in the workflow logs

### Requirement: State is stored remotely
The infrastructure state SHALL be stored in a bucket on Infomaniak Object Storage, not in the repository or on a laptop.

#### Scenario: State survives between runs
- **WHEN** two workflow runs happen one after the other
- **THEN** the second run reads the state written by the first and plans only the differences

### Requirement: Pull requests show a plan
For every pull request that changes infrastructure code or the workflow, CI SHALL check formatting, validate the configuration, compute a plan, and post the plan as a comment on the pull request. CI SHALL NOT apply changes from a pull request.

#### Scenario: Valid change
- **WHEN** a pull request changes a file under `infra/`
- **THEN** the format check and validation pass, and a comment with the plan appears on the pull request

#### Scenario: Badly formatted code
- **WHEN** a pull request contains OpenTofu code that is not formatted
- **THEN** the workflow fails and no apply happens

#### Scenario: Pull request without infrastructure changes
- **WHEN** a pull request does not touch `infra/` or the workflow file
- **THEN** the infrastructure workflow does not run

### Requirement: Changes are applied from main after approval
On push to `main` that changes infrastructure code or the workflow, CI SHALL compute a plan and SHALL apply exactly that plan only after a reviewer approves the `production` environment deployment.

#### Scenario: Approved apply
- **WHEN** a change to `infra/` is merged to `main` and a reviewer approves the deployment
- **THEN** the saved plan is applied and the workflow succeeds

#### Scenario: Rejected apply
- **WHEN** a reviewer rejects the deployment
- **THEN** nothing is applied and the infrastructure is unchanged

### Requirement: One run changes the state at a time
CI SHALL NOT run two `main` workflow runs at the same time. A new run SHALL wait for the running one instead of cancelling it. Pull request plans only read the state and MAY run in parallel with other runs.

#### Scenario: Two merges in quick succession
- **WHEN** two infrastructure changes are merged to `main` while the first apply is still running
- **THEN** the second run waits until the first finishes before planning

#### Scenario: Pull request while an apply awaits approval
- **WHEN** a pull request is updated while a `main` run is waiting for approval
- **THEN** the pull request plan runs without waiting and does not change the state

### Requirement: Credentials stay out of the repository
Cloud and storage credentials, and the allowed SSH CIDR ranges, SHALL be provided to CI only through GitHub repository secrets, and SHALL NOT appear in the repository, in workflow logs, or in pull request comments. Workflow runs triggered from forks SHALL NOT receive them.

#### Scenario: Allowed SSH ranges are not published
- **WHEN** the workflow plans or applies with the allowed SSH CIDR ranges
- **THEN** the ranges appear as `***` in the workflow logs and in the pull request plan comment

#### Scenario: Pull request from a fork
- **WHEN** a pull request is opened from a fork
- **THEN** the workflow has no access to the credentials and does not plan

#### Scenario: Secrets are missing
- **WHEN** the workflow runs without the required secrets
- **THEN** it fails before planning with an authentication error
