# About 


PART 1 — helm-learning
Helm Fundamentals
      │
      ▼
Chart structure
Templates
Values
Install / Upgrade
History / Rollback
      │
      ▼
PART 2 — helm-production
Production Deployment Behavior
      │
      ▼
Resources
Health probes
HPA
PDB
Graceful shutdown
Scheduling
Affinity
Cluster Autoscaler
Rolling updates
      │
      ▼
PART 3 — helm-config-secrets
Application State & Lifecycle
      │
      ▼
ConfigMaps
Secrets
External Secrets
Persistent Storage
EBS CSI
StatefulSets
Jobs
Helm Hooks
Smoke Tests
Init Containers


# Few important tips

----------------------------------------------------------------------------------------------
View the active KubeConfig

kubectl config view  (detailed)

kubectl config current-context

----------------------------------------------------------------------------------------------


----------------------------------------------------------------------------------------------

To generate kubeconfig
aws eks --region {AWS_REGION} update-kubeconfig --name {eks_cluster_name} --profile account-nonprod-admin

To test a temporary context
export KUBECONFIG=/tmp/cluster_01.tmp
aws eks update-kubeconfig --name {eks_cluster_name} --region {AWS_REGION} --profile account-nonprod-developer

To switch
unset KUBECONFIG

----------------------------------------------------------------------------------------------


----------------------------------------------------------------------------------------------

kubectl auth can-i <verb> <resource> 
– Checks RBAC (Role-Based Access Control) permissions to verify if a user or service account can perform a specific action (e.g., kubectl auth can-i create pods)


---------------------------------------------------------------------------------------------
