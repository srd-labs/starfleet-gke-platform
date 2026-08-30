# Troubleshooting: Grafana VM Resize Failed Because Instance Was Running

## Symptom

While resizing the Grafana Compute Engine VM from `e2-micro` to
`e2-small`, Terraform generated an in-place update:

``` text
machine_type = "e2-micro" -> "e2-small"

Plan: 0 to add, 1 to change, 0 to destroy.
```

However, `terraform apply` failed because changing the machine type on a
running Compute Engine instance requires the VM to be stopped.

## Investigation

The Terraform plan showed that the VM did not need to be destroyed or
replaced. The machine type could be updated in place, but Google Compute
Engine requires the instance to be stopped before changing its machine
type.

Terraform does not stop a running instance for this type of update
unless that behavior is explicitly allowed.

## Root Cause

The Grafana VM resource did not have:

``` hcl
allow_stopping_for_update = true
```

Without this setting, Terraform refused to automatically stop the
running VM before changing its machine type.

## Resolution

The following setting was added to the Grafana Compute Engine resource:

``` hcl
# Allow Terraform to temporarily stop the VM when an in-place update,
# such as a machine type resize, requires the instance to be powered off.
allow_stopping_for_update = true
```

The Grafana VM was also changed from:

``` hcl
machine_type = "e2-micro"
```

to:

``` hcl
machine_type = "e2-small"
```

Terraform was then run again:

``` bash
terraform plan \
  -var="grafana_admin_cidr=<ADMIN_PUBLIC_IP>/32"

terraform apply \
  -var="grafana_admin_cidr=<ADMIN_PUBLIC_IP>/32"
```

## Why the VM Was Resized

Grafana was initially deployed on an `e2-micro` instance as a
cost-conscious lab configuration.

While displaying multiple Cloud Monitoring / GKE dashboard queries, the
VM showed significant memory pressure:

``` text
Mem:   969Mi total
       909Mi used
        60Mi available
Swap:     0B
```

The Grafana UI became slow and appeared to hang while processing
dashboard queries.

The VM was therefore increased to `e2-small` to provide additional
memory while keeping the monitoring environment relatively small.

## Validation

After applying the Terraform change, verify the VM configuration:

``` bash
gcloud compute instances list \
  --filter="name=starfleet-grafana" \
  --format="table(name,machineType,status)"
```

Then verify available memory from the Grafana VM:

``` bash
free -h
```

Verify the Grafana container is running:

``` bash
sudo docker ps
sudo docker stats --no-stream
```

## Lesson Learned

Some Compute Engine properties can be changed in place but still require
the VM to be temporarily stopped.

For Terraform-managed lab instances where controlled downtime is
acceptable, `allow_stopping_for_update = true` allows Terraform to
perform these updates without requiring manual VM stop/start operations.

> **Security note:** Keep the real administrator public IP out of
> committed documentation. Use `<ADMIN_PUBLIC_IP>/32` in examples and
> supply the actual value through Terraform variables or an
> appropriately protected `.tfvars` file.
