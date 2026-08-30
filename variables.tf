variable "project_id" {
  description = "GCP project ID for the Starfleet platform lab"
  type        = string
}

variable "region" {
  description = "Primary GCP region for the Starfleet platform"
  type        = string
  default     = "us-central1"
}




# This is for reducing cost
variable "alpha_node_count" {
  description = "Number of worker nodes in Alpha"
  type        = number
  default     = 2
}

variable "delta_node_count" {
  description = "Number of worker nodes in Delta"
  type        = number
  default     = 2
}

# -----------------------------------------------------------------------------
# Grafana Administrator Source CIDR
# -----------------------------------------------------------------------------
# Restricts browser access to the Grafana dashboard.
#
# For the lab, this should normally be the administrator's current public
# IPv4 address expressed as a /32 CIDR.
#
# Example:
# 73.45.100.25/32
# -----------------------------------------------------------------------------
variable "grafana_admin_cidr" {
  description = "Public IPv4 CIDR allowed to access Grafana on TCP port 3000"
  type        = string
}
