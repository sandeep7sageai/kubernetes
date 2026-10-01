# EKS & Helm Learning — Part 3

## Helm Configuration, Secrets, Storage & Application Lifecycle

This repository contains the hands-on exercises from Part 3 of my EKS and Kubernetes learning project.

Part 1 focused on Helm fundamentals, while Part 2 explored production deployment behavior such as health probes, HPA, PDB, graceful shutdown, scheduling, affinity and rolling updates.

Part 3 moves deeper into application runtime concerns:

* ConfigMaps
* Kubernetes Secrets
* AWS Secrets Manager
* External Secrets Operator
* Persistent Volumes and Persistent Volume Claims
* EBS CSI Driver
* EKS Pod Identity for the CSI controller
* StatefulSets
* Headless Services
* Kubernetes Jobs
* Helm pre/post-upgrade hooks
* Deployment smoke tests
* Init Containers
* Failure handling and automatic rollback

The objective was not only to deploy these resources, but also to deliberately create failure scenarios and observe how Kubernetes and Helm behave.

---

## Repository Structure

```text
helm-config-secrets/
├── Readme.md
├── dependency-service.yaml
├── ebs-csi-pod-identity-trust.json
├── init-container-test.yaml
│
├── my-web-app/
│   ├── Chart.yaml
│   ├── values.yaml
│   ├── values-dev.yaml
│   ├── values-prod.yaml
│   │
│   └── templates/
│       ├── _helpers.tpl
│       ├── _secret.yaml
│       ├── configmap.yaml
│       ├── deployment.yaml
│       ├── external-secret.yaml
│       ├── hpa.yaml
│       ├── pdb.yaml
│       ├── service.yaml
│       │
│       └── hooks/
│           ├── migration-job.yaml
│           └── smoke-test-job.yaml
│
└── storage/
    ├── gp3-storageclass.yaml
    ├── pvc.yaml
    ├── storage-test-pod.yaml
    ├── storage-test.yaml
    │
    └── statefulset/
        ├── headless-service.yaml
        └── statefulset.yaml
```

---

# 1. ConfigMaps

The Helm chart uses a ConfigMap to separate application configuration from the container image.

Example configuration includes:

```text
APP_ENV
APP_REGION
FEATURE_X_ENABLED
LOG_LEVEL
```

Configuration was tested using both:

* Environment variables
* ConfigMap volume mounts

Example:

```bash
kubectl exec \
  -n helm-learning \
  deployment/config-web-my-web-app \
  -- printenv LOG_LEVEL
```

The mounted configuration was also inspected under:

```text
/etc/myapp/
```

### Key Learning

Environment variables are injected when a container starts. Updating the ConfigMap does not dynamically rewrite the environment of an existing process.

ConfigMaps mounted as volumes can be updated by Kubernetes, although the application itself must reread the files to consume the new configuration.

---

# 2. Kubernetes Secrets

Native Kubernetes Secrets were tested first to understand their behavior.

A secret containing database credentials was created and inspected.

Kubernetes displayed the values as Base64:

```text
DB_USERNAME
DB_PASSWORD
```

A value was decoded using:

```bash
echo "<base64-value>" | base64 -d
```

### Key Learning

Base64 is encoding, not encryption.

Storing plaintext production credentials directly inside Helm values or templates can expose secrets through source control, rendered manifests, CI/CD systems or Helm release data.

This led to the External Secrets implementation.

---

# 3. External Secrets Operator

The cluster already contained the External Secrets Operator.

The following cluster-wide store was available:

```text
aws-secret-manager-useast1
```

It uses AWS Secrets Manager in:

```text
us-east-1
```

The External Secrets controller authenticates to AWS using its Kubernetes ServiceAccount and AWS workload identity.

The application secret was stored in AWS Secrets Manager under:

```text
helm-learning/config-web/database
```

The Helm chart creates an `ExternalSecret` that maps remote properties into a Kubernetes Secret:

```text
AWS Secrets Manager
        │
        ▼
ClusterSecretStore
        │
        ▼
ExternalSecret
        │
        ▼
External Secrets Operator
        │
        ▼
Kubernetes Secret
        │
        ▼
Application Pod
```

Synchronization was verified with:

```bash
kubectl get externalsecret \
  -n helm-learning
```

Expected state:

```text
STATUS         READY
SecretSynced   True
```

---

# 4. Persistent Storage

The storage exercises are located under:

```text
storage/
```

The lab explored:

```text
StorageClass
     ↓
PVC
     ↓
PV
     ↓
EBS CSI Driver
     ↓
AWS EBS
```

---

# 5. EBS CSI Driver

The original cluster contained an older `gp2` StorageClass using:

```text
kubernetes.io/aws-ebs
```

but no functioning EBS CSI controller/node components were installed.

The AWS EBS CSI add-on was installed and verified.

Controller:

```text
ebs-csi-controller
```

Node plugin:

