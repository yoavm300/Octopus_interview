# Apples app — infrastructure exercise

[![ci](https://github.com/yoavm300/Octopus_interview/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/yoavm300/Octopus_interview/actions/workflows/ci.yml)
[![lint](https://github.com/yoavm300/Octopus_interview/actions/workflows/lint.yml/badge.svg?branch=main)](https://github.com/yoavm300/Octopus_interview/actions/workflows/lint.yml)
[![deploy-aws](https://github.com/yoavm300/Octopus_interview/actions/workflows/deploy-aws.yml/badge.svg?branch=main)](https://github.com/yoavm300/Octopus_interview/actions/workflows/deploy-aws.yml)

A "hello world" apples page backed by MongoDB, fully defined as code: a NodeJS app,
MongoDB, and a one-shot data-seed Job, each in its own container, deployed via Helm.
See [`docs/architecture.md`](docs/architecture.md) for the full design and network
topology.

## Quick start (local — this is the graded path, no cloud account needed)

```sh
./scripts/provision-local.sh   # builds the image, creates a kind cluster, helm installs
./scripts/check.sh              # verifies the page reports 5 apples
./scripts/demo.sh               # visual demonstration: live containers, pods, services, network
./scripts/teardown-local.sh     # tears the kind cluster down
```

`provision-local.sh` is idempotent — re-running it against an existing cluster/release
just upgrades in place.

## Architecture

- **app** (`app/`) — NodeJS/Express, serves the apples page, `/healthz`, `/readyz`.
- **mongo** — MongoDB, seeded via a Helm hook Job with the exact fruit data from the
  exercise brief.
- **helm/apples-app** — the chart deploying all of the above; `values-local.yaml` and
  `values-aws.yaml` are value overlays on the same base chart, so the identical
  templates work unmodified on a local `kind` cluster or on EKS.
- **terraform/** (bonus) — provisions the AWS side (VPC, EKS, ECR, and the AWS Load
  Balancer Controller for the Ingress/load balancer bonus) so the same Helm chart can
  also be deployed there via `scripts/provision-aws.sh`. Not required to pass — grading
  runs the local scripts without any cloud credentials.

Full write-up: [`docs/architecture.md`](docs/architecture.md).

## AWS path (bonus)

```sh
export MONGO_PASSWORD=...   # never commit this
./scripts/provision-aws.sh
./scripts/teardown-aws.sh
```

## CI/CD

`.github/workflows/ci.yml` runs on every push/PR: Terraform validate/fmt + tfsec,
Helm lint/template, a Trivy image scan, a gitleaks secrets scan, and the full local
kind smoke test (the same thing `scripts/provision-local.sh` + `scripts/check.sh` do).

`.github/workflows/lint.yml` runs on every push/PR too, but for style rather than
correctness: ESLint on `app/`, yamllint on the workflow/Helm-values YAML,
actionlint on the workflow files themselves, and commitlint (Conventional
Commits) on the commits in the push/PR.

`.github/workflows/deploy-aws.yml` is the actual cloud-provider CD pipeline (bonus):
manually triggered (`workflow_dispatch`, not on every push, to avoid spending real
money on every commit), it runs `scripts/provision-aws.sh` or `scripts/teardown-aws.sh`
against real AWS, authenticating via OIDC role assumption — no long-lived AWS keys
stored in GitHub.

`.github/workflows/teardown-aws.yml` is a dedicated, single-purpose "stop the
spending" button — same OIDC auth, always tears down, so there's no risk of
picking the wrong option in `deploy-aws.yml`'s apply/destroy dropdown.

One-time setup before this workflow can run (not part of the graded path):

1. Apply `terraform/bootstrap/` once, manually, with real AWS credentials — it
   creates the GitHub OIDC provider and the IAM role the workflow assumes. It can't
   be applied by the workflow itself (chicken-and-egg: the role has to exist before
   anything can assume it).
2. Add two repo secrets: `AWS_DEPLOY_ROLE_ARN` (the bootstrap's `deploy_role_arn`
   output) and `MONGO_PASSWORD` (any value — the demo Mongo password, not an AWS
   credential).
3. Run the workflow from the Actions tab, choosing `apply` or `destroy`.

## Data

The DB is seeded with exactly this data (see `helm/apples-app/values.yaml`
`seedData`):

```json
[
  { "_id": 1, "name": "apples", "qty": 5, "rating": 3 },
  { "_id": 2, "name": "bananas", "qty": 7, "rating": 1, "microsieverts": 0.1 },
  { "_id": 3, "name": "oranges", "qty": 6, "rating": 2 },
  { "_id": 4, "name": "avocados", "qty": 3, "rating": 5 }
]
```
