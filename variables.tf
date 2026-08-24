variable "project_id" {
  description = "GCP project ID for the Starfleet platform lab"
  type        = string
}

variable "region" {
  description = "Primary GCP region for the Starfleet platform"
  type        = string
  default     = "us-central1"
}
