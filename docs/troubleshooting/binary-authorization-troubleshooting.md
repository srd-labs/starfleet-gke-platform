# Binary Authorization Troubleshooting

This document records the Binary Authorization and image-attestation
issues encountered while implementing the Starfleet GKE CI/CD pipeline.

## 1. gcloud Beta Component Missing

### Symptom

GitHub Actions failed when running:

``` text
gcloud beta container binauthz attestations sign-and-create
```

The runner attempted an interactive installation of the `beta` component
and failed because GitHub Actions is non-interactive.

### Resolution

Install the component explicitly:

``` bash
gcloud components install beta --quiet
```

------------------------------------------------------------------------

## 2. GitHub Actions Could Not Read the Attestor

### Symptom

``` text
PERMISSION_DENIED:
Permission 'binaryauthorization.attestors.get' denied
```

### Resolution

Grant the GitHub Actions deployer:

``` text
roles/binaryauthorization.attestorsViewer
```

The attestation flow also requires:

``` text
roles/cloudkms.signerVerifier
roles/containeranalysis.notes.attacher
roles/containeranalysis.occurrences.editor
```

------------------------------------------------------------------------

## 3. Existing-Attestation Check Failed

### Symptom

The workflow displayed:

``` text
PERMISSION_DENIED:
Permission 'containeranalysis.notes.listOccurrences' denied
```

The original shell command also used `|| true` across the pipeline,
which could hide a real `gcloud` failure.

### Resolution

Grant:

``` text
roles/containeranalysis.notes.occurrences.viewer
```

to the GitHub Actions service account on the attestation note.

Also separate the Google Cloud command from the `grep` operation:

``` bash
ATTESTATIONS=$(gcloud container binauthz attestations list \
  --project="${PROJECT_ID}" \
  --attestor="starfleet-image-attestor" \
  --attestor-project="${PROJECT_ID}" \
  --format="value(resourceUri)")

EXISTING_ATTESTATION=$(echo "${ATTESTATIONS}" \
  | grep -F "${IMAGE_BY_DIGEST}" || true)
```

This allows `grep` to return no match without hiding a Google Cloud
permission failure.

------------------------------------------------------------------------

## 4. Duplicate Attestation Conflict

### Symptom

``` text
Resource ... is the subject of a conflict:
Could not create occurrence ID ...
```

### Root Cause

An attestation already existed for the immutable image digest, but the
workflow attempted to create another one.

### Resolution

Make the attestation stage idempotent:

``` text
list existing attestations
        |
        v
digest already attested?
   |              |
  yes             no
   |              |
   v              v
skip         sign-and-create
```

This allows safe workflow reruns against an already-approved image
digest.

------------------------------------------------------------------------

## 5. Binary Authorization Rejected Tag-Based Deployment

### Symptom

The Deployment rollout waited indefinitely and the ReplicaSet reported
`FailedCreate`.

Kubernetes events showed:

``` text
denied by Binary Authorization cluster admission rule
Expected digest with sha256 scheme, but got tag or malformed digest
```

The workflow was deploying:

``` text
starfleet-navigation-service:<git-sha>
```

while the attestation was created for:

``` text
starfleet-navigation-service@sha256:<digest>
```

### Root Cause

The image that was attested and the image reference submitted to GKE
were not expressed as the same immutable digest-qualified artifact.

### Resolution

After resolving the pushed image digest, persist it for later GitHub
Actions steps:

``` bash
IMAGE_BY_DIGEST="${REGION}-docker.pkg.dev/${PROJECT_ID}/${GAR_REPOSITORY}/${IMAGE_NAME}@${DIGEST}"
echo "IMAGE_BY_DIGEST=${IMAGE_BY_DIGEST}" >> "$GITHUB_ENV"
```

Deploy the exact attested digest:

``` bash
kubectl set image deployment/starfleet-navigation-service \
  navigation-service="${IMAGE_BY_DIGEST}"
```

------------------------------------------------------------------------

## 6. Final Validation

Binary Authorization enforcement is enabled for:

``` text
us-central1-a.enterprise-gke-alpha
```

with:

``` text
evaluationMode: REQUIRE_ATTESTATION
enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG
```

Alpha uses:

``` text
PROJECT_SINGLETON_POLICY_ENFORCE
```

Final deployed Navigation image:

``` text
us-central1-docker.pkg.dev/starfleet-gke-platform-lab/starfleet-apps/starfleet-navigation-service@sha256:e93d10bc0acdc99724d07df8c69ee3fd773c33b6aefa5a347b118cadac1983e8
```

The same digest was present in the Binary Authorization attestation
list.

Final pod state:

``` text
2 Navigation pods
READY: 1/1
STATUS: Running
```

## Result

The implementation now proves:

``` text
GitHub Actions
→ Trivy security gate
→ Artifact Registry
→ immutable SHA256 digest
→ Cloud KMS signature
→ Container Analysis attestation
→ Binary Authorization enforcement
→ digest-based GKE deployment
→ healthy application pods
```

**Status: COMPLETE**
