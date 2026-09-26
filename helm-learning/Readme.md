# Helm Learning

Hands-on Helm lab for deploying a simple Nginx application to Kubernetes/EKS.

The lab covers Helm charts, values, templating, environment overrides, releases, upgrades, rollbacks, helpers, ConfigMaps, and Helm release history.

## Folder Structure

```text
.
├── Readme.md
└── my-web-app
    ├── Chart.yaml
    ├── templates
    │   ├── _helpers.tpl
    │   ├── configmap.yaml
    │   ├── deployment.yaml
    │   └── service.yaml
    ├── values.yaml
    ├── values-dev.yaml
    └── values-prod.yaml
```

### Files

* `Chart.yaml` — Helm chart metadata
* `values.yaml` — default configuration
* `values-dev.yaml` — DEV overrides
* `values-prod.yaml` — PROD overrides
* `deployment.yaml` — Kubernetes Deployment template
* `service.yaml` — Kubernetes Service template
* `configmap.yaml` — application configuration
* `_helpers.tpl` — reusable names and labels

---

## 1. Validate and Render

Validate the chart:

```bash
helm lint .
```

Render locally before deploying:

```bash
helm template dev-web . -f values-dev.yaml
```

Render a specific template:

```bash
helm template dev-web . \
  -f values-dev.yaml \
  --show-only templates/deployment.yaml
```

> `helm template` is one of the most useful troubleshooting commands. Always inspect the Kubernetes YAML Helm actually generates.

---

## 2. Values and Environment Overrides

Base configuration lives in:

```text
values.yaml
```

Environment configuration overrides it:

```bash
helm template dev-web . -f values-dev.yaml

helm template prod-web . -f values-prod.yaml
```

Value precedence:

```text
values.yaml
    ↓
-f values-dev.yaml
    ↓
--set
```

Later values override earlier values when they conflict.

---

## 3. Install

Create the namespace if required:

```bash
kubectl create namespace helm-learning
```

Install the DEV release:

```bash
helm install dev-web . \
  -n helm-learning \
  -f values-dev.yaml
```

Check:

```bash
helm list -n helm-learning

kubectl get deployment,pods,svc,configmap \
  -n helm-learning
```

---

## 4. Upgrade

After changing chart configuration:

```bash
helm upgrade dev-web . \
  -n helm-learning \
  -f values-dev.yaml
```

A common install-or-upgrade pattern is:

```bash
helm upgrade --install dev-web . \
  -n helm-learning \
  -f values-dev.yaml
```

---

## 5. Release History and Rollback

View Helm revisions:

```bash
helm history dev-web -n helm-learning
```

Rollback:

```bash
helm rollback dev-web <revision> \
  -n helm-learning
```

Important:

```text
Helm revision ≠ Kubernetes Deployment revision
```

A Helm revision can change a ConfigMap or Service without changing the Deployment Pod template.

---

## 6. Helm Templates

Important objects used in this chart:

```text
.Values         → configuration
.Release.Name   → Helm release name
.Chart.Name     → chart name
```

Example:

```yaml
replicas: {{ .Values.replicaCount }}
```

Useful template functions covered:

```text
if        → conditional rendering
range     → loop over values
with      → change template scope
default   → provide fallback
required  → require configuration
include   → call helper template
nindent   → correctly indent generated YAML
```

---

## 7. `_helpers.tpl`

Reusable naming and label logic lives in:

```text
templates/_helpers.tpl
```

Example usage:

```yaml
name: {{ include "my-web-app.name" . }}
```

This avoids duplicating naming and labeling logic across Deployment, Service, ConfigMap, etc.

---

## 8. ConfigMap → Pod

The ConfigMap provides:

```text
message = Hello from DEV!
```

The Deployment consumes it as:

```text
APP_MESSAGE
```

Verify:

```bash
kubectl exec -n helm-learning \
  deployment/dev-web-my-web-app \
  -- printenv APP_MESSAGE
```

Example:

```text
Hello from DEV!
```

### Important

Updating a ConfigMap does **not** update environment variables inside an already-running container.

```text
ConfigMap changes
      ↓
Existing Pod keeps old env value
```

---

## 9. ConfigMap Checksum

The Deployment uses:

```yaml
checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
```

This creates:

```text
ConfigMap change
      ↓
Checksum change
      ↓
Deployment Pod template change
      ↓
New ReplicaSet
      ↓
New Pods
```

This allows ConfigMap changes to automatically trigger a rolling deployment.

---

## 10. Helm Release Storage

Helm stores release history inside Kubernetes Secrets by default.

```bash
kubectl get secrets -n helm-learning
```

Example:

```text
sh.helm.release.v1.dev-web.v1
sh.helm.release.v1.dev-web.v2
sh.helm.release.v1.dev-web.v3
```

This enables:

```bash
helm history dev-web -n helm-learning
helm get values dev-web -n helm-learning
helm get manifest dev-web -n helm-learning
helm rollback dev-web <revision> -n helm-learning
```

---

## Key Learnings

```text
Chart
 ├── Templates → Kubernetes structure
 └── Values    → configuration
        ↓
      Helm
        ↓
Rendered Kubernetes manifests
        ↓
EKS / Kubernetes
```

Remember:

* Always use `helm lint` and `helm template` before deployment.
* Use environment-specific values instead of duplicating charts.
* `_helpers.tpl` keeps naming and labels reusable.
* YAML indentation and `nindent` are important.
* ConfigMap environment variables require new Pods to pick up changes.
* A checksum annotation can automatically trigger that rollout.
* Prefer `helm rollback` for Helm-managed applications.
* Helm history and Kubernetes Deployment history are separate.

### Troubleshooting Mental Model

Always compare:

```text
Git / Chart Source
        ↓
Helm Release State
        ↓
Live Kubernetes State
```

These three states can differ.
