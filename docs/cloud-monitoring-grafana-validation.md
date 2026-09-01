# Cloud Monitoring and Grafana Validation

## 1. Overview

This document describes the Cloud Monitoring and Grafana implementation
used by the Starfleet GKE Platform Lab.

The objective was to provide centralized infrastructure and application
observability across two Google Kubernetes Engine (GKE) clusters while
keeping the lab cost-conscious.

The implementation validates the following monitoring path:

``` text
Alpha GKE Cluster ─┐
                   ├─> GKE Metrics Agents ─> Google Cloud Monitoring ─> Grafana
Delta GKE Cluster ─┘
```

Grafana runs on a small Compute Engine VM and queries Google Cloud
Monitoring using the VM's attached Google service account. No
service-account JSON key is stored on the VM.

------------------------------------------------------------------------

## 2. Environment

  Component              Configuration
  ---------------------- ------------------------------
  Google Cloud project   `starfleet-gke-platform-lab`
  Alpha cluster          `enterprise-gke-alpha`
  Alpha location         `us-central1-a`
  Delta cluster          `enterprise-gke-delta`
  Delta location         `us-east1-b`
  Grafana VM             `starfleet-grafana`
  Grafana VM zone        `us-central1-a`
  Grafana machine type   `e2-small`
  Grafana runtime        Docker
  Monitoring backend     Google Cloud Monitoring
  Grafana datasource     Google Cloud Monitoring
  Authentication         GCE service-account identity

------------------------------------------------------------------------

## 3. GKE Monitoring Architecture

GKE provides built-in components that collect workload and cluster
telemetry.

The following components were verified in the Delta cluster:

``` bash
kubectl get pods -n kube-system | grep -E 'metrics|gmp|collector|fluent'
```

Observed components included:

``` text
fluentbit-gke
gke-metrics-agent
metrics-server
```

Their roles are:

-   `fluentbit-gke` forwards container logs to Cloud Logging.
-   `gke-metrics-agent` exports GKE metrics to Cloud Monitoring.
-   `metrics-server` supplies Kubernetes resource metrics used by
    commands such as `kubectl top` and by the Horizontal Pod Autoscaler.

Two `gke-metrics-agent` pods were observed in the Delta cluster,
corresponding to its two worker nodes.

Example validation:

``` text
gke-metrics-agent-kd5wt   3/3   Running
gke-metrics-agent-xrg4q   3/3   Running
```

No additional monitoring agent was required for the GKE workloads in
this lab.

------------------------------------------------------------------------

## 4. Kubernetes Metrics Validation

Before configuring Grafana, Kubernetes resource metrics were validated
directly.

``` bash
kubectl top pods
```

Example result:

``` text
NAME                                                CPU(cores)   MEMORY(bytes)
starfleet-communications-service-...                1m           22Mi
starfleet-communications-service-...                1m           22Mi
starfleet-navigation-service-...                    1m           22Mi
starfleet-navigation-service-...                    1m           22Mi
```

This confirmed that the application pods were running and Kubernetes
resource metrics were available.

------------------------------------------------------------------------

## 5. Cloud Monitoring API Validation

Cloud Monitoring was validated independently of Grafana to separate
monitoring-pipeline problems from dashboard configuration problems.

The following Kubernetes container metric was used:

``` text
kubernetes.io/container/cpu/core_usage_time
```

The monitored resource type is:

``` text
k8s_container
```

A direct Cloud Monitoring API request was performed:

``` bash
TOKEN=$(gcloud auth print-access-token)

END_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
START_TIME=$(date -u -v-30M +"%Y-%m-%dT%H:%M:%SZ")

curl -s -G \
  -H "Authorization: Bearer $TOKEN" \
  "https://monitoring.googleapis.com/v3/projects/starfleet-gke-platform-lab/timeSeries" \
  --data-urlencode 'filter=metric.type="kubernetes.io/container/cpu/core_usage_time" AND resource.type="k8s_container"' \
  --data-urlencode "interval.startTime=${START_TIME}" \
  --data-urlencode "interval.endTime=${END_TIME}" \
  --data-urlencode 'view=HEADERS'
```

The response returned real workload time series containing labels such
as:

``` text
cluster_name
pod_name
container_name
namespace_name
location
project_id
```

Data was returned for workloads including:

``` text
enterprise-gke-alpha
navigation-service
communications-service
```

This proved that actual GKE workload metrics were reaching Cloud
Monitoring before Grafana was introduced into the validation path.

