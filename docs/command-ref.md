# Starfleet GKE Platform — Command Reference

This document contains the common commands used to build, validate, operate, troubleshoot, and destroy the Starfleet GKE Platform lab.

## Repository

```text
starfleet-gke-platform/
├── backend.tf
├── versions.tf
├── provider.tf
├── variables.tf
├── outputs.tf
├── network.tf
├── gke-alpha.tf
├── gke-delta.tf
├── artifact-registry.tf
└── docs/
    ├── COMMANDS.md
    └── ...
```

The platform is managed using Terraform and Google Cloud CLI.

---

# 1. Select the GCP Project

Set the active project:

```bash
gcloud config set project starfleet-gke-platform-lab
```

Verify:

```bash
gcloud config get-value project
```

List the current gcloud configuration:

```bash
gcloud config list
```

---

# 2. Terraform Initialization

Run Terraform commands from the root of the platform repository:

```bash
cd /Users/sd/workspace/starfleet-gke-platform
```

Initialize Terraform:

```bash
terraform init
```

Terraform initialization downloads the required providers and initializes the configured state backend.

---

# 3. Format Terraform

Format all Terraform files:

```bash
terraform fmt
```

Check formatting without modifying files:

```bash
terraform fmt -check
```

---

# 4. Validate Terraform

Validate the Terraform configuration:

```bash
terraform validate
```

Expected result:

```text
Success! The configuration is valid.
```

---

# 5. Review Terraform Plan

Always review the execution plan before applying infrastructure changes:

```bash
terraform plan
```

Example:

```text
Plan: 2 to add, 0 to change, 0 to destroy.
```

Pay particular attention to resources marked for destruction.

For important changes, save the plan:

```bash
terraform plan -out=tfplan
```

Apply exactly that plan:

```bash
terraform apply tfplan
```

---

# 6. Apply Infrastructure

Apply Terraform changes:

```bash
terraform apply
```

Review the plan and enter:

```text
yes
```

when Terraform requests confirmation.

---

# 7. Inspect Terraform State

List Terraform-managed resources:

```bash
terraform state list
```

Example resources include:

```text
google_compute_network.starfleet_vpc
google_compute_subnetwork.alpha_quadrant
google_compute_subnetwork.delta_quadrant
google_container_cluster.alpha
google_container_node_pool.alpha_nodes
google_container_cluster.delta
google_container_node_pool.delta_nodes
google_artifact_registry_repository.starfleet_apps
```

Inspect a particular resource:

```bash
terraform state show google_container_cluster.alpha
```

---

# 8. Verify the VPC

List GCP VPC networks:

```bash
gcloud compute networks list
```

Expected custom network:

```text
starfleet-vpc
```

Inspect the network:

```bash
gcloud compute networks describe starfleet-vpc
```

---

# 9. Verify Subnets

List subnets:

```bash
gcloud compute networks subnets list \
  --network=starfleet-vpc
```

Expected subnets:

```text
alpha-quadrant-subnet
delta-quadrant-subnet
```

The current network design is:

```text
starfleet-vpc
│
├── alpha-quadrant-subnet
│   Region: us-central1
│   Nodes: 10.10.0.0/24
│   Pods: 10.20.0.0/16
│   Services: 10.30.0.0/20
│
└── delta-quadrant-subnet
    Region: us-east1
    Nodes: 10.40.0.0/24
    Pods: 10.50.0.0/16
    Services: 10.60.0.0/20
```

---

# 10. List GKE Clusters

```bash
gcloud container clusters list
```

Expected clusters:

```text
enterprise-gke-alpha
enterprise-gke-delta
```

---

# 11. Connect kubectl to Alpha

Retrieve Alpha cluster credentials:

```bash
gcloud container clusters get-credentials enterprise-gke-alpha \
  --zone us-central1-a \
  --project starfleet-gke-platform-lab
```

Verify:

```bash
kubectl config current-context
```

Check nodes:

```bash
kubectl get nodes -o wide
```

---

# 12. Connect kubectl to Delta

Retrieve Delta cluster credentials:

```bash
gcloud container clusters get-credentials enterprise-gke-delta \
  --zone us-east1-b \
  --project starfleet-gke-platform-lab
```

Verify:

```bash
kubectl config current-context
```

Check nodes:

```bash
kubectl get nodes -o wide
```

---

# 13. Switch Between Alpha and Delta

List available Kubernetes contexts:

```bash
kubectl config get-contexts
```

Get the current context:

```bash
kubectl config current-context
```

Switch to Alpha:

```bash
kubectl config use-context \
  gke_starfleet-gke-platform-lab_us-central1-a_enterprise-gke-alpha
```

Switch to Delta:

```bash
kubectl config use-context \
  gke_starfleet-gke-platform-lab_us-east1-b_enterprise-gke-delta
```

Always verify the active context before deploying:

```bash
kubectl config current-context
```

This is especially important because the same Kubernetes manifests may be deployed to both clusters.

---

# 14. Inspect Cluster Workloads

List application pods:

```bash
kubectl get pods
```

Show pod placement and IP addresses:

```bash
kubectl get pods -o wide
```

List pods in all namespaces:

```bash
kubectl get pods -A
```

List Deployments:

```bash
kubectl get deployments
```

List Services:

```bash
kubectl get services
```

---

# 15. Check Replica Distribution

Show which node each pod is running on:

```bash
kubectl get pods -o wide
```

