# -----------------------------------------------------------------------------
# Cloud Resource Manager API
# -----------------------------------------------------------------------------
# Enables project and resource metadata discovery used by Grafana's
# Google Cloud Monitoring data source.
#
# Cloud Monitoring provides the metric data, while Cloud Resource Manager
# allows Grafana to discover Google Cloud project/resource information.
# -----------------------------------------------------------------------------
resource "google_project_service" "cloud_resource_manager_api" {
  project = var.project_id
  service = "cloudresourcemanager.googleapis.com"

  disable_on_destroy = false
}

# -----------------------------------------------------------------------------
# Grafana Service Account
# -----------------------------------------------------------------------------
# Creates a dedicated Google Cloud service account for the Grafana VM.
#
# Grafana uses this identity to authenticate to Google Cloud Monitoring.
# A dedicated service account is used instead of the Compute Engine default
# service account so that the VM receives only the permissions it requires.
# -----------------------------------------------------------------------------
resource "google_service_account" "grafana" {
  account_id   = "starfleet-grafana"
  display_name = "Starfleet Grafana Monitoring"
  description  = "Service account used by Grafana to read Google Cloud Monitoring metrics"
}


# -----------------------------------------------------------------------------
# Grafana Cloud Monitoring IAM Permission
# -----------------------------------------------------------------------------
# Grants the Grafana service account read-only access to Cloud Monitoring.
#
# Grafana only needs to query metrics for dashboards, so Monitoring Viewer is
# sufficient. No administrative Monitoring permissions are granted.
# -----------------------------------------------------------------------------
resource "google_project_iam_member" "grafana_monitoring_viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.grafana.email}"
}


# -----------------------------------------------------------------------------
# Grafana Firewall Rule
# -----------------------------------------------------------------------------
# Allows inbound TCP traffic to Grafana on port 3000.
#
# This is acceptable for the lab environment because Grafana needs to be
# reachable from a browser for dashboard validation.
#
# NOTE:
# For a production environment, Grafana should normally be placed behind
# HTTPS, identity-aware access controls, or another secured ingress layer
# rather than exposing port 3000 directly to the Internet.
# -----------------------------------------------------------------------------
resource "google_compute_firewall" "grafana" {
  name    = "allow-starfleet-grafana"
  network = google_compute_network.starfleet_vpc.name

  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["3000"]
  }

  # Lab-only configuration.
  # We can restrict this to the administrator's public IP later.
  source_ranges = [var.grafana_admin_cidr]

  # Only instances carrying this network tag receive this firewall rule.
  target_tags = ["starfleet-grafana"]
}

# -----------------------------------------------------------------------------
# Grafana SSH Firewall Rule
# -----------------------------------------------------------------------------
# Allows SSH access to the Grafana VM only from the administrator's current
# public IP address.
#
# This is used for lab troubleshooting and validation of Docker/Grafana.
# -----------------------------------------------------------------------------
resource "google_compute_firewall" "grafana_ssh" {
  name    = "allow-starfleet-grafana-ssh"
  network = google_compute_network.starfleet_vpc.name

  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = [var.grafana_admin_cidr]

  # Apply this rule only to the Grafana VM.
  target_tags = ["starfleet-grafana"]
}

