#!/usr/bin/env bash
set -e

echo "Starting Starfleet GKE lab..."
echo "Scaling Alpha and Delta node pools to 2."

terraform apply \
  -var="alpha_node_count=2" \
  -var="delta_node_count=2"
