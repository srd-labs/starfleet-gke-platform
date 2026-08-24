# Alpha Quadrant GKE cluster
# Primary lab cluster deployed in us-central1-a.
resource "google_container_cluster" "alpha" {
  name     = "enterprise-gke-alpha"
  location = "us-central1-a"

  # Attach the cluster to the Starfleet custom VPC
  # and Alpha Quadrant regional subnet.
  network    = google_compute_network.starfleet_vpc.id
  subnetwork = google_compute_subnetwork.alpha_quadrant.id

  # Remove the automatically created default node pool.
  # Worker nodes are managed separately below.
  remove_default_node_pool = true
  initial_node_count       = 1

  # Use VPC-native / alias-IP networking.
  networking_mode = "VPC_NATIVE"

  # Secondary subnet ranges reserved earlier for
  # Kubernetes Pods and Services.
  ip_allocation_policy {
    cluster_secondary_range_name  = "alpha-pods"
    services_secondary_range_name = "alpha-services"
  }

  # Lab setting. Allows Terraform to destroy the cluster
  # when we're finished to avoid unnecessary GCP charges.
  deletion_protection = false

  # GKE cannot be created until the Kubernetes Engine API is enabled.
  depends_on = [
    google_project_service.container_api
  ]
}


# Worker node pool for the Alpha Quadrant cluster.
resource "google_container_node_pool" "alpha_nodes" {
  name     = "alpha-node-pool"
  location = "us-central1-a"
  cluster  = google_container_cluster.alpha.name

  # One worker node is sufficient for the lab.
  # Production environments would normally use multiple nodes.
  node_count = 1

  node_config {
    # Cost-conscious machine size for the lab.
    machine_type = "e2-medium"

    # Small boot disk is sufficient for our lab workloads.
    disk_size_gb = 30
    disk_type    = "pd-balanced"

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # Labels make workloads/resources easier to identify.
    labels = {
      quadrant    = "alpha"
      environment = "lab"
    }

    # Disable legacy Compute Engine metadata endpoints.
    metadata = {
      disable-legacy-endpoints = "true"
    }
  }
}
