# Delta Quadrant GKE cluster
# Secondary / DR lab cluster deployed in us-east1-b.
resource "google_container_cluster" "delta" {
  name     = "enterprise-gke-delta"
  location = "us-east1-b"

  # Attach Delta to the Starfleet VPC and Delta regional subnet.
  network    = google_compute_network.starfleet_vpc.id
  subnetwork = google_compute_subnetwork.delta_quadrant.id

  # Manage the worker node pool separately from the cluster resource.
  remove_default_node_pool = true
  initial_node_count       = 1

  # VPC-native networking using the secondary ranges
  # reserved for Delta Pods and Services.
  networking_mode = "VPC_NATIVE"

  ip_allocation_policy {
    cluster_secondary_range_name  = "delta-pods"
    services_secondary_range_name = "delta-services"
  }

  # Allows Terraform cleanup of this lab cluster.
  deletion_protection = false

  depends_on = [
    google_project_service.container_api
  ]
}

# Worker node pool for Delta Quadrant.
resource "google_container_node_pool" "delta_nodes" {
  name       = "delta-node-pool"
  location   = "us-east1-b"
  cluster    = google_container_cluster.delta.name
  node_count = var.delta_node_count

  node_config {
    machine_type = "e2-medium"

    # Explicit disk configuration for predictable lab cost.
    disk_size_gb = 30
    disk_type    = "pd-balanced"

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = {
      quadrant    = "delta"
      environment = "lab"
    }

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }
}
