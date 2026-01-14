# Self-Healing Infrastructure on AWS using Terraform & EKS

This project demonstrates how to build a **self-healing, highly available application infrastructure** on AWS using **Terraform** for Infrastructure as Code (IaC) and **Kubernetes (EKS)** for application orchestration.

The system automatically recovers from:
- Pod failures (handled by Kubernetes)
- Node failures (handled by EKS managed node groups backed by Auto Scaling)

---

## Architecture Overview

- **Terraform**
  - Creates AWS infrastructure (VPC, subnets, routing, security groups)
  - Provisions an **EKS cluster**
  - Provisions an **EKS managed node group**

- **Kubernetes (EKS)**
  - Runs containerized applications
  - Maintains desired state using Deployments
  - Exposes applications using Services

### High Availability Design
- Single AWS **region** (`ap-south-1`)
- Multiple **Availability Zones** (`ap-south-1a`, `ap-south-1b`)
- EKS control plane spread across AZs
- Worker nodes distributed across AZs

---

## Prerequisites

Install and configure the following:

```bash
# Terraform
terraform --version

# AWS CLI
aws --version
aws configure

# kubectl
kubectl version --client
````

AWS credentials must have permissions for:

* VPC
* EC2
* IAM
* EKS

---

## Project Structure

```text
.
├── main.tf
├── provider.tf
├── modules/
│   ├── network/
│   │   ├── main.tf
│   │   ├── outputs.tf
│   ├── security/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   ├── eks/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
├── deployment.yaml
├── service.yaml
```

---

## Step 1: Initialize Terraform

```bash
terraform init
```

If module changes are made:

```bash
terraform init -reconfigure
```

---

## Step 2: Network Infrastructure (Multi-AZ)

The network module creates:

* One VPC
* Two public subnets (in different AZs)
* Internet Gateway
* Route Table & associations

> **Important Fix:**
> EKS requires **at least two subnets in different Availability Zones**.
> Single-subnet clusters will fail creation.

---

## Step 3: Security Group

The security module creates a security group that allows:

* SSH (22)
* HTTP (80)
* All outbound traffic

---

## Step 4: EKS Cluster & Node Group

Terraform provisions:

* EKS control plane
* IAM roles for cluster & nodes
* Managed node group (EC2 workers)

### Apply Infrastructure

```bash
terraform plan
terraform apply
```

⏱️ EKS creation may take **10–15 minutes**.

---

## Step 5: Configure kubectl

Connect your local machine to the EKS cluster:

```bash
aws eks update-kubeconfig \
  --region ap-south-1 \
  --name self-healing-eks
```

Verify nodes:

```bash
kubectl get nodes
```

Expected status: `Ready`

---

## Step 6: Deploy Application (Kubernetes)

### Deployment (`deployment.yaml`)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: demo
  template:
    metadata:
      labels:
        app: demo
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
```

Apply:

```bash
kubectl apply -f deployment.yaml
kubectl get pods
```

---

### Service (`service.yaml`)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: demo-service
spec:
  type: LoadBalancer
  selector:
    app: demo
  ports:
  - port: 80
    targetPort: 80
```

Apply:

```bash
kubectl apply -f service.yaml
kubectl get svc
```

Access the app using the `EXTERNAL-IP`.

---

## Self-Healing Demonstration

### Pod-Level Healing

```bash
kubectl delete pod <pod-name>
kubectl get pods
```

Kubernetes automatically recreates the pod.

### Node-Level Healing

If a worker node fails:

* AWS Auto Scaling replaces the EC2 instance
* Kubernetes reschedules pods automatically

---

## Real-World Issues Faced & Fixes

### Issue: EKS resources not appearing in `terraform plan`

**Cause:**
Terraform silently ignored EKS resources due to file encoding / parsing issues on Windows.

**Fix:**
Recreated `modules/eks/main.tf` cleanly and validated with a dummy resource.

---

### Issue: EKS cluster deletion stuck (ENIs not deleting)

**Problem:**

During `terraform destroy`, multiple AWS resources failed to delete, including:

* EKS Cluster
* VPC
* Subnets
* Internet Gateway
* Security Groups

Terraform was stuck because **Elastic Network Interfaces (ENIs)** created by the **AWS VPC CNI plugin** were still present and marked as “in use”.

---

**Root Cause:**

* EKS uses the **AWS VPC CNI** for pod networking
* The CNI creates **secondary ENIs** attached to worker nodes
* Even after node group deletion, ENIs may remain due to:

  * asynchronous cleanup
  * orphaned CNI attachments
* AWS blocks deletion of:

  * VPC
  * Subnets
  * Security Groups
    while dependent ENIs still exist

This caused Terraform to hang indefinitely during destroy.

---

**How the Issue Was Diagnosed:**

First, all remaining ENIs were listed:

```bash
aws ec2 describe-network-interfaces \
  --filters Name=status,Values=in-use
```

The ENIs had descriptions containing:

* `aws-node`
* `eks`
* `cni`

confirming they were created by the **EKS AWS CNI plugin**.

---

**Critical Insight (What Actually Fixed It):**

ENIs **cannot be deleted directly** if their **parent attachment** still exists.

So instead of deleting the ENI first, the **parent attachment** had to be identified and removed.

To inspect the ENI and find its parent:

```bash
aws ec2 describe-network-interfaces \
  --network-interface-ids <eni-id>
```

This revealed the **attachment ID** holding the ENI.

---

**Correct Deletion Order (What Worked):**

1. **Identify the ENI attachment (parent)**
2. **Detach the ENI from its parent first**

```bash
aws ec2 detach-network-interface \
  --attachment-id <attachment-id>
```

3. **Delete the ENI only after detachment**

```bash
aws ec2 delete-network-interface \
  --network-interface-id <eni-id>
```

4. Once ENIs were deleted, Terraform was able to successfully destroy:

   * Security Groups
   * Subnets
   * Internet Gateway
   * VPC

---

**Why This Happens (Important Learning):**

This is **not a Terraform bug**.

It happens because:

* EKS networking is AWS-managed
* CNI cleanup is asynchronous
* ENIs enforce strict dependency rules

Terraform cannot override these dependencies.

---

**Preventive Best Practice (Learned):**

Before running `terraform destroy` on EKS infrastructure:

```bash
kubectl delete all --all
kubectl delete svc --all
kubectl get nodes
```

Wait until:

* All pods are deleted
* Node count reaches `0`

Only then run:

```bash
terraform destroy
```

This significantly reduces the chance of leftover ENIs and stuck deletions.

---

## Safe Destroy Procedure (IMPORTANT)

### Step 1: Delete Kubernetes resources FIRST

```bash
kubectl delete all --all
kubectl delete svc --all
kubectl get nodes
```

Wait until nodes count reaches `0`.

---

### Step 2: Destroy Infrastructure

```bash
terraform destroy
```

If EKS was manually deleted:

```bash
terraform state rm module.eks.aws_eks_cluster.this
terraform state rm module.eks.aws_eks_node_group.this
terraform destroy
```

---

## Cost Awareness

* EKS control plane: ~$0.10/hour
* EC2 nodes: small hourly cost
* Always destroy resources after testing

---

## Key Learnings

* Terraform manages infrastructure state, not application state
* Kubernetes maintains desired application state
* EKS node groups are AWS-managed and backed by Auto Scaling Groups
* Multi-AZ design is mandatory for production-grade clusters
* Proper destroy order prevents stuck resources and extra billing

---

