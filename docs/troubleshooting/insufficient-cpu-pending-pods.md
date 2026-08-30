# Pods Pending Due to Insufficient CPU

## Symptom

During application deployment and rolling updates, newly created pods
remained in `Pending`.

## Investigation

Pod events were inspected:

``` bash
kubectl describe pod <POD_NAME>
```

The scheduler reported insufficient CPU capacity on the available worker
nodes.

The lab initially had limited node capacity while multiple replicas and
rolling-update pods competed for CPU resources.

## Root Cause

The GKE cluster did not have enough schedulable CPU capacity for the
requested workload during the deployment operation.

Rolling updates can temporarily require additional capacity because old
and new pods can coexist during the rollout.

## Resolution

The lab cluster capacity was increased to two worker nodes.

Application resource requests and limits were also kept intentionally
small:

``` yaml
resources:
  requests:
    cpu: 50m
    memory: 128Mi
  limits:
    cpu: 250m
    memory: 256Mi
```

The rolling-update strategy was configured to avoid unnecessary surge
capacity:

``` yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 0
    maxUnavailable: 1
```

## Validation

Verify that all pods are scheduled:

``` bash
kubectl get pods -o wide
```

Check node resource usage:

``` bash
kubectl top nodes
kubectl top pods
```

All required application replicas should reach `Running`.

## Lesson Learned

Kubernetes scheduling depends on resource **requests**, not just
observed application utilization. Deployment strategies can also
temporarily change the capacity required during an update.