------------------------------------------------------------------------

## 6. Grafana Deployment Design

Grafana was deployed on a Compute Engine VM rather than running locally.

Architecture:

``` text
Administrator Browser
        |
        | TCP/3000
        v
starfleet-grafana
Compute Engine VM
        |
        | GCE service-account identity
        v
Google Cloud Monitoring API
        |
        +---- Alpha GKE metrics
        |
        +---- Delta GKE metrics
```

This provides a persistent monitoring environment hosted inside Google
Cloud while remaining simple enough for the lab.

------------------------------------------------------------------------

## 7. Terraform-Managed Grafana Infrastructure

The Grafana infrastructure is managed through Terraform so the
deployment remains reproducible and infrastructure configuration stays
in source control.

Major resources include:

``` text
google_compute_instance.grafana
google_service_account.grafana
google_project_iam_member
google_compute_firewall.grafana
google_compute_firewall.grafana_ssh
google_project_service.cloud_resource_manager_api
```

The VM is connected to the existing Starfleet VPC and Alpha subnet.

The VM uses the network tag:

``` text
starfleet-grafana
```

------------------------------------------------------------------------

## 8. Grafana Service Account and IAM

A dedicated user-managed service account was created for Grafana:

``` text
starfleet-grafana@starfleet-gke-platform-lab.iam.gserviceaccount.com
```

The service account was granted:

``` text
roles/monitoring.viewer
```

The VM uses the `cloud-platform` OAuth scope while IAM controls the
effective permissions.

Grafana obtains credentials from the Compute Engine metadata service.

No service-account JSON key is required.

This provides keyless authentication and avoids storing long-lived
Google Cloud credentials inside the Grafana container.

------------------------------------------------------------------------

## 9. Service Account Validation

From the Grafana VM, the attached service-account identity was verified
using the metadata server:

``` bash
curl -s \
  -H "Metadata-Flavor: Google" \
  "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email"
```

The result identified the expected Grafana service account.

An access token was then retrieved from the metadata service and used to
call Cloud Monitoring:

``` bash
TOKEN=$(curl -s \
  -H "Metadata-Flavor: Google" \
  "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" \
  | python3 -c 'import sys,json; print(json.load(sys.stdin)["access_token"])')

curl -s -o /tmp/monitoring-test.json -w "HTTP_STATUS=%{http_code}\n" \
  -H "Authorization: Bearer $TOKEN" \
  "https://monitoring.googleapis.com/v3/projects/starfleet-gke-platform-lab/metricDescriptors?pageSize=1"
```

Validation result:

``` text
HTTP_STATUS=200
```

This confirmed:

``` text
Grafana VM
   |
   +--> GCE metadata identity
   |
   +--> IAM authorization
   |
   +--> Cloud Monitoring API
```

------------------------------------------------------------------------

## 10. Required Google Cloud APIs

The following APIs were verified/enabled for the Grafana integration:

``` text
monitoring.googleapis.com
cloudresourcemanager.googleapis.com
```

Cloud Resource Manager API enablement is managed through Terraform.

------------------------------------------------------------------------

## 11. Network Security

Grafana is exposed directly on TCP port `3000` for this lab.

The Terraform firewall rule restricts access to the administrator's
current public IPv4 address using a `/32` CIDR rather than allowing
access from the entire internet.

Example:

``` hcl
source_ranges = [var.grafana_admin_cidr]
```

SSH access on TCP port `22` is similarly restricted to the administrator
CIDR.

The actual administrator IP should not be committed to documentation.
Examples should use:

``` text
<ADMIN_PUBLIC_IP>/32
```

### Production Recommendation

For a production deployment, direct public access to Grafana should be
replaced with a stronger access architecture such as HTTPS behind an
authenticated proxy/load balancer, Identity-Aware Proxy, private
networking, or another organization-approved access mechanism.

------------------------------------------------------------------------

## 12. Grafana Runtime

Docker is installed automatically on the Compute Engine VM.

Grafana runs as:

``` text
starfleet-grafana
```

Runtime validation:

``` bash
sudo docker ps
```

The container exposes:

``` text
0.0.0.0:3000->3000/tcp
```

The Grafana data directory is backed by a Docker volume so dashboard
configuration persists independently of the container lifecycle.

------------------------------------------------------------------------

## 13. Google Cloud Monitoring Datasource

The datasource type is:

``` text
stackdriver
```

The datasource uses Compute Engine authentication:

