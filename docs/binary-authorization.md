# Binary Authorization and Image Attestation

## Overview

The Starfleet GKE platform uses Google Cloud Binary Authorization with
Cloud KMS-backed image attestations to establish trust in container
images before deployment.

``` text
GitHub Actions
    |
    v
Build linux/amd64 image
    |
    v
Trivy HIGH/CRITICAL security gate
    |
    v
Push SHA-tagged image to Artifact Registry
    |
    v
Resolve immutable image digest
    |
    v
Cloud KMS signs digest
    |
    v
Binary Authorization attestation
    |
    v
GKE deployment
```

No long-lived Cloud KMS private key or Google Cloud service-account JSON
key is stored in GitHub.

## Enabled Google Cloud Services

Terraform enables:

``` text
binaryauthorization.googleapis.com
containeranalysis.googleapis.com
cloudkms.googleapis.com
```

## Cloud KMS Signing Key

Key ring:

``` text
starfleet-binauthz-keyring
```

Signing key:

``` text
starfleet-image-attestation-key
```

Validated configuration:

``` text
Purpose: ASYMMETRIC_SIGN
Algorithm: RSA_SIGN_PKCS1_4096_SHA512
Protection level: SOFTWARE
```

The attestor uses CryptoKey version `1`. Terraform also uses
`prevent_destroy = true` on the signing key to reduce the risk of
accidental destruction.

## Container Analysis Note

The trusted attestation note is:

``` text
starfleet-image-attestation
```

Human-readable purpose:

``` text
Starfleet CI/CD approved container image
```

## Binary Authorization Attestor

The attestor is:

``` text
starfleet-image-attestor
```

The registered KMS public key is:

``` text
//cloudkms.googleapis.com/v1/projects/starfleet-gke-platform-lab/locations/global/keyRings/starfleet-binauthz-keyring/cryptoKeys/starfleet-image-attestation-key/cryptoKeyVersions/1
```

with:

``` text
RSA_SIGN_PKCS1_4096_SHA512
```

## Manual Attestation Validation

Before CI/CD automation, a real Navigation image was manually attested.

Digest:

``` text
sha256:41813f7e84ade9d98578238b77eaa4515503f70fb54f4419876d3acfd858d8d6
```

Artifact:

``` text
us-central1-docker.pkg.dev/starfleet-gke-platform-lab/starfleet-apps/starfleet-navigation-service@sha256:41813f7e84ade9d98578238b77eaa4515503f70fb54f4419876d3acfd858d8d6
```

Container Analysis returned:

``` text
kind: ATTESTATION
noteName: projects/starfleet-gke-platform-lab/notes/starfleet-image-attestation
resourceUri: us-central1-docker.pkg.dev/starfleet-gke-platform-lab/starfleet-apps/starfleet-navigation-service@sha256:41813f7e84ade9d98578238b77eaa4515503f70fb54f4419876d3acfd858d8d6
```

This proved the KMS signing, Container Analysis note, attestor, and
attestation chain before automating it.

## GitHub Actions Integration

The Navigation workflow now creates an attestation after the image
passes Trivy and is pushed to Artifact Registry.

``` text
Build
  |
  v
Trivy scan
  |
  v
Push image
  |
  v
Resolve digest
  |
  v
KMS sign + create attestation
  |
  v
Get GKE credentials
  |
  v
Deploy
```

The workflow resolves the immutable digest:

``` bash
DIGEST=$(gcloud artifacts docker images describe "$IMAGE" \
  --project="${PROJECT_ID}" \
  --format="value(image_summary.digest)")

IMAGE_BY_DIGEST="${REGION}-docker.pkg.dev/${PROJECT_ID}/${GAR_REPOSITORY}/${IMAGE_NAME}@${DIGEST}"
```

It then creates the attestation:

``` bash
gcloud beta container binauthz attestations sign-and-create \
  --project="${PROJECT_ID}" \
  --artifact-url="${IMAGE_BY_DIGEST}" \
  --attestor="starfleet-image-attestor" \
  --attestor-project="${PROJECT_ID}" \
  --keyversion-project="${PROJECT_ID}" \
  --keyversion-location="global" \
  --keyversion-keyring="starfleet-binauthz-keyring" \
  --keyversion-key="starfleet-image-attestation-key" \
  --keyversion="1"
```

