# GitHub Actions CI/CD Integration

## Overview

This document describes the GitHub Actions authentication and CI/CD
foundation for the Starfleet GKE Platform Lab.

The implementation uses GitHub OpenID Connect (OIDC), Google Cloud
Workload Identity Federation, a dedicated CI/CD Google service account,
Artifact Registry, and Google Kubernetes Engine (GKE).

The GitHub repository currently configured for federation is:

``` text
srd-labs/starfleet-navigation-service
```

Only workflows running from the `main` branch are trusted.

## Authentication Architecture

``` text
GitHub Actions
      |
      | GitHub-issued OIDC token
      v
Google Workload Identity Pool
      |
      v
GitHub OIDC Workload Identity Provider
      |
      | Repository and branch validation
      v
github-actions-deployer Google Service Account
      |
      +-----------------------+
      |                       |
      v                       v
Artifact Registry            GKE
Push images                  Deploy workloads
```

No Google Cloud service account JSON key is stored in GitHub.

## Security Model

The trust relationship is restricted to:

``` text
Repository: srd-labs/starfleet-navigation-service
Branch: refs/heads/main
Token type: branch
```

This prevents unrelated GitHub repositories and branches from using the
Google Cloud Workload Identity Provider.

## Workload Identity Pool

``` hcl
resource "google_iam_workload_identity_pool" "github_actions" {
  project = var.project_id

  workload_identity_pool_id = "github-actions"
  display_name              = "GitHub Actions"
  description               = "Workload Identity Pool for GitHub Actions CI/CD"
}
```

## GitHub OIDC Provider

``` hcl
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
```

## GitHub Actions Google Service Account

``` hcl
resource "google_service_account" "github_actions" {
  project = var.project_id

  account_id   = "github-actions-deployer"
  display_name = "GitHub Actions Deployer"
}
```

Service account:

``` text
github-actions-deployer@starfleet-gke-platform-lab.iam.gserviceaccount.com
```

This identity is dedicated to CI/CD and is separate from application
runtime identities.

## Workload Identity Impersonation

``` hcl
resource "google_service_account_iam_member" "github_actions_workload_identity" {
  service_account_id = google_service_account.github_actions.name
  role               = "roles/iam.workloadIdentityUser"

  member = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_actions.name}/attribute.repository/srd-labs/starfleet-navigation-service"
}
```

GitHub Actions can exchange its OIDC identity for temporary Google Cloud
credentials. No static service account key is required.

## Artifact Registry Permission

``` hcl
resource "google_artifact_registry_repository_iam_member" "github_actions_writer" {
  project    = var.project_id
  location   = "us-central1"
  repository = "starfleet-apps"

  role   = "roles/artifactregistry.writer"
  member = "serviceAccount:${google_service_account.github_actions.email}"
}
```

Artifact Registry repository:

``` text
us-central1-docker.pkg.dev/starfleet-gke-platform-lab/starfleet-apps
```

The CI/CD service account receives `roles/artifactregistry.writer` only
on this repository.

## GKE Deployment Permission

``` hcl
resource "google_project_iam_member" "github_actions_gke_developer" {
  project = var.project_id

  role   = "roles/container.developer"
  member = "serviceAccount:${google_service_account.github_actions.email}"
}
```

The role is assigned to the dedicated CI/CD Google service account, not
directly to GitHub.

Authentication therefore follows:

``` text
GitHub Actions
  -> GitHub OIDC
  -> Workload Identity Federation
  -> github-actions-deployer GSA
  -> roles/container.developer
```

## Initial Terraform Validation

Commands:

``` bash
terraform fmt
terraform validate
terraform plan
```

Initial federation plan:

``` text
Plan: 5 to add, 0 to change, 0 to destroy
```

Resources:

``` text
google_iam_workload_identity_pool.github_actions
google_iam_workload_identity_pool_provider.github_actions
google_service_account.github_actions
google_service_account_iam_member.github_actions_workload_identity
google_artifact_registry_repository_iam_member.github_actions_writer
```

No existing infrastructure was changed or destroyed.

