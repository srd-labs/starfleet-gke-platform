# Reserve a global static IPv4 address for the Starfleet
# multi-cluster Gateway.
#
# Keeping the address as a separate GCP resource ensures that
# the public endpoint remains stable even if the Kubernetes
# Gateway resource is recreated.
resource "google_compute_global_address" "starfleet_global_gateway" {
  project      = var.project_id
  name         = "starfleet-global-gateway-ip"
  address_type = "EXTERNAL"
  ip_version   = "IPV4"
}