``` yaml
apiVersion: 1

datasources:
  - name: Google Cloud Monitoring
    type: stackdriver
    access: proxy
    isDefault: true
    editable: true
    jsonData:
      authenticationType: gce
      universeDomain: googleapis.com
```

This allows Grafana to obtain credentials through the VM's attached
service account.

------------------------------------------------------------------------

## 14. Query Validation

The Grafana Builder interface was initially used to query:

``` text
Service: Kubernetes
Metric: CPU usage time
```

Although the underlying Cloud Monitoring metric contained data, the
Builder query returned `No data`.

Because Cloud Monitoring had already been independently validated
through the REST API, the problem was isolated to Grafana query
construction rather than GKE metrics collection.

The query was switched to PromQL.

PromQL successfully returned GKE workload metrics.

------------------------------------------------------------------------

## 15. Grafana Dashboard

Dashboard name:

``` text
Starfleet GKE Platform
```

The dashboard contains six primary panels:

``` text
+----------------------------------+----------------------------------+
| Alpha Cluster - Application CPU  | Delta Cluster - Application CPU  |
+----------------------------------+----------------------------------+
| Alpha Cluster - Application      | Delta Cluster - Application      |
| Memory                           | Memory                           |
+----------------------------------+----------------------------------+
| Alpha Cluster - Running Pods     | Delta Cluster - Running Pods     |
+----------------------------------+----------------------------------+
```

The panels provide cluster-level comparison while preserving
application-level series for the Navigation and Communications services.

------------------------------------------------------------------------

## 16. Alpha Application CPU

CPU usage is derived from the cumulative Cloud Monitoring CPU usage-time
metric.

A five-minute `rate()` converts cumulative CPU time into CPU cores
consumed per second.

The result is multiplied by `1000` to display millicores.

``` promql
sum by (container_name) (
  rate(
    kubernetes_io:container_cpu_core_usage_time{
      cluster_name="enterprise-gke-alpha",
      namespace_name="default"
    }[5m]
  )
) * 1000
```

Panel title:

``` text
Alpha Cluster - Application CPU
```

Recommended display unit:

``` text
mCPU
```

------------------------------------------------------------------------

## 17. Delta Application CPU

``` promql
sum by (container_name) (
  rate(
    kubernetes_io:container_cpu_core_usage_time{
      cluster_name="enterprise-gke-delta",
      namespace_name="default"
    }[5m]
  )
) * 1000
```

Panel title:

``` text
Delta Cluster - Application CPU
```

Recommended display unit:

``` text
mCPU
```

------------------------------------------------------------------------

## 18. Alpha Application Memory

Memory is a gauge/current-value metric and therefore does not require
`rate()`.

``` promql
sum by (container_name) (
  kubernetes_io:container_memory_used_bytes{
    cluster_name="enterprise-gke-alpha",
    namespace_name="default"
  }
)
```

Panel title:

``` text
Alpha Cluster - Application Memory
```

Grafana should use an IEC bytes unit so values are automatically
displayed as MiB/GiB.

------------------------------------------------------------------------

## 19. Delta Application Memory

``` promql
sum by (container_name) (
  kubernetes_io:container_memory_used_bytes{
    cluster_name="enterprise-gke-delta",
    namespace_name="default"
  }
)
```

Panel title:

``` text
Delta Cluster - Application Memory
```

Recommended unit:

``` text
Bytes (IEC)
```

------------------------------------------------------------------------

## 20. Running Pods

Running workload visibility was added to demonstrate that both
applications maintain multiple replicas in each cluster.

Alpha:

``` promql
count by (container_name) (
  kubernetes_io:container_uptime{
    cluster_name="enterprise-gke-alpha",
    namespace_name="default",
    container_name=~"navigation-service|communications-service"
  }
)
```

Delta:

``` promql
count by (container_name) (
  kubernetes_io:container_uptime{
    cluster_name="enterprise-gke-delta",
    namespace_name="default",
    container_name=~"navigation-service|communications-service"
  }
)
```

The panels were configured with:

``` text
Unit: none
Decimals: 0
```

During normal operation the dashboard showed two instances for each
application.

------------------------------------------------------------------------

## 21. Grafana VM Resource Sizing

Grafana was initially deployed using:

``` text
e2-micro
```

This was selected to minimize lab cost.

As additional Cloud Monitoring queries and dashboard panels were added,
the Grafana UI became slow and appeared to hang.

Memory inspection showed:

