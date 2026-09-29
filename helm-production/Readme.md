# Helm Part 2 — Production Workloads, Reliability & Scheduling

Hands-on Helm/EKS lab covering production workload configuration, availability, autoscaling, graceful shutdown, and Kubernetes scheduling.

## Topics Covered

* CPU & memory requests/limits
* CPU throttling and OOMKilled behavior
* Kubernetes QoS classes
* Readiness, liveness, and startup probes
* RollingUpdate strategy
* Helm `--rollback-on-failure`
* Horizontal Pod Autoscaler (HPA)
* HPA vs Cluster Autoscaler
* PodDisruptionBudget (PDB)
* Kubernetes Eviction API
* Graceful termination (`SIGTERM` / `SIGKILL`)
* `preStop` and `terminationGracePeriodSeconds`
* Node selector and node affinity
* Taints and tolerations
* Pod anti-affinity
* Topology spread constraints

## Repository Structure

```text
.
├── Chart.yaml
├── graceful-test.yaml
├── scheduling-test.yaml
├── templates
│   ├── _helpers.tpl
│   ├── configmap.yaml
│   ├── deployment.yaml
│   ├── hpa.yaml
│   ├── pdb.yaml
│   └── service.yaml
├── tmp
│   └── eviction.json
├── values-dev.yaml
├── values-prod.yaml
└── values.yaml
```

### Lab Files

`graceful-test.yaml`

* SIGTERM handling
* graceful shutdown
* `preStop`
* termination grace period
* SIGKILL behavior

`scheduling-test.yaml`

* node selector testing
* Pending Pod troubleshooting
* scheduler `FailedScheduling` events

`tmp/eviction.json`

* manual Kubernetes Eviction API testing
* verifies PDB behavior

## Useful Commands

Render and validate:

```bash
helm lint .

helm template dev-web . \
  -n helm-learning \
  -f values-dev.yaml
```

Deploy:

```bash
helm upgrade --install dev-web . \
  -n helm-learning \
  -f values-dev.yaml \
  --rollback-on-failure \
  --timeout 5m
```

Inspect resources:

```bash
kubectl get pods -n helm-learning -o wide
kubectl get hpa -n helm-learning
kubectl get pdb -n helm-learning
kubectl top pod -n helm-learning
kubectl describe pod <pod> -n helm-learning
```

Helm history:

```bash
helm history dev-web -n helm-learning
```

## Key Learnings

```text
Requests → Scheduling
Limits   → Runtime enforcement

CPU limit    → Throttling
Memory limit → OOMKilled

Readiness → Traffic
Liveness  → Restart
Startup   → Startup protection

HPA                → Scales Pods
Cluster Autoscaler → Scales Nodes

PDB → Protects voluntary disruption

Required affinity  → Filters nodes
Preferred affinity → Scores nodes

Taint      → Node repels Pod
Toleration → Pod is allowed onto tainted node

Anti-affinity   → Avoid Pod co-location
Topology spread → Balance replicas
```

## Troubleshooting Rule

When a Pod is `Pending`:

```bash
kubectl describe pod <pod> -n helm-learning
```

Check **Events** for:

```text
Insufficient cpu/memory
node selector/affinity mismatch
untolerated taints
scheduling constraints
```

## Production Takeaway

A production Kubernetes workload requires more than a Deployment:

```text
Resources
+ Health Checks
+ Safe Rollouts
+ Autoscaling
+ Disruption Protection
+ Graceful Shutdown
+ Scheduling
+ Failure-Domain Distribution
```

Together these determine application **reliability, availability, scalability, and resilience**.
