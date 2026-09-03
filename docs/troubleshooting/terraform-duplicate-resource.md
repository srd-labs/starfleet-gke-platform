# Terraform Duplicate Resource Declaration

## Symptom

While adding the APIs required for Fleet and Multi-Cluster Gateway, a
Cloud Resource Manager API Terraform resource was added to the new Fleet
configuration.

Terraform then reported a duplicate resource declaration.

## Investigation

The project already managed the Cloud Resource Manager API in another
Terraform file.

Search the module:

``` bash
grep -R "cloud_resource_manager_api" -n .
```

The existing declaration was found in:

``` text
grafana.tf
```

## Root Cause

Terraform reads all `.tf` files in a module directory together as one
configuration.

Files such as:

``` text
grafana.tf
fleet.tf
network.tf
```

are organizational boundaries for humans. They are not independent
Terraform configurations when they are in the same module directory.

The Cloud Resource Manager API resource was therefore being declared
twice in the same Terraform module.

## Resolution

The duplicate resource declaration was removed from the Fleet
configuration.

The existing declaration in `grafana.tf` remained the Terraform source
of truth for enabling that API.

The configuration was then checked:

``` bash
terraform fmt
terraform validate
terraform plan
```

## Validation

Terraform validation completed without the duplicate-resource error.

The Fleet resources were able to depend on the already-managed project
API rather than creating another declaration.

## Lessons Learned

Before adding a shared project-level Terraform resource, search the
existing module to determine whether it is already managed.

Useful searches include:

``` bash
grep -R "google_project_service" -n *.tf
```

and:

``` bash
grep -R "<resource-name>" -n .
```

Terraform resource uniqueness is based on the resource address within
the module, not the filename containing the block.
