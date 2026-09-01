# Workload Identity

## Overview

Workload Identity is enabled on both GKE clusters so Kubernetes workloads can authenticate to Google Cloud services without storing service account JSON keys inside containers, Kubernetes Secrets, or source repositories.

Clusters:

- `enterprise-gke-alpha`
- `enterprise-gke-delta`

## Architecture

```text
Application Pod
      |
      v
Kubernetes ServiceAccount
      |
      v
Workload Identity
      |
      v
Google Service Account
      |
      v
Google Cloud API
```
