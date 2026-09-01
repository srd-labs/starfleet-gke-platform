# Secret Manager

## Overview

Google Secret Manager is used to securely store application secrets for the Starfleet Navigation and Communications services.

The implementation follows a least-privilege security model:

- Navigation has its own secret.
- Communications has its own secret.
- Each application has a dedicated Google Service Account.
- Kubernetes workloads authenticate using Workload Identity.
- IAM access is granted at the individual secret level.
- No Google service account JSON keys are stored in the applications.
- Secret values are not stored in Terraform state.

---

## Architecture

The applications access Secret Manager through Workload Identity.

```text
Navigation Pod
      |
      v
navigation-service
Kubernetes ServiceAccount
      |
      v
Workload Identity
      |
      v
navigation-service
Google Service Account
      |
      v
navigation-service-secret
```

```text
Communications Pod
      |
      v
communications-service
Kubernetes ServiceAccount
      |
      v
Workload Identity
      |
      v
communications-service
Google Service Account
      |
      v
communications-service-secret
```

This allows application pods to access Google Cloud services without storing long-lived Google service account credentials.

---

## Secret Manager API

Secret Manager must be enabled before secrets can be created.

The API is managed through Terraform in:

```text
apis.tf
```

Terraform configuration:

```hcl
# Enable Secret Manager so application workloads can securely retrieve
# secrets using Workload Identity instead of storing credentials in code
# or Kubernetes manifests.
resource "google_project_service" "secret_manager_api" {
  project            = var.project_id
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}
```

---

## Secret Resources

Secret resources and their IAM permissions are managed in:

```text
secret-manager.tf
```

### Navigation Secret

```hcl
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
```

### Navigation Secret IAM

Only the Navigation Google Service Account is granted permission to access the Navigation secret.

```hcl
# Allow only the Navigation workload identity to read its application secret.
resource "google_secret_manager_secret_iam_member" "navigation_accessor" {
  secret_id = google_secret_manager_secret.navigation.id

  role   = "roles/secretmanager.secretAccessor"
  member = "serviceAccount:${google_service_account.navigation_service.email}"
}
```

---

## Communications Secret

```hcl
# Secret used by the Communications application.
# The secret value itself is intentionally not managed by Terraform so
# sensitive data is not stored in Terraform state.
resource "google_secret_manager_secret" "communications" {
  secret_id = "communications-service-secret"

  replication {
    auto {}
  }

  depends_on = [
    google_project_service.secret_manager_api
  ]
}
```

### Communications Secret IAM

Only the Communications Google Service Account is granted permission to access the Communications secret.

```hcl
# Allow only the Communications workload identity to read its application secret.
resource "google_secret_manager_secret_iam_member" "communications_accessor" {
  secret_id = google_secret_manager_secret.communications.id

  role   = "roles/secretmanager.secretAccessor"
  member = "serviceAccount:${google_service_account.communications_service.email}"
}
```

---

## Terraform Validation

Terraform configuration was formatted and validated before deployment.

```bash
terraform fmt
terraform validate
terraform plan
```

The expected Secret Manager plan was:

```text
Plan: 5 to add, 0 to change, 0 to destroy.
```

The following resources were created:

```text
google_project_service.secret_manager_api

google_secret_manager_secret.navigation
google_secret_manager_secret.communications

google_secret_manager_secret_iam_member.navigation_accessor
google_secret_manager_secret_iam_member.communications_accessor
```

The resources were deployed using:

```bash
terraform apply
```

---

## Verify Secret Manager Resources

The created secrets can be verified using:

```bash
gcloud secrets list \
  --project starfleet-gke-platform-lab
```

Validated result:

```text
NAME                           REPLICATION_POLICY
communications-service-secret automatic
navigation-service-secret     automatic
```

This confirms that both application secret resources were successfully created.

---

## Secret Values

Terraform manages the Secret Manager resources and IAM permissions, but it intentionally does not manage the actual secret payloads.

This prevents secret values from being stored inside Terraform state.

For assessment testing, harmless test values are used.

### Navigation Test Secret

```bash
printf '%s' 'NAVIGATION-SECRET-OK' | \
gcloud secrets versions add navigation-service-secret \
  --data-file=- \
  --project starfleet-gke-platform-lab
```

### Communications Test Secret

