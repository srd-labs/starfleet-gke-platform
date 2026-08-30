# Topology Spread Configuration Error

## Symptom

A Kubernetes Deployment did not accept or correctly apply the intended
`topologySpreadConstraints` configuration.

## Investigation

The deployment YAML was reviewed and the topology-spread configuration
was found at the wrong indentation/location in the manifest.

`topologySpreadConstraints` is a Pod specification field.

## Root Cause

The field was not placed under:

``` text
spec.template.spec
```

## Resolution

Move the topology-spread configuration into the Pod specification:

``` yaml
spec:
  template:
    spec:
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: kubernetes.io/hostname
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              app: <APPLICATION_LABEL>
```

This configuration spreads replicas across worker-node hostnames.

## Validation

Apply the corrected manifest:

``` bash
kubectl apply -f <DEPLOYMENT_FILE>
```

Then inspect placement:

``` bash
kubectl get pods -o wide
```

With two nodes available, application replicas should normally appear on
different nodes.

## Lesson Learned

Kubernetes YAML structure is significant. Scheduling settings such as
`topologySpreadConstraints` belong to the Pod specification at
`spec.template.spec`.
