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
