# Troubleshooting Guide

This directory documents real issues encountered while building and
operating the Starfleet GKE Platform Lab.

Each document records the symptom, investigation, root cause,
resolution, validation, and lessons learned.

  ---------------------------------------------------------------------------------------
  Issue                                               Area
  --------------------------------------------------- -----------------------------------
  [Kubectl Authentication                             GKE / kubectl
  Failed](kubectl-authentication-failed.md)           

  [Container Architecture                             Docker / GKE
  Mismatch](container-architecture-mismatch.md)       

  [Insufficient CPU / Pending                         GKE / Kubernetes
  Pods](insufficient-cpu-pending-pods.md)             

  [Topology Spread                                    Kubernetes
  Configuration](topology-spread-configuration.md)    

  [Communications Selector                            Kubernetes
  Error](communications-selector-error.md)            

  [Cloud Monitoring CLI                               Cloud Monitoring
  Command](cloud-monitoring-cli.md)                   

  [Grafana SSH Firewall](grafana-ssh-firewall.md)     Compute Engine / Networking

  [Grafana VM Resize](grafana-vm-resize.md)           Compute Engine / Grafana

  [Delta Zone Resource Pool                           GKE / Compute Engine
  Exhausted](delta-zone-resource-pool-exhausted.md)   

  [Deployment Last-Applied vs Live                    Kubernetes
  Spec](deployment-last-applied-vs-live-spec.md)      

  [Gateway API Configuration                          GKE / Gateway API
  Verification](gateway-api-config-verification.md)   

  [Fleet CLI Feature                                  GKE Fleet
  Verification](fleet-cli-feature-verification.md)    

  [Terraform Duplicate Resource                       Terraform / GCP APIs
  Declaration](terraform-duplicate-resource.md)       
  ---------------------------------------------------------------------------------------

The successful Multi-Cluster Gateway failover and failback test is
documented separately as platform validation rather than as a
troubleshooting incident:

``` text
../multi-cluster-gateway-failover-validation.md
```
