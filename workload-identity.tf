# Google service account used by the Navigation application.
# This identity will be mapped to the application's Kubernetes service account
# so the pod can access Google Cloud APIs without a JSON key file.
resource "google_service_account" "navigation_service" {
  account_id   = "navigation-service"
  display_name = "Navigation Service"
}

# Google service account used by the Communications application.
# Keeping a separate identity per application supports least-privilege IAM.
resource "google_service_account" "communications_service" {
  account_id   = "communications-service"
  display_name = "Communications Service"
}

# Allow the Kubernetes service account named navigation-service in the
# default namespace to use the Navigation Google service account.
resource "google_service_account_iam_member" "navigation_workload_identity" {
  service_account_id = google_service_account.navigation_service.name
  role               = "roles/iam.workloadIdentityUser"

  member = "serviceAccount:${var.project_id}.svc.id.goog[default/navigation-service]"
}

# Allow the Kubernetes service account named communications-service in the
# default namespace to use the Communications Google service account.
resource "google_service_account_iam_member" "communications_workload_identity" {
  service_account_id = google_service_account.communications_service.name
  role               = "roles/iam.workloadIdentityUser"

  member = "serviceAccount:${var.project_id}.svc.id.goog[default/communications-service]"
}
