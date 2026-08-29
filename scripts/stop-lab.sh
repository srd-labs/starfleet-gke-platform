#!/usr/bin/env bash
set -e

echo "Parking Starfleet GKE lab..."
echo "Scaling Alpha and Delta node pools to 0."

terraform apply \
  -var="alpha_node_count=0" \
  -var="delta_node_count=0"
