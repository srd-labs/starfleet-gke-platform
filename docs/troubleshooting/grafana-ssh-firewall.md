# Grafana VM SSH Connection Failed

## Symptom

The Grafana Compute Engine VM was created successfully, but SSH access
to the instance failed.

Grafana TCP port `3000` had already been allowed through a
Terraform-managed firewall rule.

## Investigation

Existing VPC firewall rules were reviewed.

The custom `starfleet-vpc` allowed Grafana access on TCP port `3000`,
but there was no applicable ingress rule allowing SSH on TCP port `22`
from the administrator workstation.

## Root Cause

The custom VPC did not have an SSH ingress rule applicable to the
Grafana VM.

## Resolution

A dedicated Terraform-managed SSH firewall rule was added.

The rule:

-   allows TCP port `22`;
-   targets the `starfleet-grafana` network tag;
-   restricts the source to the administrator's current public `/32`
    CIDR.

Example:

``` hcl
resource "google_compute_firewall" "grafana_ssh" {
  name    = "allow-starfleet-grafana-ssh"
  network = google_compute_network.starfleet_vpc.name

  # Restrict SSH access to the administrator workstation rather than
  # exposing TCP/22 to the public internet.
  source_ranges = [var.grafana_admin_cidr]
  target_tags   = ["starfleet-grafana"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}
```

## Validation

After applying Terraform, SSH access succeeded:

``` bash
gcloud compute ssh starfleet-grafana \
  --zone=us-central1-a \
  --project=starfleet-gke-platform-lab
```

The Grafana Docker container was then verified:

``` bash
sudo docker ps
```

## Lesson Learned

A VM having an external IP does not automatically make SSH reachable in
a custom VPC. Required ingress must be explicitly allowed.

For this lab, SSH is intentionally restricted to a single administrator
`/32`. A production environment should consider stronger administrative
access patterns such as IAP and private instances.
