# Enable the GKE control plane and Kubernetes cluster management APIs.
resource "google_project_service" "container_api" {
  project            = var.project_id
  service            = "container.googleapis.com"
  disable_on_destroy = false
}

# Enable Compute Engine resources used by GKE, networking, and Grafana.
resource "google_project_service" "compute_api" {
  project            = var.project_id
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

# Enable Secret Manager so application workloads can securely retrieve
# secrets using Workload Identity instead of storing credentials in code
# or Kubernetes manifests.
resource "google_project_service" "secret_manager_api" {
  project            = var.project_id
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}
