# Communications Deployment Selector Error

## Symptom

While configuring the Communications service, its Kubernetes Deployment
contained an incorrect selector referring to the Navigation application.

## Investigation

The Communications Deployment manifest was compared with its Pod
template labels.

A copied configuration still contained the Navigation service label.

Kubernetes Deployment selectors must match the labels on the pods
managed by that Deployment.

## Root Cause

A copy/paste error caused the Communications Deployment selector to
reference the Navigation application instead of the Communications
application.

## Resolution

Update the selector and Pod labels so they consistently identify the
Communications service.

Example:

``` yaml
spec:
  selector:
    matchLabels:
      app: starfleet-communications-service

  template:
    metadata:
      labels:
        app: starfleet-communications-service
```

Any related Service or HPA selectors/targets should also reference the
intended Communications workload.

## Validation

Apply the corrected manifest and verify:

``` bash
kubectl get deployments
kubectl get pods --show-labels
kubectl get service
```

Confirm that the Communications service selects only Communications
pods.

## Lesson Learned

When Kubernetes manifests are copied between applications, selectors,
labels, container names, Service selectors, and HPA targets should all
be reviewed together.
