# Create a small Cloud Storage bucket used by the Navigation service
# to demonstrate authenticated access to a Google Cloud service.
resource "google_storage_bucket" "navigation_data" {
  name          = "${var.project_id}-navigation-data"
  location      = "US"
  force_destroy = true

  uniform_bucket_level_access = true
}

# Allow only the Navigation service identity to read objects from
# the Navigation data bucket.
resource "google_storage_bucket_iam_member" "navigation_object_viewer" {
  bucket = google_storage_bucket.navigation_data.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.navigation_service.email}"
}
