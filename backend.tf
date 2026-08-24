terraform {
  backend "gcs" {
    bucket = "starfleet-gke-tfstate-1787575717"
    prefix = "starfleet/platform"
  }
}
