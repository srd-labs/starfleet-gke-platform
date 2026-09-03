# Delta Zone Resource Pool Exhausted

## Symptom

While increasing the Delta GKE node pool from two nodes to three,
Terraform failed while waiting for the node-pool resize.

The operation reported:

``` text
ZONE_RESOURCE_POOL_EXHAUSTED
```

Terraform showed the desired node count as three, but Kubernetes
continued to show only two Delta worker nodes. The node pool also
entered an error state.

## Investigation

Check the Terraform state:

``` bash
terraform state show google_container_node_pool.delta_nodes
```

Check the actual Kubernetes nodes:

``` bash
kubectl get nodes -o wide
```

Inspect the GKE node pool:

``` bash
gcloud container node-pools describe delta-node-pool \
  --cluster=enterprise-gke-delta \
  --zone=us-east1-b \
  --project=starfleet-gke-platform-lab \
  --format="yaml(name,status)"
```

The requested third node was not created and the node pool reported an
error.

## Root Cause

The selected GCP zone did not have sufficient available Compute Engine
capacity for the additional requested node at that time.

This was different from the Kubernetes `Insufficient cpu` scheduling
problem. Kubernetes scheduling capacity concerns resources available
inside existing nodes, while `ZONE_RESOURCE_POOL_EXHAUSTED` concerns
underlying Google Cloud infrastructure capacity in the selected zone.

## Resolution

For this lab, the Delta node count was returned to two rather than
moving or rebuilding the cluster in another zone.

The Terraform variable was restored to:

``` text
delta_node_count = 2
```

Terraform was applied again:

``` bash
terraform plan
terraform apply
```

The node pool was then checked:

``` bash
gcloud container node-pools describe delta-node-pool \
  --cluster=enterprise-gke-delta \
  --zone=us-east1-b \
  --project=starfleet-gke-platform-lab \
  --format="yaml(name,status)"
```

The recovered state was:

``` text
name: delta-node-pool
status: RUNNING
```

## Validation

``` bash
kubectl get nodes -o wide
```

Delta continued operating with its two-node lab configuration.

## Lessons Learned

Cloud quota and available zonal capacity are different.

A project may be permitted to create another VM while the selected zone
is temporarily unable to supply the requested machine capacity.

For a production platform, possible responses include using multiple
zones, regional clusters or node pools, alternative machine types, or
capacity reservations where appropriate.
