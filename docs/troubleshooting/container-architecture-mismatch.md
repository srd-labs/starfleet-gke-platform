# Container Architecture Mismatch

## Symptom

The application image built successfully on the local Apple Silicon Mac,
but GKE could not run the container correctly and the workload entered
an image/startup failure state.

## Investigation

The application worked locally, but the GKE worker nodes used an AMD64
architecture.

The image had been built using the local machine's default architecture,
resulting in an ARM64 container image.

## Root Cause

The container image architecture did not match the architecture of the
GKE worker nodes:

``` text
Local build: ARM64
GKE nodes:   AMD64
```

## Resolution

Build and push an AMD64 image explicitly:

``` bash
docker buildx build \
  --platform linux/amd64 \
  -t <ARTIFACT_REGISTRY_IMAGE>:<TAG> \
  --push .
```

The Kubernetes Deployment was then updated or restarted to use the
corrected image.

## Validation

Check the workload:

``` bash
kubectl get pods
```

Then verify the application endpoint and health endpoint.

``` bash
kubectl logs <POD_NAME>
```

The pods should reach `Running` and the application should respond
successfully.

## Lesson Learned

When container images are built on Apple Silicon but deployed to AMD64
infrastructure, the target platform should be specified explicitly
during the image build.