```text
ebs-csi-node
```

CSI driver:

```text
ebs.csi.aws.com
```

The controller ServiceAccount uses EKS Pod Identity to obtain the AWS permissions required to manage EBS volumes.

The Pod Identity trust policy used during the exercise is stored in:

```text
ebs-csi-pod-identity-trust.json
```

---

# 6. Dynamic EBS Provisioning

A CSI-based gp3 StorageClass was created:

```text
storage/gp3-storageclass.yaml
```

A PVC then requested storage:

```text
storage/pvc.yaml
```

Kubernetes dynamically provisioned a 2 GiB EBS-backed PersistentVolume.

The relationship was:

```text
Pod
 ↓
PVC
 ↓
PV
 ↓
EBS Volume
```

The test Pod successfully mounted the volume.

### Key Learning

The application requests storage using a PVC. It does not need to know the underlying EBS volume ID.

The StorageClass and CSI driver handle provisioning.

---

# 7. WaitForFirstConsumer

The StorageClass uses topology-aware volume provisioning.

This is important because EBS volumes are Availability Zone scoped.

Instead of provisioning storage before Pod placement is known:

```text
PVC
 ↓
Pod scheduling
 ↓
Availability Zone selected
 ↓
EBS volume provisioned
```

This prevents the scheduler from ending up with a Pod and EBS volume in incompatible Availability Zones.

---

# 8. StatefulSets

The StatefulSet exercises are located under:

```text
storage/statefulset/
```

They demonstrate the three important StatefulSet properties:

```text
Stable Pod Identity
Stable Network Identity
Stable Storage Identity
```

StatefulSet Pods receive predictable names:

```text
storage-demo-0
storage-demo-1
storage-demo-2
```

Individual replicas can retain their own persistent storage.

---

# 9. Headless Service

The StatefulSet uses:

```text
headless-service.yaml
```

with:

```yaml
clusterIP: None
```

This enables individual StatefulSet members to receive stable DNS identities.

Conceptually:

```text
storage-demo-0.storage-demo
storage-demo-1.storage-demo
storage-demo-2.storage-demo
```

Unlike a normal Service, where clients generally connect to any healthy replica, a headless Service can support discovery of specific StatefulSet members.

This is useful for distributed systems where individual members have distinct identities.

---

# 10. Kubernetes Jobs and Helm Hooks

The Helm chart contains:

```text
templates/hooks/
├── migration-job.yaml
└── smoke-test-job.yaml
```

These demonstrate two different stages of the deployment lifecycle.

---

## Pre-Upgrade Migration

`migration-job.yaml` uses a Helm:

```text
pre-upgrade
```

hook.

Deployment flow:

```text
helm upgrade
     ↓
Migration Job
     ↓
Success?
   /        \
 NO          YES
 │            │
STOP          ▼
          Upgrade
```

A failed migration was deliberately tested.

Helm correctly marked the upgrade as failed and, when used with:

```text
--rollback-on-failure
```

restored the previous release.

### Key Learning

A pre-upgrade hook is useful when an operation must succeed before the application upgrade is allowed to continue.

Database schema migration is a common example.

---

# 11. Post-Upgrade Smoke Test

`smoke-test-job.yaml` uses:

```text
post-upgrade
```

The Job calls the application through its Kubernetes Service:

```text
Smoke Test Job
      ↓
config-web Service
      ↓
Application Pod
      ↓
HTTP response
```

A successful test confirms more than simply checking that a Pod exists.

It validates that the deployed application is reachable through the normal Kubernetes networking path.

---

# 12. Smoke-Test Failure

The test endpoint was deliberately changed to:

```text
/does-not-exist
```

nginx returned:

```text
HTTP 404
```

The curl command used:

```bash
curl --fail
```

which returned a non-zero exit code.

Initially, however, the script continued executing successful `echo` commands, causing the container to exit successfully.

The script was corrected using:

```bash
set -e
```

After the fix:

```text
HTTP 404
   ↓
curl fails
   ↓
shell exits
   ↓
Pod fails
   ↓
Job fails
   ↓
post-upgrade hook fails
   ↓
Helm detects failed release
   ↓
automatic rollback
```

### Key Learning

CI/CD and deployment scripts must propagate command failures correctly.

A failed command inside a shell script does not necessarily mean the overall script will return failure.

---

# 13. Pre-Upgrade vs Post-Upgrade Failure

The exercises demonstrated both failure points.

### Pre-Upgrade Failure

```text
Migration
   ↓
FAIL
   ↓
Application upgrade does not proceed
```

### Post-Upgrade Failure

```text
Migration
   ↓
SUCCESS
   ↓
Application upgraded
   ↓
Smoke test
   ↓
FAIL
   ↓
ROLLBACK
```

This distinction is important when designing deployment pipelines.

---

# 14. Helm Resource Drift

During the lab, a ConfigMap field produced a server-side apply ownership conflict after it had previously been modified using `kubectl edit`.

