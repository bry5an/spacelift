# Spacelift Spaces hierarchical Okta mapped Terraform Module

This module streamlines creating application and environment-level Spacelift spaces for a single team, according to the Spacelift best-practices topology. It also intelligently resolves Okta identity groups to custom Role IDs, switching automatically between production and non-production roles depending on the given space type. The team space defaults to the root space.

## Purpose

Suppose you have:
1.  Custom Roles already created in Spacelift (e.g. "reader" and "maintainer" roles for both Production and Non-Production).
2.  Okta groups synced to your Identity Provider.

You can declare a single `apps` map for a single team describing your organizational layout. This module unfolds the nested dictionary into `spacelift_space`, `spacelift_idp_group_mapping`, and recursive `spacelift_role_attachment` resources. By checking if the environment space name is `prod`, the correct permissions cascade naturally without having to specify verbose rules for every namespace. Environment names are restricted to `dev` or `prod`.

## Example Usage

```hcl
module "team_space" {
  source = "./modules/spacelift-spaces"

  team_name        = "platform"
  team_description = "Platform Engineering Team space"
  
  team_role_mappings = [
    {
      okta_group_name = "okta-platform-admins"
      role_name       = "maintainer" # Attaches non-prod role by default at the team tier
    }
  ]

  role_ids = {
    nonprod_reader     = "rol_reader_nonprod_1234"
    prod_reader        = "rol_reader_prod_1234"
    nonprod_maintainer = "rol_maintainer_nonprod_5678"
    prod_maintainer    = "rol_maintainer_prod_5678"
  }

  apps = {
    "kubernetes" = {
      description = "K8s App Space"
      
      environments = {
        "dev" = {
          description = "K8s Dev Environment Space"
          role_mappings = [
            {
              okta_group_name = "okta-platform-devs"
              role_name       = "maintainer" # Attaches `nonprod_maintainer`
            }
          ]
        }
        "prod" = {
          description = "K8s Prod Environment Space"
          role_mappings = [
            {
              okta_group_name = "okta-platform-devs"
              role_name       = "reader" # Developers get the `prod_reader` permissions
            },
            {
              okta_group_name = "okta-platform-admins"
              role_name       = "maintainer" # Admins get the `prod_maintainer` permissions
            }
          ]
        }
      }
    }
  }
}
```