# -----------------------------------------------------------------------------
# Grafana Compute Engine VM
# -----------------------------------------------------------------------------
# Hosts Grafana on a small Compute Engine instance.
#
# The e2-micro machine type is intentionally selected to keep the lab
# lightweight and cost-conscious.
#
# Grafana authenticates to Google Cloud using the VM's attached service
# account instead of a downloaded service-account key.
# -----------------------------------------------------------------------------
resource "google_compute_instance" "grafana" {
  name         = "starfleet-grafana"
  machine_type = "e2-small"
  zone         = "us-central1-a"

  # Some Compute Engine changes, including machine type updates,
  # require the VM to be stopped temporarily. Terraform will stop
  # and restart the instance automatically when this is enabled.
  allow_stopping_for_update = true

  tags = ["starfleet-grafana"]

  boot_disk {
    initialize_params {
      # Debian is a lightweight base OS suitable for running Docker/Grafana.
      image = "debian-cloud/debian-12"

      # Small boot disk is sufficient for this Grafana lab environment.
      size = 10
      type = "pd-standard"
    }
  }

  network_interface {
    # Place Grafana inside the existing Starfleet VPC.
    subnetwork = google_compute_subnetwork.alpha_quadrant.id

    # Assign an ephemeral external IP so the dashboard can be accessed
    # directly from a browser during the lab.
    access_config {}
  }

  service_account {
    # Grafana uses this attached service account when communicating with
    # Google Cloud Monitoring through the Compute Engine metadata server.
    email = google_service_account.grafana.email

    # Google recommends the cloud-platform OAuth scope together with
    # least-privilege IAM roles on the service account.
    scopes = ["cloud-platform"]
  }

  # ---------------------------------------------------------------------------
  # Grafana Startup Script
  # ---------------------------------------------------------------------------
  # Installs Docker, creates Grafana's Cloud Monitoring data-source
  # configuration, and launches Grafana automatically when the VM starts.
  #
  # authenticationType=gce instructs Grafana to use the Compute Engine
  # service account attached above. No service-account key is stored.
  # ---------------------------------------------------------------------------
  metadata_startup_script = <<-EOT
    #!/bin/bash
    set -e
  
    apt-get update
    apt-get install -y docker.io

    systemctl enable docker
    systemctl start docker

    # Directory containing Grafana provisioning configuration.
    mkdir -p /opt/grafana/provisioning/datasources
  
    # Docker manages Grafana's persistent application data.
    docker volume create grafana-data

    cat > /opt/grafana/provisioning/datasources/google-cloud-monitoring.yaml <<'EOF'
    apiVersion: 1
   
    datasources:
      - name: Google Cloud Monitoring
        type: stackdriver
        access: proxy
        isDefault: true
        editable: true
        jsonData:
          authenticationType: gce
          defaultProject: ${var.project_id}
          universeDomain: googleapis.com
    EOF

    docker run -d \
      --name starfleet-grafana \
      --restart unless-stopped \
      -p 3000:3000 \
      -v grafana-data:/var/lib/grafana \
      -v /opt/grafana/provisioning:/etc/grafana/provisioning \
      grafana/grafana:latest
  EOT	


  # Ensure IAM has been granted before the VM starts Grafana.
  depends_on = [
    google_project_iam_member.grafana_monitoring_viewer
  ]

  labels = {
    environment = "lab"
    component   = "grafana"
  }
}


# -----------------------------------------------------------------------------
# Grafana External IP Output
# -----------------------------------------------------------------------------
# Displays the VM's ephemeral public IP after Terraform completes.
#
# Grafana will be accessible at:
# http://<grafana_external_ip>:3000
# -----------------------------------------------------------------------------
output "grafana_external_ip" {
  description = "Public IP address of the Starfleet Grafana VM"
  value       = google_compute_instance.grafana.network_interface[0].access_config[0].nat_ip
}

# Allows the Grafana service account to run BigQuery query jobs.
resource "google_project_iam_member" "grafana_bigquery_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.grafana.email}"
}

# Allows the Grafana service account to read BigQuery data.
resource "google_project_iam_member" "grafana_bigquery_data_viewer" {
  project = var.project_id
  role    = "roles/bigquery.dataViewer"
  member  = "serviceAccount:${google_service_account.grafana.email}"
}

# -----------------------------------------------------------------------------
# Grafana URL Output
# -----------------------------------------------------------------------------
# Generates the browser URL for the Grafana dashboard.
# -----------------------------------------------------------------------------
output "grafana_url" {
  description = "URL used to access the Starfleet Grafana instance"
  value       = "http://${google_compute_instance.grafana.network_interface[0].access_config[0].nat_ip}:3000"
}
