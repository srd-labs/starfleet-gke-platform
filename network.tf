resource "google_compute_network" "starfleet_vpc" {
  name                    = "starfleet-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "alpha_quadrant" {
  name          = "alpha-quadrant-subnet"
  region        = "us-central1"
  network       = google_compute_network.starfleet_vpc.id
  ip_cidr_range = "10.10.0.0/24"

  secondary_ip_range {
    range_name    = "alpha-pods"
    ip_cidr_range = "10.20.0.0/16"
  }

  secondary_ip_range {
    range_name    = "alpha-services"
    ip_cidr_range = "10.30.0.0/20"
  }
}

resource "google_compute_subnetwork" "delta_quadrant" {
  name          = "delta-quadrant-subnet"
  region        = "us-east1"
  network       = google_compute_network.starfleet_vpc.id
  ip_cidr_range = "10.40.0.0/24"

  secondary_ip_range {
    range_name    = "delta-pods"
    ip_cidr_range = "10.50.0.0/16"
  }

  secondary_ip_range {
    range_name    = "delta-services"
    ip_cidr_range = "10.60.0.0/20"
  }
}