The conflict referenced:

```text
kubectl-edit
.data.LOG_LEVEL
```

### Key Learning

Avoid manually modifying resources that are declaratively managed by Helm unless there is a specific operational reason.

The desired state should normally flow from:

```text
Git
 ↓
Helm chart / values
 ↓
Kubernetes
```

Manual cluster changes can create configuration drift and field ownership conflicts.

---

# 15. Init Containers

The standalone example is:

```text
init-container-test.yaml
```

An init container executes before the application's regular containers.

```text
Pod Created
     ↓
Init Container
     ↓
Dependency Available?
    /             \
   NO             YES
   │               │
 retry             ▼
             Application Starts
```

The lab used an init container to wait for an application dependency.

---

# 16. Helm-Configurable Init Container

The init-container behavior was then integrated into the Helm chart and controlled through values.

Conceptually:

```text
values.yaml
     ↓
initContainer.enabled
     ↓
deployment.yaml
     ↓
initContainers:
```

This allows the feature to be enabled or configured differently between environments without maintaining separate Deployment templates.

---

# 17. Dependency Service

The lab dependency is defined in:

```text
dependency-service.yaml
```

It provides a simple network dependency for studying init-container behavior.

The dependency exists only for learning purposes; nginx is used as a lightweight reachable service rather than representing a real database implementation.

---

# 18. Init Container vs Helm Hook

These solve different problems.

### Helm Hook

```text
Release lifecycle
```

Example:

> Run a database migration once before application version 2 is deployed.

### Init Container

```text
Pod lifecycle
```

Example:

> Every new Pod must wait for a required dependency before starting its application container.

---

# 19. Init Container vs Probes

The lifecycle can be remembered as:

```text
Pod Created
    ↓
Init Container
    ↓
Application Starts
    ↓
Startup Probe
    ↓
Readiness Probe
    ↓
Service Traffic
    ↓
Liveness Probe continues monitoring
```

The questions they answer are different:

```text
Init Container
→ Should the application start yet?

Startup Probe
→ Has the application finished starting?

Readiness Probe
→ Should this Pod receive traffic?

Liveness Probe
→ Should Kubernetes restart this container?
```

---

# 20. Init Containers and Rolling Updates

The dependency was deliberately made unavailable while new application Pods were created.

The new Pods remained in initialization because their dependency was unavailable.

Existing healthy replicas could remain available while the rollout waited for new replicas.

This ties together Part 2 and Part 3 concepts:

```text
Dependency unavailable
        ↓
Init container waits
        ↓
New Pod not Ready
        ↓
RollingUpdate cannot safely progress
        ↓
Existing Ready Pods protect availability
```

When the dependency returned:

```text
Dependency restored
       ↓
Init container succeeds
       ↓
Application starts
       ↓
Pod becomes Ready
       ↓
RollingUpdate continues
```

---

# Useful Commands

Inspect application configuration:

```bash
kubectl exec \
  -n helm-learning \
  deployment/config-web-my-web-app \
  -- printenv LOG_LEVEL
```

Inspect External Secrets:

```bash
kubectl get externalsecret -n helm-learning

kubectl describe externalsecret \
  config-web-my-web-app-database \
  -n helm-learning
```

Inspect persistent storage:

```bash
kubectl get storageclass
kubectl get pvc -A
kubectl get pv
kubectl get csidriver
kubectl get csinode
```

Inspect the EBS CSI driver:

```bash
kubectl get deployment,daemonset \
  -n kube-system | grep ebs
```

Inspect Helm history:

```bash
helm history config-web \
  -n helm-learning
```

Inspect hook Jobs:

```bash
kubectl get jobs \
  -n helm-learning
```

Migration logs:

```bash
kubectl logs \
  -n helm-learning \
  job/config-web-my-web-app-migration
```

Smoke-test logs:

```bash
kubectl logs \
  -n helm-learning \
  job/config-web-my-web-app-smoke-test
```

Render a template before deployment:

```bash
helm template config-web . \
  -n helm-learning \
  -f values-dev.yaml
```

Upgrade safely:

```bash
helm upgrade config-web . \
  -n helm-learning \
  -f values-dev.yaml \
  --rollback-on-failure \
  --timeout 5m
```

---

# Key Takeaways

Part 3 demonstrated that running an application in Kubernetes involves much more than creating a Deployment.

A production application needs clear strategies for:

* Runtime configuration
* Secret management
* Cloud workload identity
* Persistent storage
* Stateful workloads
* Dependency handling
* Database migrations
* Deployment validation
* Failure propagation
* Rollback

The major architecture pattern demonstrated throughout the lab was:

```text
Declarative configuration
        +
Kubernetes controllers
        +
AWS managed services
        +
Helm release lifecycle
        ↓
Predictable application operations
```

The most important lesson is to understand not only what each Kubernetes resource does individually, but how the resources and controllers interact during normal operation and failure.
