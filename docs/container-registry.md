# Container Registry Design

## Overview

The Starfleet GKE Platform uses Google Cloud Artifact Registry to store and manage container images deployed to GKE.

Artifact Registry provides the boundary between application build processes and the Kubernetes runtime environment.

## Architecture

The container delivery flow is:

```text
Application GitHub Repository
        |
        v
Docker Build
        |
        v
Google Artifact Registry
        |
        v
GKE Cluster
        |
        v
Kubernetes Deployment
        |
        v
Application Pods
```