``` text
969 MiB total
909 MiB used
60 MiB available
0 B swap
```

This demonstrated significant memory pressure.

The VM was resized through Terraform to:

``` text
e2-small
```

After the resize:

``` text
Memory total:       1.9 GiB
Memory available:   1.2 GiB
Grafana container:  ~534 MiB
Grafana memory:     ~27%
```

This provided sufficient headroom for the lab dashboard.

------------------------------------------------------------------------

## 22. Terraform VM Update Behavior

Changing a Compute Engine machine type requires the running VM to be
stopped.

Terraform initially rejected the update because automatic stopping had
not been enabled.

The following setting was added:

``` hcl
# Allow Terraform to temporarily stop the VM when an in-place update,
# such as a machine type resize, requires the instance to be powered off.
allow_stopping_for_update = true
```

The detailed incident is documented separately in:

``` text
docs/troubleshooting/grafana-vm-resize.md
```

------------------------------------------------------------------------

## 23. Ephemeral External IP Behavior

The Grafana VM intentionally uses an ephemeral external IP.

When the VM is stopped, the external IP can be released. When the VM
starts again, Google Cloud can assign a different address.

Therefore:

``` text
Grafana external IP != administrator firewall source IP
```

The administrator CIDR controls who can connect **to** Grafana.

The Grafana external IP identifies where the browser connects.

The current VM address can be retrieved with:

``` bash
gcloud compute instances describe starfleet-grafana \
  --zone=us-central1-a \
  --project=starfleet-gke-platform-lab \
  --format="get(networkInterfaces[0].accessConfigs[0].natIP)"
```

Using an ephemeral address avoids reserving a static public address
solely for this lab.

------------------------------------------------------------------------

## 24. Troubleshooting References

Detailed troubleshooting records are maintained separately under:

``` text
docs/troubleshooting/
```

Relevant incidents include:

``` text
cloud-monitoring-cli.md
grafana-ssh-firewall.md
grafana-vm-resize.md
```

Other Kubernetes and GKE operational incidents are indexed in:

``` text
docs/troubleshooting/README.md
```

------------------------------------------------------------------------

## 25. Dashboard Export

The final Grafana dashboard should be exported and stored in source
control.

Recommended location:

``` text
docs/monitoring/grafana/starfleet-gke-platform-dashboard.json
```

This provides a version-controlled representation of the dashboard
configuration and makes the monitoring implementation easier to review
or reproduce.

------------------------------------------------------------------------

## 26. Validation Summary

The following monitoring capabilities were validated:

-   GKE metrics agents running on worker nodes.
-   Kubernetes CPU and memory metrics available through `kubectl top`.
-   Real GKE container metrics available through the Cloud Monitoring
    API.
-   Dedicated Grafana Compute Engine service account.
-   Keyless GCE metadata authentication.
-   `roles/monitoring.viewer` authorization.
-   Cloud Monitoring API access from the Grafana VM.
-   Grafana Google Cloud Monitoring datasource connectivity.
-   PromQL queries returning application CPU metrics.
-   Alpha and Delta application CPU panels.
-   Alpha and Delta application memory panels.
-   Alpha and Delta running-pod panels.
-   Grafana VM resource utilization and right-sizing.
-   Terraform-managed networking, IAM, API enablement, VM configuration,
    and firewall controls.

The validated end-to-end path is:

``` text
Navigation + Communications Pods
              |
              v
       GKE Metrics Agents
              |
              v
      Cloud Monitoring
              |
              v
   Grafana on Compute Engine
              |
              v
 Starfleet GKE Platform Dashboard
```

------------------------------------------------------------------------

## 27. Production Recommendations

The lab intentionally favors simplicity and cost control. A production
implementation should evaluate:

-   private Grafana access rather than direct TCP/3000 exposure;
-   HTTPS and managed certificates;
-   Identity-Aware Proxy or another enterprise authentication layer;
-   regional/high-availability monitoring infrastructure;
-   managed Grafana or a highly available Grafana deployment;
-   persistent storage and backup strategy for Grafana;
-   alerting and notification channels;
-   SLO/SLI dashboards;
-   dashboard and datasource provisioning fully maintained as code;
-   centralized secret management;
-   stronger network segmentation;
-   production-grade application servers rather than Flask's built-in
    development server;
-   capacity planning based on observed monitoring workload.

The current design is intentionally sized and secured for a temporary
hands-on GCP/GKE assessment lab rather than production use.