## Workload Identity Pool Validation

``` bash
gcloud iam workload-identity-pools describe github-actions \
  --location=global \
  --project=starfleet-gke-platform-lab
```

Observed result:

``` text
description: Workload Identity Pool for GitHub Actions CI/CD
displayName: GitHub Actions
name: projects/232310545058/locations/global/workloadIdentityPools/github-actions
state: ACTIVE
```

Result: **PASS**

## GitHub OIDC Provider Validation

``` bash
gcloud iam workload-identity-pools providers describe github \
  --workload-identity-pool=github-actions \
  --location=global \
  --project=starfleet-gke-platform-lab
```

Observed configuration:

``` text
attributeCondition: |
  attribute.repository == "srd-labs/starfleet-navigation-service" &&
  assertion.ref == "refs/heads/main" &&
  assertion.ref_type == "branch"

attributeMapping:
  attribute.actor: assertion.actor
  attribute.ref: assertion.ref
  attribute.repository: assertion.repository
  google.subject: assertion.sub

displayName: GitHub Actions Provider

oidc:
  issuerUri: https://token.actions.githubusercontent.com

state: ACTIVE
```

Validation:

``` text
Provider state          PASS - ACTIVE
Repository restriction PASS
Branch restriction     PASS - main
OIDC issuer             PASS
```

## GKE Permission Terraform Validation

The GKE permission was deliberately added only after the GitHub trust
boundary was validated.

Terraform plan:

``` text
Plan: 1 to add, 0 to change, 0 to destroy
```

Resource:

``` text
google_project_iam_member.github_actions_gke_developer
```

Configuration:

``` text
role:
roles/container.developer

member:
serviceAccount:github-actions-deployer@starfleet-gke-platform-lab.iam.gserviceaccount.com
```

No existing resources were changed or destroyed.

## IAM Validation

Project-level GKE access can be verified with:

``` bash
gcloud projects get-iam-policy starfleet-gke-platform-lab \
  --flatten="bindings[].members" \
  --filter="bindings.members:github-actions-deployer@starfleet-gke-platform-lab.iam.gserviceaccount.com" \
  --format="table(bindings.role)"
```

Expected GKE role:

``` text
roles/container.developer
```

Artifact Registry access is granted directly on `starfleet-apps` using:

``` text
roles/artifactregistry.writer
```

## Current CI/CD Security Controls

  Control                                 Implementation
  --------------------------------------- -----------------------------------------
  GitHub authentication                   OIDC
  Google authentication                   Workload Identity Federation
  Service account JSON key                None
  Trusted repository                      `srd-labs/starfleet-navigation-service`
  Trusted branch                          `main`
  CI/CD Google identity                   `github-actions-deployer`
  Artifact Registry access                `roles/artifactregistry.writer`
  GKE access                              `roles/container.developer`
  Application runtime identities reused   No
  Long-lived GCP credentials in GitHub    No

## Planned GitHub Actions Pipeline

``` text
git push to main
        |
        v
GitHub Actions
        |
        v
GitHub OIDC authentication
        |
        v
Google Workload Identity Federation
        |
        v
github-actions-deployer
        |
        +----------------------------+
        |                            |
        v                            v
Build linux/amd64 image       Authenticate to GKE
        |                            |
        v                            |
Push to Artifact Registry           |
        |                            |
        +-------------+--------------+
                      |
                      v
               Deploy Navigation
                      |
                      v
              Validate rollout
```

The first automated deployment will target the Alpha GKE cluster. After
successful end-to-end validation, the workflow can be extended to Delta.

## Current Status

``` text
Workload Identity Pool          PASS
GitHub OIDC Provider            PASS
Repository restriction          PASS
Main branch restriction         PASS
CI/CD service account           PASS
Workload Identity binding       PASS
Artifact Registry writer        PASS
GKE container developer         PASS
Service account keys required   NO
```

The Google Cloud authentication and authorization foundation for the
Navigation GitHub Actions pipeline is complete.

The next implementation step is:

``` text
starfleet-navigation-service/.github/workflows/
```
