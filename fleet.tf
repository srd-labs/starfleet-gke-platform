# -------------------------------------------------------------------
# GKE Fleet / Multi-Cluster Platform APIs
# -------------------------------------------------------------------

# Retrieves project metadata, including the numeric project ID used
# when constructing Google-managed service-agent identities.
data "google_project" "current" {
  project_id = var.project_id
}


# Enables GKE Fleet (GKE Hub).
# Fleet provides the logical grouping required to manage the Alpha
# and Delta GKE clusters as one multi-cluster environment.
resource "google_project_service" "gke_hub_api" {
  project = var.project_id
  service = "gkehub.googleapis.com"

  disable_on_destroy = false
}

# Enables Multi-cluster Services.
# This provides service discovery across Fleet-registered clusters
# and is used by Multi-cluster Gateway backends.
resource "google_project_service" "multi_cluster_services_api" {
  project = var.project_id
  service = "multiclusterservicediscovery.googleapis.com"

  disable_on_destroy = false
}

# Enables the Multi-cluster Ingress/Gateway control-plane API.
# Multi-cluster Gateway uses this service when managing global
# load-balancing resources for Fleet clusters.
resource "google_project_service" "multi_cluster_ingress_api" {
  project = var.project_id
  service = "multiclusteringress.googleapis.com"

  disable_on_destroy = false
}

# -------------------------------------------------------------------
# GKE Fleet Memberships
# -------------------------------------------------------------------

# Registers the Alpha GKE cluster with the project Fleet.
# Fleet registration allows Alpha to participate in shared
# multi-cluster features such as Multi-cluster Services and Gateway.
resource "google_gke_hub_membership" "alpha" {
  project       = var.project_id
  membership_id = "enterprise-gke-alpha"
  location      = "global"

  endpoint {
    gke_cluster {
      resource_link = google_container_cluster.alpha.id
    }
  }

  depends_on = [
    google_project_service.gke_hub_api
  ]
}

# Registers the Delta GKE cluster with the same Fleet so that
# applications can be exposed across both GCP regions.
resource "google_gke_hub_membership" "delta" {
  project       = var.project_id
  membership_id = "enterprise-gke-delta"
  location      = "global"

  endpoint {
    gke_cluster {
      resource_link = google_container_cluster.delta.id
    }
  }

  depends_on = [
    google_project_service.gke_hub_api
  ]
}

# Enables the Cloud Service Mesh / Traffic Director control-plane API
# required by GKE Multi-cluster Gateway.
resource "google_project_service" "traffic_director_api" {
  project            = var.project_id
  service            = "trafficdirector.googleapis.com"
  disable_on_destroy = false
}

# Enables the Connect Gateway API.
# Multi-cluster Services uses this API as part of Fleet-based
# communication and management across registered GKE clusters.
resource "google_project_service" "connect_gateway_api" {
  project            = var.project_id
  service            = "connectgateway.googleapis.com"
  disable_on_destroy = false
}


# Enables Cloud DNS.
# Multi-cluster Gateway uses Cloud DNS internally for multi-cluster
# service discovery, and we will also use Cloud DNS later for the
# application's public DNS record.
resource "google_project_service" "cloud_dns_api" {
  project            = var.project_id
  service            = "dns.googleapis.com"
  disable_on_destroy = false
}

# -------------------------------------------------------------------
# Multi-Cluster Services
# -------------------------------------------------------------------

# Enables Multi-cluster Services for the GKE Fleet.
#
# MCS allows Kubernetes Services in Fleet member clusters to be
# exported and discovered across clusters. Navigation services in
# Alpha and Delta will later be exposed through ServiceExport and
# used as backends for the Multi-cluster Gateway.
resource "google_gke_hub_feature" "multi_cluster_services" {
  project  = var.project_id
  name     = "multiclusterservicediscovery"
  location = "global"

  depends_on = [
    google_project_service.multi_cluster_services_api,
    google_project_service.connect_gateway_api,
    google_project_service.traffic_director_api,
    google_project_service.cloud_dns_api,
    google_gke_hub_membership.alpha,
    google_gke_hub_membership.delta
  ]
}

# -------------------------------------------------------------------
# Multi-Cluster Gateway
# -------------------------------------------------------------------

# Enables the Fleet Multi-cluster Ingress/Gateway controller.
#
# Alpha is designated as the config cluster. Gateway, HTTPRoute,
# and related routing resources will be created in Alpha, while
# application traffic can be distributed across services running
# in both Alpha and Delta.
resource "google_gke_hub_feature" "multi_cluster_gateway" {
  project  = var.project_id
  name     = "multiclusteringress"
  location = "global"

  spec {
    multiclusteringress {
      config_membership = google_gke_hub_membership.alpha.id
    }
  }

  depends_on = [
    google_project_service.multi_cluster_ingress_api,
    google_project_service.traffic_director_api,
    google_gke_hub_membership.alpha,
    google_gke_hub_membership.delta,
    google_gke_hub_feature.multi_cluster_services
  ]
}

# -------------------------------------------------------------------
# Multi-Cluster Services IAM
# -------------------------------------------------------------------

# Allows the MCS importer running through GKE Workload Identity
# to inspect VPC networking information required to manage
# multi-cluster service connectivity.
resource "google_project_iam_member" "mcs_network_viewer" {
  project = var.project_id
  role    = "roles/compute.networkViewer"

  member = "serviceAccount:${var.project_id}.svc.id.goog[gke-mcs/gke-mcs-importer]"
}

# Grants the Google-managed Multi-cluster Service Discovery
# service agent the permissions required to operate MCS.
resource "google_project_iam_member" "mcs_service_agent" {
  project = var.project_id
  role    = "roles/multiclusterservicediscovery.serviceAgent"

  member = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-mcsd.iam.gserviceaccount.com"
}

# -------------------------------------------------------------------
# Multi-Cluster Gateway IAM
# -------------------------------------------------------------------

# Allows the Google-managed Multi-cluster Gateway controller
# to manage Kubernetes resources across the Fleet member clusters.
resource "google_project_iam_member" "multi_cluster_gateway_container_admin" {
  project = var.project_id
  role    = "roles/container.admin"

  member = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-multiclusteringress.iam.gserviceaccount.com"
}
