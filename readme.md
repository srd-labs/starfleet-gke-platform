# Starfleet GKE Platform --- What We Covered

## 1. Project Overview

The **Starfleet GKE Platform Lab** is a hands-on Google Cloud platform
engineering project demonstrating how a multi-cluster Kubernetes
platform can be provisioned, secured, deployed, monitored, and operated
using modern DevOps and cloud-native practices.

The implementation covers:

-   Google Cloud Platform
-   Terraform Infrastructure as Code
-   Custom VPC networking
-   Two GKE Standard clusters in separate regions
-   Docker and Artifact Registry
-   Kubernetes Deployments, Services, probes, and autoscaling
-   Workload Identity
-   Secret Manager
-   Cloud Storage integration
-   GitHub Actions CI/CD
-   Workload Identity Federation
-   Trivy vulnerability scanning
-   Binary Authorization
-   Cloud Logging
-   BigQuery
-   Cloud Monitoring
-   Grafana
-   GKE Fleet
-   Multi-Cluster Services
-   Gateway API
-   Multi-Cluster Gateway
-   Global static IP
-   Cross-region application failover and failback
-   Operational troubleshooting and documentation

The lab intentionally balances production architecture concepts with
cost-conscious implementation choices.

------------------------------------------------------------------------

## 2. GCP Foundation

The platform is deployed in:

``` text
Project ID: starfleet-gke-platform-lab
```

Terraform is used as the infrastructure source of truth.

Platform repository:

``` text
starfleet-gke-platform
```

The Terraform configuration manages the major infrastructure components,
including:

-   Google Cloud APIs
-   VPC and subnets
-   GKE clusters and node pools
-   Artifact Registry
-   IAM
-   Workload Identity
-   Secret Manager integration
-   Cloud Storage
-   logging and BigQuery resources
-   Grafana infrastructure
-   Fleet resources
-   Multi-Cluster Services
-   Multi-Cluster Gateway prerequisites
-   global static IP
-   Binary Authorization resources

Standard workflow:

``` bash
terraform fmt
terraform validate
terraform plan
terraform apply
```

------------------------------------------------------------------------

## 3. Network Architecture

A custom-mode VPC was created:

``` text
starfleet-vpc
```

### Alpha Quadrant

``` text
Subnet:   alpha-quadrant-subnet
Region:   us-central1

Nodes:    10.10.0.0/24
Pods:     10.20.0.0/16
Services: 10.30.0.0/20
```

Secondary ranges:

``` text
alpha-pods
alpha-services
```

### Delta Quadrant

``` text
Subnet:   delta-quadrant-subnet
Region:   us-east1

Nodes:    10.40.0.0/24
Pods:     10.50.0.0/16
Services: 10.60.0.0/20
```

Secondary ranges:

``` text
delta-pods
delta-services
```

The CIDR ranges are non-overlapping and both GKE clusters use VPC-native
networking.

------------------------------------------------------------------------

## 4. GKE Architecture

Two GKE Standard clusters were deployed.

### Alpha Cluster

``` text
Cluster:   enterprise-gke-alpha
Zone:      us-central1-a
Node pool: alpha-node-pool
Machine:   e2-medium
Disk:      30 GB pd-balanced
```

### Delta Cluster

``` text
Cluster:   enterprise-gke-delta
Zone:      us-east1-b
Node pool: delta-node-pool
Machine:   e2-medium
Disk:      30 GB pd-balanced
```

The normal lab design uses two worker nodes per cluster.

Both clusters use VPC-native networking and support the Kubernetes/GCP
capabilities required by the platform, including Workload Identity,
Secret Manager integration, and Gateway API.

Zonal clusters were selected for the lab to control cost. A production
implementation would normally evaluate regional clusters and broader
failure-domain distribution.

------------------------------------------------------------------------

## 5. Application Architecture

Application code is maintained separately from the platform
infrastructure.

Repositories include:

``` text
starfleet-navigation-service
starfleet-communications-service
```

