# Secret used by the Navigation application.
# The secret value itself is intentionally not managed by Terraform so
# sensitive data is not stored in Terraform state.
resource "google_secret_manager_secret" "navigation" {
  secret_id = "navigation-service-secret"

  replication {
    auto {}
  }

  depends_on = [
    google_project_service.secret_manager_api
  ]
}

# Allow only the Navigation workload identity to read its application secret.
resource "google_secret_manager_secret_iam_member" "navigation_accessor" {
  secret_id = google_secret_manager_secret.navigation.id

  role   = "roles/secretmanager.secretAccessor"
  member = "serviceAccount:${google_service_account.navigation_service.email}"
}

# Secret used by the Communications application.
resource "google_secret_manager_secret" "communications" {
  secret_id = "communications-service-secret"

  replication {
    auto {}
  }

  depends_on = [
    google_project_service.secret_manager_api
  ]
}

# Allow only the Communications workload identity to read its application secret.
resource "google_secret_manager_secret_iam_member" "communications_accessor" {
  secret_id = google_secret_manager_secret.communications.id

  role   = "roles/secretmanager.secretAccessor"
  member = "serviceAccount:${google_service_account.communications_service.email}"
}
