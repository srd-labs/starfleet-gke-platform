# Starfleet GKE Platform — Architecture Design

## 1. Purpose

The **Starfleet GKE Platform** is a hands-on Google Cloud platform engineering project designed to demonstrate the deployment and operation of a resilient, multi-cluster Kubernetes environment.

The project covers:

- Infrastructure as Code using Terraform
- Google Cloud networking
- Multi-cluster GKE architecture
- Containerized web applications
- Kubernetes multi-pod deployments
- Load balancing and application ingress
- Centralized logging and monitoring
- BigQuery-based log analytics
- Grafana dashboards
- Operational troubleshooting
- Cost-conscious cloud infrastructure design

The lab implementation is designed to demonstrate production architecture concepts while keeping cloud costs appropriate for a learning environment.

---

## 2. Repository Strategy

Platform infrastructure and application workloads are maintained separately.

### Platform Repository

`starfleet-gke-platform`

Responsible for:

- GCP project configuration
- VPC networking
- Subnets and IP allocation
- GKE clusters
- IAM
- Logging
- Monitoring
- BigQuery
- Load balancing
- Terraform state configuration
- Platform documentation

### Application Repository

`starfleet-apps`

Responsible for:

- Application source code
- Dockerfiles
- Container build configuration
- Kubernetes Deployments
- Kubernetes Services
- Horizontal Pod Autoscaling
- Application configuration

This separation allows infrastructure and applications to have independent development and CI/CD lifecycles.

---

## 3. GCP Project

**Project Name:** Starfleet GKE Platform Lab  
**Project ID:** `starfleet-gke-platform-lab`

The project currently exists without a GCP Organization parent because it is implemented using an individual GCP account.

In an enterprise environment, the project would normally exist within an organizational resource hierarchy:

```text
Organization
└── Folder
    └── Project
```

---

## 4. Network Architecture

A custom-mode Google Cloud VPC is used.

**VPC:** `starfleet-vpc`

The VPC is global, while subnets are regional.

```text
starfleet-vpc
│
├── alpha-quadrant-subnet
│   └── us-central1
│
└── delta-quadrant-subnet
    └── us-east1
```

### Alpha Quadrant

**Subnet:** `alpha-quadrant-subnet`  
**Region:** `us-central1`

| Purpose | CIDR | Range Name |
|---|---|---|
| GKE Nodes | `10.10.0.0/24` | Primary subnet range |
| GKE Pods | `10.20.0.0/16` | `alpha-pods` |
| Kubernetes Services | `10.30.0.0/20` | `alpha-services` |

### Delta Quadrant

**Subnet:** `delta-quadrant-subnet`  
**Region:** `us-east1`

| Purpose | CIDR | Range Name |
|---|---|---|
| GKE Nodes | `10.40.0.0/24` | Primary subnet range |
| GKE Pods | `10.50.0.0/16` | `delta-pods` |
| Kubernetes Services | `10.60.0.0/20` | `delta-services` |

All address ranges are non-overlapping.

---

## 5. Planned GKE Architecture

Two GKE clusters will be deployed.

### Alpha Quadrant Cluster

Primary GKE cluster located in `us-central1`.

Planned responsibilities:

- Primary application environment
- Application A
- Application B
- Multiple pod replicas
- Kubernetes Services
- Horizontal Pod Autoscaling

### Delta Quadrant Cluster

Secondary GKE cluster located in `us-east1`.

Planned responsibilities:

- Secondary / DR environment
- Application A
- Application B
- Multiple pod replicas
- Kubernetes Services
- Horizontal Pod Autoscaling

For the lab implementation, **zonal GKE Standard clusters** are being considered to reduce cost while exposing node-pool management and other GKE operational concepts.

A production implementation could use regional GKE clusters for higher availability.

---

## 6. Terraform

Infrastructure is provisioned using Terraform.

Terraform currently manages:

- `starfleet-vpc`
- `alpha-quadrant-subnet`
- `delta-quadrant-subnet`

Terraform state is stored remotely in a **Google Cloud Storage (GCS) backend**.

Remote state was selected so infrastructure state is not dependent on a single engineer's workstation and can later support team and CI/CD workflows.

Conceptually:

```text
Developer / CI
      |
      v
   Terraform
    /     \
   v       v
GCP APIs   GCS Backend
             |
             v
       Terraform State
```

---

## 7. Cost Management

The project is designed as a temporary lab environment rather than an always-running production platform.

Cost-control principles include:

- Small GKE node pools
- Zonal clusters for the lab
- Minimal application resource requests
- Limited logging volume
- Terraform-managed infrastructure
- Destroying expensive resources when they are not required
- Monitoring project spending through GCP budget alerts

The architecture documentation will distinguish between the cost-optimized lab implementation and the recommended production architecture.

---

## 8. Planned Observability Architecture

The planned logging and analytics flow is:

```text
GKE Workloads
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
Grafana
```

Cloud Monitoring will provide infrastructure and Kubernetes metrics.

The final Grafana dashboard is planned to include:

1. Application error rates
2. Pod restart counts
3. Request latency
4. CPU and memory utilization

BigQuery will also be used directly to demonstrate log-analysis queries.

---

## 9. Current Implementation Status

### Completed

- [x] GCP project creation
- [x] Billing configuration
- [x] Budget alerts
- [x] Google Cloud CLI installation and configuration
- [x] Terraform installation and configuration
- [x] kubectl installation
- [x] Terraform GCS remote backend
- [x] Custom VPC
- [x] Alpha Quadrant subnet design
- [x] Delta Quadrant subnet design
- [x] GKE Pod and Service secondary IP ranges

### Next

- [ ] GKE architecture and cost analysis
- [ ] Alpha Quadrant GKE cluster
- [ ] Delta Quadrant GKE cluster
- [ ] Application deployment
- [ ] Load balancing / ingress
- [ ] Cloud Logging and Monitoring
- [ ] BigQuery log export
- [ ] BigQuery analysis queries
- [ ] Grafana dashboard
- [ ] Troubleshooting scenario
- [ ] Final architecture diagram
- [ ] Assessment documentation

