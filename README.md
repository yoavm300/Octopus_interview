# Apples app — infrastructure exercise

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

## CI

`.github/workflows/ci.yml` runs on every push/PR: Terraform validate/fmt + tfsec,
Helm lint/template, a Trivy image scan, a gitleaks secrets scan, and the full local
kind smoke test (the same thing `scripts/provision-local.sh` + `scripts/check.sh` do).

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
