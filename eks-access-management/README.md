# EKS Access Management & Workload Identity Lab

Hands-on lab demonstrating **human access management and workload identity in Amazon EKS**.

The lab covers three important EKS security concepts:

1. **EKS Access Entries + Kubernetes RBAC** for human access
2. **EKS Pod Identity** for workload access to DynamoDB
3. **IRSA (IAM Roles for Service Accounts)** for workload access to S3

---

## Architecture

### Human Access

```text
IAM Identity Center
        │
        ▼
IAM Role
VA-Role-ReadOnly
        │
        ▼
EKS Access Entry
        │
        ▼
Kubernetes Group
VA_User
        │
        ▼
RoleBinding
        │
        ▼
Role
        │
        ▼
va-test namespace
```

### EKS Pod Identity

```text
dynamodb-pod
      │
      ▼
dynamodb-sa
      │
      ▼
EKS Pod Identity Association
      │
      ▼
va-test-dynamodb-pod-role
      │
      ▼
DynamoDB
```

### IRSA

```text
s3-pod
   │
   ▼
s3-sa
   │
   ▼
ServiceAccount JWT
   │
   ▼
EKS OIDC Provider
   │
   ▼
AWS STS
AssumeRoleWithWebIdentity
   │
   ▼
va-test-s3-irsa-role
   │
   ▼
Amazon S3
```

---

## Repository Structure

```text
eks-access-management/
├── irsa-pod/
│   ├── s3-irsa-trust.json
│   ├── s3-pod.yaml
│   ├── s3-policy.json
│   └── s3-sa.yaml
│
├── pod-identity-pod/
│   ├── dynamodb-pod.yaml
│   ├── dynamodb-policy.json
│   ├── dynamodb-sa.yaml
│   └── pod-identity-trust.json
│
├── va-test-pod.yaml
├── va-test-role.yaml
└── va-test-rolebinding.yaml
```

---

## Part 1 — Human Access

Part 1 demonstrates how an IAM Identity Center user receives namespace-scoped Kubernetes access.

```text
IAM Identity Center
        ↓
IAM Role
        ↓
EKS Access Entry
        ↓
Kubernetes Group
        ↓
RoleBinding
        ↓
Role
```

The Kubernetes Role grants Pod permissions only within:

```text
va-test
```

The user can perform operations such as:

```bash
kubectl get pods -n va-test
kubectl apply -f va-test-pod.yaml
kubectl exec -it <pod> -n va-test -- /bin/sh
```

but does not receive unrestricted cluster-wide access.

---

## Part 2 — Workload Identity

Part 2 demonstrates that **the AWS identity of a Pod is independent from the AWS identity of the human who created the Pod**.

Two mechanisms are compared.

### EKS Pod Identity

```text
dynamodb-pod
      ↓
dynamodb-sa
      ↓
Pod Identity Association
      ↓
IAM Role
      ↓
dynamodb:ListTables
```

The workload identity can be verified from inside the Pod:

```bash
aws sts get-caller-identity
aws dynamodb list-tables
```

Pod Identity credentials can also be observed through variables such as:

```text
AWS_CONTAINER_CREDENTIALS_FULL_URI
AWS_CONTAINER_AUTHORIZATION_TOKEN_FILE
```

---

### IRSA

```text
s3-pod
   ↓
s3-sa
   ↓
OIDC JWT
   ↓
AWS STS
   ↓
IAM Role
   ↓
s3:ListAllMyBuckets
```

The IRSA IAM trust policy restricts access to:

```text
system:serviceaccount:va-test:s3-sa
```

The ServiceAccount points to the IAM role using:

```text
eks.amazonaws.com/role-arn
```

The workload can then verify its AWS identity and access:

```bash
aws sts get-caller-identity
aws s3 ls
```

---

## Pod Identity vs IRSA

|                            | EKS Pod Identity                     | IRSA                          |
| -------------------------- | ------------------------------------ | ----------------------------- |
| Kubernetes identity        | ServiceAccount                       | ServiceAccount                |
| IAM trust                  | `pods.eks.amazonaws.com`             | Cluster OIDC provider         |
| Role mapping               | Pod Identity Association             | ServiceAccount annotation     |
| AWS credentials            | Temporary                            | Temporary                     |
| OIDC IAM provider required | No                                   | Yes                           |
| Credential clue            | `AWS_CONTAINER_CREDENTIALS_FULL_URI` | `AWS_WEB_IDENTITY_TOKEN_FILE` |

---

## Key Learning

The most important distinction from this lab is that **human access and workload access solve different problems**.

```text
Human Access
────────────

SSO → IAM Role → EKS Access Entry → RBAC → Kubernetes

Answers:
"What can this person do in the cluster?"


Workload Access
───────────────

Pod → ServiceAccount → Pod Identity / IRSA → IAM Role → AWS

Answers:
"What can this application do in AWS?"
```

A Pod does **not inherit the AWS permissions of the person who created it**.

---

## Troubleshooting Mental Model

```text
kubectl → Unauthorized
    ↓
Authentication problem


kubectl → Forbidden
    ↓
Kubernetes RBAC problem


Pod → wrong AWS identity
    ↓
ServiceAccount / Pod Identity / IRSA problem


Pod → correct IAM role → AccessDenied
    ↓
IAM permissions problem
```

This separation makes EKS access troubleshooting significantly easier.

---

## Security Notes

* Use least-privilege IAM permissions.
* Use namespace-scoped Kubernetes Roles where cluster-wide access is unnecessary.
* Restrict IRSA trust policies to specific namespaces and ServiceAccounts.
* Do not store long-lived AWS access keys in Pods, Kubernetes manifests, or Git repositories.
* Use `aws sts get-caller-identity` when troubleshooting workload identity.
* Do not commit projected ServiceAccount tokens or temporary AWS credentials.

---

## Lab Objective

By completing this lab, you should be able to explain the difference between:

```text
EKS authentication
Kubernetes RBAC
Kubernetes ServiceAccounts
EKS Access Entries
EKS Pod Identity
IRSA
IAM role trust policies
IAM permissions policies
```

and understand how these components work together to securely connect **humans → Kubernetes** and **Kubernetes workloads → AWS**.
