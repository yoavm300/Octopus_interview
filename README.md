# Apples app — infrastructure exercise

[![ci](https://github.com/yoavm300/Octopus_interview/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/yoavm300/Octopus_interview/actions/workflows/ci.yml)
[![lint](https://github.com/yoavm300/Octopus_interview/actions/workflows/lint.yml/badge.svg?branch=main)](https://github.com/yoavm300/Octopus_interview/actions/workflows/lint.yml)
[![deploy-aws](https://github.com/yoavm300/Octopus_interview/actions/workflows/deploy-aws.yml/badge.svg?branch=main)](https://github.com/yoavm300/Octopus_interview/actions/workflows/deploy-aws.yml)
[![teardown-aws](https://github.com/yoavm300/Octopus_interview/actions/workflows/teardown-aws.yml/badge.svg?branch=main)](https://github.com/yoavm300/Octopus_interview/actions/workflows/teardown-aws.yml)

A "hello world" apples page backed by MongoDB, fully defined as code: a NodeJS app,
MongoDB, and a one-shot data-seed Job, each in its own container, deployed via Helm.

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

### Components

- **app** — a small NodeJS/Express service. Serves one page showing the current apple
  count read from MongoDB, plus `/healthz` (liveness) and `/readyz` (readiness, checks
  the DB connection).
- **mongo** — a single-replica MongoDB instance (StatefulSet), holding the `fruits`
  collection.
- **seed** — a Helm post-install/post-upgrade hook Job that inserts the exercise's
  fixed fruit data into `fruits` on every install/upgrade.

Each runs in its own container, per the brief. **helm/apples-app** is the one chart
deploying all three; `values-local.yaml` and `values-aws.yaml` are value overlays on
the same base chart, so the identical templates work unmodified on a local `kind`
cluster or on EKS — only the overlay differs (service type, persistence, ingress).
**terraform/** (bonus) provisions the AWS side (VPC, EKS, ECR, the AWS Load Balancer
Controller) so the same Helm chart can also be deployed there via
`scripts/provision-aws.sh`. Not required to pass — grading runs the local scripts
without any cloud credentials.

### Network topology (local / kind)

```
                 +----------------------------+
                 |   kind cluster "apples-local" |
                 |                                |
  localhost      |   +----------+     +--------+  |
  (port-forward) +-->| app Svc  +---->| app Pod|  |
                 |   | ClusterIP|     +----+---+  |
                 |   +----------+          |      |
                 |                         v      |
                 |   +-------------+  mongo:27017 |
                 |   | mongo Svc   +--->+--------+ |
                 |   | headless    |    |mongo Pod| |
                 |   +-------------+    +--------+ |
                 +----------------------------+
```

No Ingress/load balancer locally — `scripts/check.sh` reaches the app via
`kubectl port-forward`, which is sufficient for the "provision from scratch + verify"
requirement without needing a cloud account.

### Network topology (AWS, bonus)

```
 Internet
    |
    v
 ALB (via AWS Load Balancer Controller, Ingress)
    |
    v
 EKS cluster (private subnets, NAT-routed egress)
    |
    +-- app Deployment  -- app Service (ClusterIP)
    |
    +-- mongo StatefulSet (EBS-backed PVC) -- mongo Service (headless)

VPC: 2 public subnets (ALB, NAT GW) + 2 private subnets (EKS nodes), across 2 AZs.
ECR holds the built app image; EKS nodes pull from it.
```

Same Helm chart as local — only `values-aws.yaml` differs (ingress enabled with an
ALB class, persistent storage enabled, password supplied at deploy time instead of a
checked-in dev default).

### Containers

| Container | Image               | Role                                   |
|-----------|---------------------|-----------------------------------------|
| app       | built from `app/`   | serves the apples page                 |
| mongo     | `mongo:7`           | data store                             |
| seed      | `mongo:7` (Job)     | one-shot: inserts the fixed fruit data |

### Security notes

- App and seed containers run as non-root with `allowPrivilegeEscalation: false`; the
  app's root filesystem is read-only (writable `/tmp` only).
- Mongo runs as non-root too; an init container (running briefly as root) `chown`s the
  data volume so the main container doesn't need root.
- Mongo credentials live in a Kubernetes `Secret`, never committed in plaintext.
  Neither `values-local.yaml` nor `values-aws.yaml` hardcodes a password —
  `provision-local.sh` generates one into a gitignored `.local-mongo-password`
  file and supplies it via `--set`; the AWS path expects it supplied the same
  way from the `MONGO_PASSWORD` env var.

### Operational notes (found live, on real AWS)

A handful of details below only matter on the AWS path, and only exist in the code
because a live `apply`/`destroy` cycle against a real account surfaced them —
each is a real failure mode, not speculative hardening:

- **Storage provisioner.** Modern EKS doesn't bundle one. Mongo's PVC would stay
  `Pending` forever ("no persistent volumes available for this claim and no storage
  class is set") without the `aws-ebs-csi-driver` EKS addon and a default `gp3`
  `StorageClass`, both provisioned by `terraform/modules/eks`.
- **Mongo's memory limit.** 256Mi OOMKilled `mongod` five seconds into its very
  first boot on a real EKS node (WiredTiger's default cache sizing alone needs close
  to that much) — worked fine on `kind`, where memory pressure differs. Raised to
  512Mi.
- **The ALB controller doesn't auto-discover reliably.** It resolves its VPC ID and
  region via EC2 instance metadata (IMDS) by default, and that call can time out from
  inside a pod's network namespace, leaving the controller crash-looping. Both are
  passed to the Helm release explicitly instead (`terraform/modules/alb`).
- **EKS's "cluster creator gets implicit admin" doesn't reliably apply** once the
  cluster's `access_config` is set explicitly (needed to support an optional
  `admin_principal_arns` variable that lets an operator `kubectl` into the cluster to
  debug, without assuming the CI role). Fixed by always granting whoever actually ran
  Terraform an explicit EKS access entry instead of relying on that behavior.
- **A few AWS APIs lag behind their own writes** by seconds to minutes right after a
  dependent resource changes — ECR's `ListTagsForResource` right after
  `CreateRepository`, a security group or VPC-CNI secondary ENI a moment after the
  resource that owned it is deleted. `provision-aws.sh` and `teardown-aws.sh` both
  retry `terraform apply`/`destroy` a few times with a short backoff to absorb this,
  rather than treating it as a hard failure.

## Project layout

```
app/                      NodeJS/Express app — the only piece with application code
  src/server.js             routes: "/" (apple count), "/healthz", "/readyz"
  src/db.js                 Mongo connection + queries
  Dockerfile                multi-stage build (deps stage, then a slim non-root runtime)

helm/apples-app/           One chart, deploys app + MongoDB + the seed Job together
  Chart.yaml
  values.yaml                base values: image, resources, probes, the fixed seedData
  values-local.yaml           overlay: ClusterIP service, ephemeral storage — for kind
  values-aws.yaml              overlay: ALB Ingress annotations, persistent volume — for EKS
  values.schema.json          validates values shape (catches typos before a bad install)
  templates/_helpers.tpl      shared labels/selectors used by every template
  templates/app-deployment.yaml / app-service.yaml   the NodeJS app
  templates/mongo-statefulset.yaml / mongo-service.yaml   MongoDB (headless Service, PVC-ready)
  templates/mongo-secret.yaml  Mongo credentials as a Kubernetes Secret, never in plaintext values
  templates/seed-job.yaml     post-install/post-upgrade hook Job that loads the fixed fruit data
  templates/ingress.yaml      optional Ingress, only rendered when an overlay enables it

terraform/                 AWS bonus path — provisions the cloud the chart above deploys onto
  main.tf / providers.tf / variables.tf / outputs.tf   root config for the one demo environment
  modules/vpc/               VPC, subnets, flow logs
  modules/eks/                 EKS cluster, node group, OIDC provider for IRSA
  modules/ecr/                 container registry for the app image
  modules/alb/                 AWS Load Balancer Controller (IRSA role + helm_release)
  bootstrap/                 separate, one-time-applied root module: creates the GitHub
                                Actions OIDC trust + IAM role, so CI can assume it later
                                (has to exist before any workflow can use it — chicken-and-egg)

scripts/                   Top-level, idempotent entry points — what grading actually runs
  provision-local.sh         build image, create/reuse a kind cluster, helm install — no cloud
  check.sh                   asserts the page reports the correct apple count
  demo.sh                     prints/shows the live containers, pods, services, network
  teardown-local.sh           tears the kind cluster down
  provision-aws.sh            terraform apply, push image to ECR, helm install onto EKS
  demo-aws.sh                 same visual demonstration as demo.sh, but for the live
                                 EKS cluster: nodes, pods, services, Ingress/ALB, VPC layout
  teardown-aws.sh             terraform destroy — the AWS "stop the spending" path

.github/workflows/         CI/CD — kept separate from the provisioning scripts it calls
  ci.yml                      runs the checks above on every push/PR: terraform validate/tfsec,
                                 helm lint/template, Trivy image scan, gitleaks, kind smoke test
  lint.yml                     style/hygiene, not correctness: eslint, yamllint, actionlint,
                                 commitlint — also every push/PR
  deploy-aws.yml               manual (workflow_dispatch) real AWS apply/destroy via OIDC
  teardown-aws.yml             manual-only, single-purpose destroy — a dedicated safety net
```

Rationale behind the split:
- **`app/` vs `helm/` vs `terraform/`** are separated by concern, not by environment: the app
  doesn't know about Kubernetes, the chart doesn't know about AWS, and Terraform doesn't know
  about the app's code — each layer only depends on the one below it.
- **One Helm chart, two values overlays** (`values-local.yaml` / `values-aws.yaml`) instead of
  two charts, so the local (graded) and AWS (bonus) deployments can never silently drift apart.
- **`terraform/modules/`** exists even though there's only one environment, because splitting
  vpc/eks/ecr/alb into modules is how a real Terraform codebase would be organized — full
  multi-environment workspaces would be disproportionate here, but the module boundary itself
  is worth keeping.
- **`terraform/bootstrap/`** is its own root module, not folded into `terraform/`, because it has
  a different lifecycle (applied once, by hand, long before any EKS infra exists) and a different
  blast radius (IAM trust, not disposable demo infra).
- **`scripts/`** is the one directory grading actually depends on: everything else exists to
  support what these scripts do, so they stay flat, named by action, and runnable with no
  arguments.
- **CI (`.github/workflows/`) calls the scripts rather than re-implementing them**, so "what CI
  checks" and "what you can run yourself locally" never diverge.

## AWS path (bonus)

```sh
export MONGO_PASSWORD=...   # never commit this
./scripts/provision-aws.sh
./scripts/demo-aws.sh        # visual demonstration: nodes, pods, services, Ingress/ALB,
                               # VPC subnet layout, and a live curl through the real ALB
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
   creates the GitHub OIDC provider and IAM role the workflow assumes, plus the
   S3 bucket + DynamoDB table `terraform/`'s remote state lives in. None of this
   can be applied by the workflow itself (chicken-and-egg: it all has to exist
   before anything can assume the role or write state to it).
2. Add four repo secrets: `AWS_DEPLOY_ROLE_ARN` (bootstrap's `deploy_role_arn`
   output), `TF_STATE_BUCKET` (`tfstate_bucket` output), `TF_LOCK_TABLE`
   (`tfstate_lock_table` output), and `MONGO_PASSWORD` (any value — the demo
   Mongo password, not an AWS credential).
3. Run the workflow from the Actions tab, choosing `apply` or `destroy`.

A remote state backend matters here specifically because `apply` and `destroy`
run as separate `workflow_dispatch` invocations, each on its own disposable
GitHub Actions runner — without one, the state written by an `apply` run
would vanish with that runner, and a later `destroy` run would have nothing
to act on. (This is exactly what happened before the backend was added: a
failed `apply` left a real EKS cluster running, with no state anywhere that
`teardown-aws.yml` could use to find and remove it.)

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
