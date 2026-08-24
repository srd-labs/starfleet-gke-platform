# Enable Artifact Registry API for container image storage.
resource "google_project_service" "artifact_registry_api" {
  project = var.project_id
  service = "artifactregistry.googleapis.com"

  disable_on_destroy = false
}

# Docker repository for Starfleet application images.
resource "google_artifact_registry_repository" "starfleet_apps" {
  location      = var.region
  repository_id = "starfleet-apps"
  description   = "Docker images for Starfleet application services"
  format        = "DOCKER"

  depends_on = [
    google_project_service.artifact_registry_api
  ]
}
