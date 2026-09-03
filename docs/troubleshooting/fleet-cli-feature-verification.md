# Fleet CLI Feature Verification

## Symptom

While validating GKE Fleet features, the feature describe command was
initially run with:

``` text
--location=global
```

The installed `gcloud` CLI rejected that option for the Fleet feature
describe command.

## Investigation

The Fleet memberships and features already existed, so the issue was
with the verification command rather than the Fleet configuration
itself.

List memberships:

``` bash
gcloud container fleet memberships list \
  --project=starfleet-gke-platform-lab
```

The working Multi-Cluster Services verification command was:

``` bash
gcloud container fleet features describe multiclusterservicediscovery \
  --project=starfleet-gke-platform-lab
```

The working Multi-Cluster Gateway verification command was:

``` bash
gcloud container fleet features describe multiclusteringress \
  --project=starfleet-gke-platform-lab
```

## Root Cause

The installed `gcloud` command version did not accept
`--location=global` for this particular feature describe operation.

The problem was CLI syntax, not a failed Fleet feature.

## Resolution

The unsupported `--location=global` argument was removed.

The features were then successfully described and validated.

Multi-Cluster Services was active, and the Multi-Cluster Gateway feature
showed Alpha as the configuration membership.

## Validation

``` bash
gcloud container fleet features describe multiclusterservicediscovery \
  --project=starfleet-gke-platform-lab
```

``` bash
gcloud container fleet features describe multiclusteringress \
  --project=starfleet-gke-platform-lab
```

## Lessons Learned

Do not assume that similar `gcloud` command groups support identical
flags.

When a verification command fails because of an unrecognized argument,
check the command syntax before changing the underlying infrastructure.
