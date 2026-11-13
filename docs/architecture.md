# Architecture

## Components

- **app** — a small NodeJS/Express service. Serves one page showing the current apple
  count read from MongoDB, plus `/healthz` (liveness) and `/readyz` (readiness, checks
  the DB connection).
- **mongo** — a single-replica MongoDB instance (StatefulSet), holding the `fruits`
  collection.
- **seed** — a Helm post-install/post-upgrade hook Job that inserts the exercise's fixed
  fruit data into `fruits` on every install/upgrade.

Each runs in its own container, per the brief.

## Network topology (local / kind)

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

## Network topology (AWS, bonus)

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
    +-- mongo StatefulSet (PVC-backed) -- mongo Service (headless)

VPC: 2 public subnets (ALB, NAT GW) + 2 private subnets (EKS nodes), across 2 AZs.
ECR holds the built app image; EKS nodes pull from it.
```

Same Helm chart as local — only `values-aws.yaml` differs (ingress enabled with an ALB
class, persistent storage enabled, password supplied at deploy time instead of a
checked-in dev default).

## Containers

| Container | Image               | Role                                  |
|-----------|---------------------|----------------------------------------|
| app       | built from `app/`   | serves the apples page                |
| mongo     | `mongo:7`           | data store                            |
| seed      | `mongo:7` (Job)     | one-shot: inserts the fixed fruit data|

## Security notes

- App and seed containers run as non-root with `allowPrivilegeEscalation: false`; the
  app's root filesystem is read-only (writable `/tmp` only).
- Mongo runs as non-root too; an init container (running briefly as root) `chown`s the
  data volume so the main container doesn't need root.
- Mongo credentials live in a Kubernetes `Secret`, never committed in plaintext. The
  local dev password is a throwaway value in `values-local.yaml`; the AWS path expects
  it supplied via `--set` at deploy time.
