# Deployment Last-Applied Configuration vs Live Spec

## Symptom

While validating the Navigation deployment, this command was used:

``` bash
kubectl get deployment starfleet-navigation-service -o yaml
```

The output contained the annotation:

``` text
kubectl.kubernetes.io/last-applied-configuration
```

The annotation included older image and environment configuration, which
initially appeared to indicate that the deployment was still using an
old release.

## Investigation

Instead of relying on the annotation, inspect the live Deployment pod
template directly.

Check the live image:

``` bash
kubectl get deployment starfleet-navigation-service \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
echo
```

The live Navigation image was verified as the immutable digest:

``` text
us-central1-docker.pkg.dev/starfleet-gke-platform-lab/starfleet-apps/starfleet-navigation-service@sha256:4bad968954586cdc9cc947f3730c811764e7c2aab9f215ef203b597128a627d3
```

Check the live environment variables:

``` bash
kubectl get deployment starfleet-navigation-service \
  -o jsonpath='{.spec.template.spec.containers[0].env}'
echo
```

On Delta, the live specification included:

``` text
QUADRANT=delta
```

## Root Cause

`kubectl.kubernetes.io/last-applied-configuration` is historical
configuration stored as an annotation.

It is not guaranteed to represent the current live Deployment
specification, particularly after changes made with commands such as:

``` bash
kubectl set image
kubectl set env
```

## Resolution

The deployment was validated using fields directly under:

``` text
.spec.template.spec.containers
```

This confirmed the current immutable image digest and current
environment configuration.

## Validation

Useful commands:

``` bash
kubectl get deployment starfleet-navigation-service \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
echo
```

``` bash
kubectl get deployment starfleet-navigation-service \
  -o jsonpath='{.spec.template.spec.containers[0].env}'
echo
```

## Lessons Learned

Do not confuse `last-applied-configuration` with the current live
Kubernetes specification.

When validating what a Deployment will actually run, query the relevant
`.spec` fields directly.
