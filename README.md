# Spacelift Spaces hierarchical Okta mapped Terraform Module

This module streamlines creating application and environment-level Spacelift spaces for a single team, according to the Spacelift best-practices topology. It also intelligently resolves Okta identity groups to custom Role IDs, switching automatically between production and non-production roles depending on the given space type. The team space defaults to the root space.

## Purpose

Suppose you have:
1.  Custom Roles already created in Spacelift (e.g. "reader" and "maintainer" roles for both Production and Non-Production).
2.  Okta groups synced to your Identity Provider.

You can declare a single `apps` map for a single team describing your organizational layout. This module unfolds the nested dictionary into `spacelift_space`, `spacelift_idp_group_mapping`, and recursive `spacelift_role_attachment` resources. By providing `okta_groups` in the standard nomenclature (`Spacelift_<app>_<team>_<permission_level>_<env>`), this module extracts the target space, role permissions, and environments recursively without requiring inline verbose bindings.

Environment names are restricted to `dev`, `test`, or `prod`. Note that `T` resolves to `test` if it exists, otherwise defaulting to `dev`.

## Example Usage

```hcl
variable "role_ids" {
  description = "Map of role logical names to Spacelift Role IDs. Used to consume output from dependent Spacelift stack"
  type        = map(string)
}

locals {
  nonprod_reader_role     = var.role_ids["nonprod_reader"]
  prod_reader_role        = var.role_ids["prod_reader"]
  nonprod_maintainer_role = var.role_ids["nonprod_maintainer"]
  prod_maintainer_role    = var.role_ids["prod_maintainer"]
}

module "team_space" {
  source = "./modules/spacelift-spaces"

  team_name        = "CCOE"
  team_description = "Cloud Center of Excellence Team space"
  
  okta_groups = [
    "Spacelift_K8s_CCOE_M_P",
    "Spacelift_K8s_CCOE_M_T",
    "Spacelift_K8s_CCOE_RO_P",
    "Spacelift_K8s_CCOE_RO_T"
  ]

  nonprod_reader_role     = local.nonprod_reader_role
  prod_reader_role        = local.prod_reader_role
  nonprod_maintainer_role = local.nonprod_maintainer_role
  prod_maintainer_role    = local.prod_maintainer_role

  apps = {
    "K8s" = {
      description = "K8s App Space"
      
      environments = {
        "test" = {
          description = "K8s Test Environment Space"
        }
        "prod" = {
          description = "K8s Prod Environment Space"
        }
      }
    }
  }
}
```
