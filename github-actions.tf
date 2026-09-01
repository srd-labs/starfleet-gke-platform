# ---------------------------------------------------------------------------
# GitHub Actions Workload Identity Federation
# ---------------------------------------------------------------------------
#
# This configuration allows the starfleet-navigation-service GitHub
# repository to authenticate to Google Cloud without storing a service
# account JSON key in GitHub.
#
# Authentication flow:
#
# GitHub Actions
#      |
#      | GitHub OIDC token
#      v
# Workload Identity Pool
#      |
#      v
# GitHub OIDC Provider
#      |
#      v
# GitHub Actions Google Service Account
#

# Workload Identity Pool used by GitHub Actions.
resource "google_iam_workload_identity_pool" "github_actions" {
  project = var.project_id

  workload_identity_pool_id = "github-actions"
  display_name              = "GitHub Actions"
  description               = "Workload Identity Pool for GitHub Actions CI/CD"
}

# Trust GitHub's OIDC identity provider.
#
# Access is restricted to:
#   srd-labs/starfleet-navigation-service
#   main branch
#
# This prevents workflows from unrelated repositories or branches from
# using this provider.
resource "google_iam_workload_identity_pool_provider" "github_actions" {
  project = var.project_id

  workload_identity_pool_id          = google_iam_workload_identity_pool.github_actions.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub Actions Provider"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.actor"      = "assertion.actor"
    "attribute.ref"        = "assertion.ref"
  }

  attribute_condition = <<EOT
attribute.repository == "srd-labs/starfleet-navigation-service" &&
assertion.ref == "refs/heads/main" &&
assertion.ref_type == "branch"
EOT

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# Dedicated Google Service Account used by GitHub Actions.
#
# Application workloads do not use this identity. It exists only for
# CI/CD operations such as publishing container images and deploying
# workloads to GKE.
resource "google_service_account" "github_actions" {
  project = var.project_id

  account_id   = "github-actions-deployer"
  display_name = "GitHub Actions Deployer"
}

# Allow only the trusted Navigation GitHub repository identity to
# impersonate the GitHub Actions deployment service account.
resource "google_service_account_iam_member" "github_actions_workload_identity" {
  service_account_id = google_service_account.github_actions.name

  role = "roles/iam.workloadIdentityUser"

  member = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_actions.name}/attribute.repository/srd-labs/starfleet-navigation-service"
}

# Allow GitHub Actions to push application container images to the
# existing starfleet-apps Artifact Registry repository.
resource "google_artifact_registry_repository_iam_member" "github_actions_writer" {
  project    = var.project_id
  location   = "us-central1"
  repository = "starfleet-apps"

  role   = "roles/artifactregistry.writer"
  member = "serviceAccount:${google_service_account.github_actions.email}"
}

# Allow the GitHub Actions deployer to interact with GKE clusters.
#
# This role lets the CI/CD pipeline read cluster information and perform
# Kubernetes deployment operations through the GKE API.
resource "google_project_iam_member" "github_actions_gke_developer" {
  project = var.project_id

  role   = "roles/container.developer"
  member = "serviceAccount:${google_service_account.github_actions.email}"
}