Both services are containerized Flask applications deployed to GKE.

### Navigation Service

Navigation includes:

``` text
/
/health
/health_metadata
/api/navigation
/api/navigation/gcp-status
```

The application listens on:

``` text
8080
```

Its Kubernetes configuration includes:

-   Deployment
-   Service
-   readiness probe
-   liveness probe
-   CPU and memory requests/limits
-   Horizontal Pod Autoscaler
-   topology spread constraints
-   Kubernetes service account
-   SecretProviderClass
-   ServiceExport
-   HTTPRoute
-   Gateway configuration

Navigation also reports the serving quadrant, which was used during
multi-cluster validation:

``` json
{"quadrant":"alpha","service":"starfleet-navigation-service","status":"operational"}
```

or:

``` json
{"quadrant":"delta","service":"starfleet-navigation-service","status":"operational"}
```

### Communications Service

The Communications service was also deployed as a Kubernetes workload
and participated in the platform's application, monitoring, scaling, and
Secret Manager implementation.

------------------------------------------------------------------------

## 6. Artifact Registry

Application images are stored in Google Artifact Registry.

``` text
Region:     us-central1
Repository: starfleet-apps
```

Base image path:

``` text
us-central1-docker.pkg.dev/starfleet-gke-platform-lab/starfleet-apps
```

Images are built for:

``` text
linux/amd64
```

This was important because development was performed from Apple Silicon
while the GKE worker nodes use AMD64.

------------------------------------------------------------------------

## 7. Kubernetes Availability and Autoscaling

The application deployments use resource requests and limits, health
probes, multiple replicas, and topology-aware scheduling.

Navigation uses the following rolling-update strategy:

``` yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 0
    maxUnavailable: 1
```

Horizontal Pod Autoscaling uses:

``` text
API:              autoscaling/v2
Minimum replicas: 2
Maximum replicas: 4
CPU target:       60%
```

Alpha Navigation load testing demonstrated automatic scaling from two
replicas to three and then returning toward normal capacity after load
decreased.

------------------------------------------------------------------------

## 8. Workload Identity

GKE Workload Identity was implemented so Kubernetes workloads can access
Google Cloud services without storing long-lived service-account keys
inside containers.

Dedicated Google service accounts and Kubernetes service accounts were
configured for application workloads.

This provides:

``` text
Kubernetes Pod
      |
      v
Kubernetes Service Account
      |
      v
Workload Identity
      |
      v
Google Service Account
      |
      v
Google Cloud API
```

Workload Identity was validated through application access to Google
Cloud resources.

------------------------------------------------------------------------

## 9. Secret Manager

Google Secret Manager integration was implemented for the application
workloads.

Secrets include:

``` text
navigation-service-secret
communications-service-secret
```

Secret values are intentionally not stored directly in Terraform state.

The platform uses the GKE Secret Manager integration/CSI mounting
approach so applications can consume secrets without embedding secret
values in container images or Kubernetes manifests.

Secret Manager implementation and application validation were completed
as part of the lab.

------------------------------------------------------------------------

## 10. Cloud Storage

A Cloud Storage bucket was provisioned for Navigation:

``` text
starfleet-gke-platform-lab-navigation-data
```

The Navigation Google service account receives the required
object-viewer access.

Navigation successfully demonstrated Google Cloud access through
Workload Identity.

This validated the path:

``` text
Navigation Pod
     |
     v
Workload Identity
     |
     v
Navigation Google Service Account
     |
     v
Cloud Storage
```

------------------------------------------------------------------------

## 11. GitHub Actions CI/CD

The Navigation repository uses GitHub Actions for CI/CD.

The deployment pipeline follows:

``` text
GitHub
   |
   v
GitHub Actions
   |
   +--> Workload Identity Federation
   |
   +--> Build linux/amd64 image
   |
   +--> Trivy security scan
   |
   +--> Push to Artifact Registry
   |
   +--> Create Binary Authorization attestation
   |
   v
Deploy immutable image digest to GKE
```

