
#### kubectl authentication failed

```
CRITICAL: ACTION REQUIRED: gke-gcloud-auth-plugin, which is needed for continued use of kubectl, was not found or is not executable. Install gke-gcloud-auth-plugin for use with kubectl by following https://cloud.google.com/kubernetes-engine/docs/how-to/cluster-access-for-kubectl#install_plugin
```

```
kubectl authentication failed
        ↓
gke-gcloud-auth-plugin missing
        ↓
Installed plugin
        ↓
Retrieved cluster credentials
        ↓
kubectl get nodes → Ready
```
