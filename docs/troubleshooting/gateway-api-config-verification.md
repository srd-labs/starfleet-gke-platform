# Gateway API Configuration Verification

## Symptom

While verifying Gateway API enablement on the GKE clusters, the initial
formatted `gcloud` query returned:

``` text
null
```

This initially appeared to indicate that Gateway API was not enabled.

## Investigation

The first check queried `gatewayApiConfig` at the wrong level of the
cluster resource.

The Gateway API configuration is nested under:

``` text
networkConfig.gatewayApiConfig
```

Check Alpha:

``` bash
gcloud container clusters describe enterprise-gke-alpha \
  --zone=us-central1-a \
  --project=starfleet-gke-platform-lab \
  --format="yaml(networkConfig.gatewayApiConfig)"
```

Check Delta:

``` bash
gcloud container clusters describe enterprise-gke-delta \
  --zone=us-east1-b \
  --project=starfleet-gke-platform-lab \
  --format="yaml(networkConfig.gatewayApiConfig)"
```

Terraform state can also be checked:

``` bash
terraform state show google_container_cluster.alpha | grep -A4 gateway_api_config
terraform state show google_container_cluster.delta | grep -A4 gateway_api_config
```

## Root Cause

Gateway API was enabled. The original verification command used the
wrong field path.

The correct nested path is:

``` text
networkConfig.gatewayApiConfig
```

## Resolution

The corrected commands were used to verify both clusters.

The configuration showed:

``` text
CHANNEL_STANDARD
```

## Validation

The platform later successfully created and programmed the Multi-Cluster
Gateway, providing additional functional validation that the Gateway API
configuration was working.

Useful checks:

``` bash
kubectl get gatewayclass
kubectl get gateway
kubectl describe gateway starfleet-global-gateway
```

## Lessons Learned

A `null` value from a formatted CLI query does not necessarily mean a
feature is missing.

Before changing infrastructure, confirm that the correct resource field
path is being queried.