The applications use topology spread constraints so replicas can be distributed across worker nodes.

A desired two-node layout is:

```text
Node 1
├── Navigation replica
└── Communications replica

Node 2
├── Navigation replica
└── Communications replica
```

---

# 16. Troubleshoot a Pod

List pods:

```bash
kubectl get pods -o wide
```

Describe a problem pod:

```bash
kubectl describe pod <pod-name>
```

Check application logs:

```bash
kubectl logs <pod-name>
```

Follow logs:

```bash
kubectl logs -f <pod-name>
```

Check recent Kubernetes events:

```bash
kubectl get events --sort-by=.lastTimestamp
```

Common states to investigate include:

```text
Pending
ImagePullBackOff
CrashLoopBackOff
0/1 Running
```

---

# 17. Check Deployment Rollouts

Navigation Service:

```bash
kubectl rollout status deployment/starfleet-navigation-service
```

Communications Service:

```bash
kubectl rollout status deployment/starfleet-communications-service
```

View rollout history:

```bash
kubectl rollout history deployment/starfleet-navigation-service
```

---

# 18. Artifact Registry

List repositories:

```bash
gcloud artifacts repositories list
```

List Starfleet application images:

```bash
gcloud artifacts docker images list \
  us-central1-docker.pkg.dev/starfleet-gke-platform-lab/starfleet-apps
```

Include image tags:

```bash
gcloud artifacts docker images list \
  us-central1-docker.pkg.dev/starfleet-gke-platform-lab/starfleet-apps \
  --include-tags
```

---

# 19. Verify Container Architecture

The GKE worker nodes use the `amd64` architecture.

Check node architecture:

```bash
kubectl get node \
  -o jsonpath='{.items[0].status.nodeInfo.architecture}{"\n"}'
```

Inspect an application image:

```bash
docker buildx imagetools inspect <IMAGE>
```

Application images deployed to these GKE nodes should contain:

```text
Platform: linux/amd64
```

When building from an Apple Silicon Mac, explicitly specify the platform:

```bash
docker buildx build \
  --platform linux/amd64 \
  -t <IMAGE>:<VERSION> \
  --push \
  .
```

---

# 20. Check Public Services

List Kubernetes Services:

```bash
kubectl get services
```

For a LoadBalancer Service, look for:

```text
TYPE           EXTERNAL-IP
LoadBalancer   <public-ip>
```

Inspect a Service:

```bash
kubectl describe service <service-name>
```

Check its backend endpoints:

```bash
kubectl get endpoints <service-name>
```

---

# 21. Test Application Health

Navigation Service:

```bash
curl http://<NAVIGATION_EXTERNAL_IP>/
curl http://<NAVIGATION_EXTERNAL_IP>/health
curl http://<NAVIGATION_EXTERNAL_IP>/health_metadata
curl http://<NAVIGATION_EXTERNAL_IP>/api/navigation
```

Communications Service:

```bash
curl http://<COMMUNICATIONS_EXTERNAL_IP>/
curl http://<COMMUNICATIONS_EXTERNAL_IP>/health
curl http://<COMMUNICATIONS_EXTERNAL_IP>/health_metadata
curl http://<COMMUNICATIONS_EXTERNAL_IP>/api/communications
```

The `/health_metadata` endpoint provides deployment traceability including:

```json
{
  "commit_id": "<git-commit>",
  "release_version": "<release-version>",
  "service": "<service-name>",
  "status": "healthy",
  "timestamp": "<timestamp>"
}
```

---

# 22. Check GCP Billing Status

Verify that billing is enabled for the project:

```bash
gcloud beta billing projects describe starfleet-gke-platform-lab
```

Look for:

```text
billingEnabled: true
```

---

# 23. Git Workflow

Check repository status:

```bash
git status
```

Review changes:

```bash
git diff
```

Stage changes:

```bash
git add .
```

Commit:

```bash
git commit -m "Describe infrastructure change"
```

Push:

```bash
git push origin main
```

---

# 24. Safe Platform Change Workflow

For normal infrastructure changes, use:

```bash
terraform fmt
terraform validate
terraform plan
```

Review the plan carefully.

If correct:

```bash
terraform apply
```

Then verify GCP:

```bash
gcloud container clusters list
```

Verify Kubernetes:

```bash
kubectl config current-context
kubectl get nodes -o wide
kubectl get pods -o wide
```

Finally:

```bash
git status
git add .
git commit -m "Describe infrastructure change"
git push origin main
```

---

# 25. Destroying Lab Infrastructure

Before destroying anything, verify the active project:

```bash
gcloud config get-value project
```

Review what Terraform manages:

```bash
terraform state list
```

Preview destruction:

```bash
terraform plan -destroy
```

Only when intentionally removing the lab:

```bash
terraform destroy
```

Review the destruction plan carefully before confirming.

> **Warning:** `terraform destroy` removes Terraform-managed Starfleet infrastructure. Do not run it as part of normal deployment or troubleshooting.

---

# Quick Daily Checklist

When returning to the lab:

```bash
cd /Users/sd/workspace/starfleet-gke-platform

gcloud config get-value project

terraform validate
terraform plan

gcloud container clusters list

kubectl config get-contexts
kubectl config current-context

kubectl get nodes -o wide
kubectl get pods -o wide
kubectl get services
```

Before applying an application manifest, always verify:

```bash
kubectl config current-context
```

This prevents accidentally deploying an Alpha workload to Delta or a Delta workload to Alpha.