The dedicated deployment service account is:

``` text
github-actions-deployer@starfleet-gke-platform-lab.iam.gserviceaccount.com
```

Workload Identity Federation removes the need to store a long-lived
Google Cloud service-account JSON key in GitHub.

------------------------------------------------------------------------

## 12. Container Security

Trivy is used as a CI vulnerability gate.

The pipeline checks container images for:

``` text
HIGH
CRITICAL
```

severity vulnerabilities.

The scan is configured to fail the pipeline when applicable
high-severity findings violate the configured gate.

------------------------------------------------------------------------

## 13. Binary Authorization

Binary Authorization was implemented for the Alpha GKE cluster.

The implementation includes:

-   required Google Cloud APIs
-   Cloud KMS
-   Container Analysis
-   attestor
-   IAM permissions
-   attestation creation
-   Binary Authorization policy
-   GitHub Actions integration

A validated Navigation release used the immutable digest:

``` text
sha256:4bad968954586cdc9cc947f3730c811764e7c2aab9f215ef203b597128a627d3
```

The CI/CD workflow creates the required attestation and deploys the
approved digest.

Binary Authorization and image attestation validation are complete for
the implemented Alpha security flow.

------------------------------------------------------------------------

## 14. Centralized Logging and BigQuery

Application logs are collected through Cloud Logging.

A logging sink exports selected application logs to BigQuery.

``` text
Logging sink:
starfleet-gke-app-logs

BigQuery dataset:
starfleet_gke_logs
```

The log table is partitioned for analysis.

This demonstrates a centralized operational-analysis path:

``` text
GKE Applications
      |
      v
Cloud Logging
      |
      v
Logging Sink
      |
      v
BigQuery
      |
      v
SQL Analysis
```

------------------------------------------------------------------------

## 15. Cloud Monitoring and Grafana

Google Cloud Monitoring provides the metrics backend for the GKE
workloads.

Grafana runs on a dedicated Compute Engine VM:

``` text
starfleet-grafana
```

The VM uses a dedicated Google service account with:

``` text
roles/monitoring.viewer
```

Grafana authenticates through the VM's attached GCE identity rather than
a service-account JSON key.

The final dashboard contains six primary panels:

``` text
+----------------------------------+----------------------------------+
| Alpha - Application CPU          | Delta - Application CPU          |
+----------------------------------+----------------------------------+
| Alpha - Application Memory       | Delta - Application Memory       |
+----------------------------------+----------------------------------+
| Alpha - Running Pods             | Delta - Running Pods             |
+----------------------------------+----------------------------------+
```

The dashboard uses PromQL queries against Google Cloud Monitoring
metrics.

The final Grafana dashboard JSON was exported for source control as:

``` text
docs/monitoring/grafana/starfleet-gke-platform-dashboard.json
```

This makes the monitoring configuration reviewable and reproducible.

------------------------------------------------------------------------

## 16. GKE Fleet

Both GKE clusters were registered with GKE Fleet.

Memberships:

``` text
enterprise-gke-alpha
enterprise-gke-delta
```

Alpha was selected as the Multi-Cluster Gateway configuration cluster.

The configuration cluster acts as the Kubernetes configuration authority
for the Gateway resources; it is not simply a permanent primary traffic
destination.

------------------------------------------------------------------------

## 17. Multi-Cluster Services

GKE Multi-Cluster Services was enabled.

Navigation is exported from both clusters using:

``` text
ServiceExport
```

Corresponding:

``` text
ServiceImport
```

resources allow the Multi-Cluster Gateway to reference the service
across the Fleet.

Multi-Cluster Services validation showed successful processing for Alpha
and Delta.

------------------------------------------------------------------------

## 18. Multi-Cluster Gateway

The platform uses:

``` text
gke-l7-global-external-managed-mc
```

as the Multi-Cluster GatewayClass.

The implemented traffic architecture is:

