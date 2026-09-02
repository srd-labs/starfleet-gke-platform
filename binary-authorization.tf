# Enable Binary Authorization so GKE can enforce trusted-image
# deployment policies.
resource "google_project_service" "binary_authorization_api" {
  project = var.project_id
  service = "binaryauthorization.googleapis.com"

  disable_on_destroy = false
}

# Enable Container Analysis because Binary Authorization attestations
# are stored as Container Analysis notes and occurrences.
resource "google_project_service" "container_analysis_api" {
  project = var.project_id
  service = "containeranalysis.googleapis.com"

  disable_on_destroy = false
}

# Enable Cloud KMS for cryptographic signing of container-image
# attestations.
resource "google_project_service" "cloud_kms_api" {
  project = var.project_id
  service = "cloudkms.googleapis.com"

  disable_on_destroy = false
}

# Key ring used to hold the Binary Authorization image-signing key.
resource "google_kms_key_ring" "binary_authorization" {
  name     = "starfleet-binauthz-keyring"
  location = "global"
  project  = var.project_id

  depends_on = [
    google_project_service.cloud_kms_api
  ]
}

# Asymmetric key used to sign attestations for container images that
# successfully pass the trusted CI/CD security process.
resource "google_kms_crypto_key" "binary_authorization_signing" {
  name     = "starfleet-image-attestation-key"
  key_ring = google_kms_key_ring.binary_authorization.id
  purpose  = "ASYMMETRIC_SIGN"

  version_template {
    algorithm = "RSA_SIGN_PKCS1_4096_SHA512"
  }

  lifecycle {
    prevent_destroy = true
  }
}

data "google_kms_crypto_key_version" "binary_authorization_signing" {
  crypto_key = google_kms_crypto_key.binary_authorization_signing.id
}



# Container Analysis note used as the authoritative metadata record
# for images approved by the Starfleet CI/CD attestation process.
resource "google_container_analysis_note" "starfleet_attestation" {
  name    = "starfleet-image-attestation"
  project = var.project_id

  attestation_authority {
    hint {
      human_readable_name = "Starfleet CI/CD approved container image"
    }
  }

  depends_on = [
    google_project_service.container_analysis_api
  ]
}

# Binary Authorization attestor used to verify that a container image
# was signed by the trusted Starfleet CI/CD signing key.
resource "google_binary_authorization_attestor" "starfleet_attestor" {
  name    = "starfleet-image-attestor"
  project = var.project_id

  attestation_authority_note {
    note_reference = google_container_analysis_note.starfleet_attestation.name

    public_keys {
      id = data.google_kms_crypto_key_version.binary_authorization_signing.id

      pkix_public_key {
        public_key_pem = data.google_kms_crypto_key_version.binary_authorization_signing.public_key[0].pem

        signature_algorithm = data.google_kms_crypto_key_version.binary_authorization_signing.public_key[0].algorithm
      }
    }
  }

  depends_on = [
    google_project_service.binary_authorization_api
  ]
}

# Allow the GitHub Actions deployment identity to use the Binary
# Authorization KMS key for signing approved container images.
resource "google_kms_crypto_key_iam_member" "github_actions_attestation_signer" {
  crypto_key_id = google_kms_crypto_key.binary_authorization_signing.id

  role = "roles/cloudkms.signerVerifier"

  member = "serviceAccount:${google_service_account.github_actions.email}"
}
# Allow GitHub Actions to read the Binary Authorization attestor
# before creating an image attestation.
resource "google_project_iam_member" "github_actions_attestor_viewer" {
  project = var.project_id
  role    = "roles/binaryauthorization.attestorsViewer"
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

# Allow GitHub Actions to attach an attestation occurrence to the
# Container Analysis note used by the Binary Authorization attestor.
resource "google_container_analysis_note_iam_member" "github_actions_note_attacher" {
  project = var.project_id
  note    = google_container_analysis_note.starfleet_attestation.name
  role    = "roles/containeranalysis.notes.attacher"
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

# Allow GitHub Actions to create the Container Analysis occurrence
# that stores the signed image attestation.
resource "google_project_iam_member" "github_actions_occurrences_editor" {
  project = var.project_id
  role    = "roles/containeranalysis.occurrences.editor"
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

# Allow GitHub Actions to inspect existing attestations attached
# to the trusted Container Analysis note. This makes the CI/CD
# attestation step idempotent when a workflow is rerun.
resource "google_container_analysis_note_iam_member" "github_actions_note_viewer" {
  project = var.project_id
  note    = google_container_analysis_note.starfleet_attestation.name
  role    = "roles/containeranalysis.notes.viewer"
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

# Allow GitHub Actions to inspect occurrences attached to the
# Binary Authorization attestation note. This lets the pipeline
# detect whether an image digest has already been attested.
resource "google_container_analysis_note_iam_member" "github_actions_attestation_viewer" {
  project = var.project_id
  note    = google_container_analysis_note.starfleet_attestation.name
  role    = "roles/containeranalysis.notes.occurrences.viewer"
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}


# Define the project-level Binary Authorization policy.
# Alpha requires container images to have a valid attestation from
# the trusted Starfleet image attestor before deployment.
resource "google_binary_authorization_policy" "starfleet" {
  project = var.project_id

  # Allow Google-maintained GKE system images to be evaluated by
  # Google's managed system policy so required cluster components
  # are not blocked by our application attestation policy.
  global_policy_evaluation_mode = "ENABLE"

  # Keep the project default permissive because Binary Authorization
  # enforcement is initially being introduced only to Alpha.
  default_admission_rule {
    evaluation_mode  = "ALWAYS_ALLOW"
    enforcement_mode = "ENFORCED_BLOCK_AND_AUDIT_LOG"
  }

  # Require a valid Starfleet attestation for application images
  # deployed to the Alpha GKE cluster.
  cluster_admission_rules {
    cluster                 = "us-central1-a.enterprise-gke-alpha"
    evaluation_mode         = "REQUIRE_ATTESTATION"
    enforcement_mode        = "ENFORCED_BLOCK_AND_AUDIT_LOG"
    require_attestations_by = [google_binary_authorization_attestor.starfleet_attestor.name]
  }
}