The GitHub-hosted runner requires the gcloud beta component:

``` bash
gcloud components install beta --quiet
```

## GitHub Actions IAM

CI/CD service account:

``` text
github-actions-deployer@starfleet-gke-platform-lab.iam.gserviceaccount.com
```

Attestation-related permissions provisioned through Terraform:

  ----------------------------------------------------------------------------------
  Role                                           Purpose
  ---------------------------------------------- -----------------------------------
  `roles/cloudkms.signerVerifier`                Sign the image digest with the KMS
                                                 key

  `roles/binaryauthorization.attestorsViewer`    Read the configured attestor

  `roles/containeranalysis.notes.attacher`       Attach an occurrence to the trusted
                                                 note

  `roles/containeranalysis.occurrences.editor`   Create the attestation occurrence
  ----------------------------------------------------------------------------------

These complement the existing Workload Identity Federation, Artifact
Registry writer, and GKE deployment permissions.

## Troubleshooting

### gcloud Beta Component Missing

The first GitHub Actions attestation attempt reached the new stage but
the runner did not have the beta command group installed. The CLI
attempted an interactive component installation, which failed because
GitHub Actions is non-interactive.

Resolution:

``` bash
gcloud components install beta --quiet
```

The `--quiet` option allows the installation to complete without
prompting.

### Binary Authorization Attestor Permission Denied

The next attempt failed with:

``` text
PERMISSION_DENIED:
Permission 'binaryauthorization.attestors.get' denied
```

The GitHub Actions identity already had permission to sign with KMS but
could not read the attestor.

Terraform was updated to grant:

``` text
roles/binaryauthorization.attestorsViewer
roles/containeranalysis.notes.attacher
roles/containeranalysis.occurrences.editor
```

After applying the additional IAM permissions, automatic GitHub Actions
attestation succeeded.

## Security Model

  Stage                          Control
  ------------------------------ -------------------------------------
  GitHub → GCP                   OIDC + Workload Identity Federation
  Container build                Explicit `linux/amd64`
  Vulnerability validation       Trivy HIGH/CRITICAL gate
  Source traceability            Git SHA image tag
  Trusted artifact identity      Immutable SHA256 digest
  Signing                        Cloud KMS asymmetric signing key
  Approval record                Container Analysis attestation
  Trust verification             Binary Authorization attestor
  Long-lived GCP key in GitHub   Not used

The GitHub workflow never receives the KMS private key. Signing is
performed by Cloud KMS.

## Validation Status

  Component                                 Status
  ----------------------------------------- -----------------
  Binary Authorization API                  PASS
  Container Analysis API                    PASS
  Cloud KMS API                             PASS
  KMS asymmetric signing key                PASS
  Container Analysis note                   PASS
  Binary Authorization attestor             PASS
  KMS public key registered with attestor   PASS
  Manual Navigation image attestation       PASS
  GitHub Actions KMS signing                PASS
  GitHub Actions automatic attestation      PASS
  Attestation occurrence creation           PASS
  GKE Binary Authorization enforcement      NOT YET ENABLED

## Current Architecture

``` text
GitHub Actions
      |
      | OIDC
      v
Workload Identity Federation
      |
      v
github-actions-deployer GSA
      |
      +-----------------------+
      |                       |
      v                       v
Artifact Registry         Cloud KMS
      |                       |
      | image digest          | sign digest
      +-----------+-----------+
                  |
                  v
       Binary Authorization Attestor
                  |
                  v
        Container Analysis
           Attestation
                  |
                  v
              GKE Alpha
```

Image signing and attestation are now operational.

Binary Authorization enforcement has intentionally not yet been enabled
on Alpha. This allowed the automated attestation path to be validated
without risking disruption to existing workloads.

## Next Step

Enable Binary Authorization enforcement on Alpha and prove both policy
outcomes:

``` text
Attested image   -> Binary Authorization -> ALLOW
Unattested image -> Binary Authorization -> DENY
```

This will complete the end-to-end trusted-image deployment control.