``` text
                         Internet
                            |
                            v
                    Global Static IP
                     34.49.192.254
                            |
                            v
                 Multi-Cluster Gateway
                starfleet-global-gateway
                     /             \
                    /               \
                   v                 v
       enterprise-gke-alpha    enterprise-gke-delta
          us-central1-a           us-east1-b
                 |                    |
                 v                    v
          Navigation Pods       Navigation Pods
```

Gateway validation showed the expected programmed and healthy state.

The HTTPRoute references the multi-cluster Navigation `ServiceImport`.

------------------------------------------------------------------------

## 19. Global Static IP

A global external IPv4 address is managed through Terraform.

Resource name:

``` text
starfleet-global-gateway-ip
```

Address:

``` text
34.49.192.254
```

The Gateway references it using:

``` yaml
addresses:
  - type: NamedAddress
    value: starfleet-global-gateway-ip
```

This provides a stable public frontend suitable for future DNS
configuration.

------------------------------------------------------------------------

## 20. Multi-Cluster Failover and Failback

Cross-region application failover was tested using the Navigation
service.

### Normal State

The global endpoint returned Alpha:

``` json
{"quadrant":"alpha","service":"starfleet-navigation-service","status":"operational"}
```

### Simulated Alpha Failure

The Alpha Navigation deployment was temporarily scaled to zero:

``` bash
kubectl scale deployment starfleet-navigation-service --replicas=0
```

Repeated requests to the same global frontend transitioned to Delta:

``` json
{"quadrant":"delta","service":"starfleet-navigation-service","status":"operational"}
```

### Failback

Alpha was restored:

``` bash
kubectl scale deployment starfleet-navigation-service --replicas=2
kubectl rollout status deployment/starfleet-navigation-service
```

Traffic subsequently returned to Alpha.

### Validation Result

``` text
Normal state:              Alpha   PASS
Alpha backend unavailable: Delta   PASS
Alpha restored:            Alpha   PASS
```

This demonstrated application-level failover and failback across two GCP
regions while preserving the same global client endpoint.

------------------------------------------------------------------------

## 21. Cloud DNS Decision

The Cloud DNS API is enabled.

A public DNS zone was intentionally not created because the lab does not
currently use an owned public domain available for delegation.

The global application can therefore be accessed through the static IP:

``` text
34.49.192.254
```

For production, an owned hostname could point to this address using an
`A` record.

This is an intentional lab design decision rather than an incomplete
infrastructure failure.

------------------------------------------------------------------------

## 22. Troubleshooting and Operational Experience

Real issues encountered during implementation were documented under:

``` text
docs/troubleshooting/
```

Examples include:

-   kubectl authentication failure
-   container architecture mismatch
-   insufficient CPU / Pending pods
-   topology spread configuration
-   Communications selector error
-   Cloud Monitoring CLI behavior
-   Grafana SSH firewall access
-   Grafana VM resizing
-   Delta zonal resource-pool exhaustion
-   live Deployment spec vs `last-applied-configuration`
-   Gateway API configuration verification
-   Fleet CLI feature verification
-   duplicate Terraform resource declaration
-   Binary Authorization troubleshooting

One of the most important Kubernetes findings was that low actual CPU
utilization does not necessarily mean a node has enough schedulable
capacity.

Kubernetes schedules against declared resource requests.

Another important infrastructure finding was that project quota does not
guarantee that a particular GCP zone has immediate VM capacity.

------------------------------------------------------------------------

## 23. Lab vs Production Design

The project intentionally uses several cost-conscious lab decisions.

  -----------------------------------------------------------------------
  Lab Implementation                  Production Direction
  ----------------------------------- -----------------------------------
  Zonal GKE clusters                  Regional GKE clusters

  Small fixed node pools              Capacity planning and node
                                      autoscaling

  Public-node lab design              Private nodes and controlled egress

  Direct cluster LoadBalancer         Remove unnecessary public cluster
  Services retained for testing       endpoints

  Single Grafana VM                   HA or managed observability
                                      platform

  Direct TCP/3000 Grafana access      HTTPS and enterprise authentication
  restricted by `/32`                 

  Flask development server            Production application server

  Static IP without public DNS        Owned domain and managed DNS

  Manual failover testing             Automated resilience testing
  -----------------------------------------------------------------------

