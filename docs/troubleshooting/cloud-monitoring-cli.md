# Cloud Monitoring CLI Command Not Available

## Symptom

An attempted Google Cloud CLI command for listing Monitoring metrics
failed:

``` text
ERROR: (gcloud.monitoring) Invalid choice: 'metrics'.
```

## Investigation

The installed `gcloud` CLI did not provide the attempted
`gcloud monitoring metrics list` command.

Instead of treating this as a failure of Cloud Monitoring, the
Monitoring REST API was used to validate metric descriptors and actual
time-series data.

## Root Cause

The attempted CLI command was not supported by the installed Google
Cloud CLI command surface.

This was a client-command issue, not a GKE metrics collection failure.

## Resolution

Use an OAuth access token from `gcloud` and query the Cloud Monitoring
API directly.

Example metric query:

``` bash
TOKEN=$(gcloud auth print-access-token)

END_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
START_TIME=$(date -u -v-10M +"%Y-%m-%dT%H:%M:%SZ")

curl -s -G \
  -H "Authorization: Bearer $TOKEN" \
  "https://monitoring.googleapis.com/v3/projects/starfleet-gke-platform-lab/timeSeries" \
  --data-urlencode 'filter=metric.type="kubernetes.io/container/cpu/core_usage_time" AND resource.type="k8s_container"' \
  --data-urlencode "interval.startTime=${START_TIME}" \
  --data-urlencode "interval.endTime=${END_TIME}" \
  --data-urlencode 'view=FULL'
```

## Validation

The response returned real `k8s_container` time series for the Starfleet
workloads, including cluster, pod, namespace, and container labels.

This confirmed:

``` text
GKE workload
    ↓
gke-metrics-agent
    ↓
Cloud Monitoring
    ↓
Kubernetes container metrics
```

## Lesson Learned

A missing or unsupported CLI command does not imply that the underlying
Google Cloud service is unavailable. The service API can be used as an
authoritative validation path.
