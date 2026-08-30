# Kubectl Authentication Failed

## Symptom

After creating a GKE cluster, `kubectl` could not authenticate to the
cluster.

The local environment was missing the GKE authentication plugin required
by `kubectl` to obtain Google Cloud credentials.

## Investigation

The cluster existed and was reachable through Google Cloud, but local
`kubectl` commands failed during authentication.

The problem was isolated to the local client configuration rather than
the GKE control plane.

## Root Cause

The `gke-gcloud-auth-plugin` required for GKE authentication was not
installed or available to the local `kubectl` client.

## Resolution

Install the GKE authentication plugin using the appropriate Google Cloud
SDK installation method, then refresh cluster credentials:

``` bash
gcloud container clusters get-credentials <CLUSTER_NAME> \
  --zone=<ZONE> \
  --project=starfleet-gke-platform-lab
```

Verify that the plugin is available:

``` bash
gke-gcloud-auth-plugin --version
```

## Validation

Confirm cluster access:

``` bash
kubectl get nodes
```

Successful output should list the GKE worker nodes and show them as
`Ready`.

## Lesson Learned

A working GKE cluster is only one part of Kubernetes access. The local
workstation also needs the supported GKE authentication plugin and
current cluster credentials.