The goal is to demonstrate architecture and operational concepts without
incurring the cost and complexity of a full production platform.

------------------------------------------------------------------------

## 24. Major Capabilities Demonstrated

The project demonstrates hands-on experience with:

-   Terraform-based GCP provisioning
-   VPC and subnet architecture
-   VPC-native GKE networking
-   multi-cluster Kubernetes
-   Docker and Artifact Registry
-   Kubernetes Deployments and Services
-   readiness and liveness probes
-   resource requests and limits
-   rolling deployments
-   Horizontal Pod Autoscaling
-   topology-aware scheduling
-   Workload Identity
-   Secret Manager
-   Cloud Storage IAM
-   GitHub Actions
-   Workload Identity Federation
-   container vulnerability scanning
-   Binary Authorization
-   Cloud Logging
-   BigQuery
-   Cloud Monitoring
-   Grafana
-   GKE Fleet
-   Multi-Cluster Services
-   Gateway API
-   Multi-Cluster Gateway
-   global application load balancing
-   global static addressing
-   cross-region failover and failback
-   GKE and Terraform troubleshooting
-   technical documentation

------------------------------------------------------------------------

## 25. Documentation Created

The project documentation includes:

``` text
docs/
├── architecture.md
├── command-ref.md
├── project-implementation-summary.md
├── cloud-monitoring-grafana-validation.md
├── logging-bigquery-validation.md
├── workload-identity.md
├── secret-manager.md
├── github-actions-cicd.md
├── binary-authorization.md
├── multi-cluster-gateway-failover-validation.md
├── monitoring/
│   └── grafana/
│       └── starfleet-gke-platform-dashboard.json
└── troubleshooting/
    ├── README.md
    ├── binary-authorization-troubleshooting.md
    └── additional incident-specific troubleshooting documents
```

The exact repository tree can evolve as the documentation is refined.

------------------------------------------------------------------------

## 26. Final Evidence / Cleanup

The major platform capabilities are implemented and documented.

Before considering the lab completely closed, the final operational
review should confirm:

-   Alpha and Delta are at the intended lab node counts.
-   temporary replica changes made during troubleshooting have been
    restored.
-   HPA configuration matches the intended steady-state configuration.
-   Navigation and Communications workloads are healthy.
-   the global Multi-Cluster Gateway endpoint is healthy.
-   the Grafana dashboard screenshot has been captured for assessment
    evidence.
-   Terraform shows no unintended infrastructure drift.
-   final documentation changes are committed and pushed.

These are final-state verification and evidence tasks rather than
missing platform architecture components.

------------------------------------------------------------------------

## 27. Final Architecture

``` text
                           GitHub
                              |
                              v
                    GitHub Actions CI/CD
                              |
                 Workload Identity Federation
                              |
                  Trivy + Image Attestation
                              |
                              v
                     Artifact Registry
                              |
                              v
                    Binary Authorization
                              |
                              v
                         GKE Workload

Internet
   |
   v
Global Static IP
34.49.192.254
   |
   v
Multi-Cluster Gateway
   |
   +-------------------------------+
   |                               |
   v                               v
GKE Alpha                       GKE Delta
us-central1-a                   us-east1-b
   |                               |
   +--------- Navigation -----------+
   |
   +------ Communications ----------+

Application Workloads
   |
   +--> Workload Identity
   |       |
   |       +--> Secret Manager
   |       +--> Cloud Storage
   |
   +--> Cloud Logging
   |       |
   |       +--> BigQuery
   |
   +--> Cloud Monitoring
           |
           +--> Grafana
```

The result is a working multi-cluster GKE platform lab demonstrating
infrastructure automation, secure CI/CD, workload identity, secret
management, centralized observability, global application routing, and
cross-region resilience.