```bash
printf '%s' 'COMMUNICATIONS-SECRET-OK' | \
gcloud secrets versions add communications-service-secret \
  --data-file=- \
  --project starfleet-gke-platform-lab
```

Production secret values should be supplied through an approved secure operational process rather than committed to source control.

---

## Verify Secret Versions

List Navigation secret versions:

```bash
gcloud secrets versions list navigation-service-secret \
  --project starfleet-gke-platform-lab
```

List Communications secret versions:

```bash
gcloud secrets versions list communications-service-secret \
  --project starfleet-gke-platform-lab
```

An active secret version should report:

```text
STATE
ENABLED
```

---

## IAM Security Model

The applications use separate identities and separate secrets.

```text
navigation-service GSA
        |
        | roles/secretmanager.secretAccessor
        v
navigation-service-secret


communications-service GSA
        |
        | roles/secretmanager.secretAccessor
        v
communications-service-secret
```

The IAM role is granted on the individual secret rather than at the entire project level.

This means Navigation should not automatically have access to Communications secrets, and Communications should not automatically have access to Navigation secrets.

---

## Workload Identity Integration

The Google Service Accounts are mapped to Kubernetes ServiceAccounts using Workload Identity.

Navigation:

```text
default/navigation-service
        |
        v
navigation-service@starfleet-gke-platform-lab.iam.gserviceaccount.com
```

Communications:

```text
default/communications-service
        |
        v
communications-service@starfleet-gke-platform-lab.iam.gserviceaccount.com
```

The Kubernetes Deployments specify their application ServiceAccount.

Navigation:

```yaml
spec:
  template:
    spec:
      serviceAccountName: navigation-service
```

Communications:

```yaml
spec:
  template:
    spec:
      serviceAccountName: communications-service
```

The Kubernetes ServiceAccounts contain the corresponding Google Service Account annotation.

Example:

```yaml
metadata:
  annotations:
    iam.gke.io/gcp-service-account: navigation-service@starfleet-gke-platform-lab.iam.gserviceaccount.com
```
## GKE Secret Manager Add-on

To allow application pods to mount secrets directly from Google Secret Manager,
the GKE Secret Manager add-on is enabled on both clusters through Terraform.

This avoids storing secret values in Kubernetes manifests or Terraform state.

### Terraform Configuration

The following configuration is included in both GKE cluster resources:

```hcl
# Enable the GKE Secret Manager add-on so workloads can mount secrets
# directly from Google Secret Manager as files inside application pods.
#
# Authentication is provided through Workload Identity, avoiding
# long-lived service account keys or plaintext Kubernetes Secrets.
secret_manager_config {
  enabled = true
}
---

## End-to-End Security Flow

The complete authentication and authorization flow is:

```text
Application Pod
      |
      v
Kubernetes ServiceAccount
      |
      v
GKE Workload Identity
      |
      v
Google Service Account
      |
      v
Secret-level IAM
      |
      v
Google Secret Manager
```

No service account JSON key is required anywhere in this flow.

---

## Least-Privilege Validation

The final security validation should demonstrate both successful and denied access.

Expected Navigation behavior:

```text
navigation-service
    |
    +--> navigation-service-secret       ALLOWED
    |
    +--> communications-service-secret   DENIED
```

Expected Communications behavior:

```text
communications-service
    |
    +--> communications-service-secret   ALLOWED
    |
    +--> navigation-service-secret       DENIED
```

This test validates both Workload Identity and secret-level IAM isolation.

---

## Security Benefits

The implementation provides:

- keyless Google Cloud authentication
- no service account JSON credentials in containers
- no service account keys in Kubernetes Secrets
- no plaintext secrets in Kubernetes deployment manifests
- no application secret values stored in Terraform state
- separate workload identities for each application
- secret-level IAM authorization
- independently rotatable secret versions
- centralized secret auditing through Google Cloud
- least-privilege application access

---

## Production Considerations

For a production environment:

- use meaningful secret names based on their actual purpose, such as database credentials or external API keys;
- rotate secrets regularly;
- disable or destroy obsolete secret versions;
- avoid granting Secret Manager access at the project level when secret-level IAM is sufficient;
- audit secret access using Cloud Audit Logs;
- separate application service accounts by workload;
- avoid downloading service account JSON keys;
- establish an approved process for injecting new secret versions;
- consider automated secret rotation where supported.

The lab implementation intentionally uses harmless test values to demonstrate the security architecture without introducing real credentials.
