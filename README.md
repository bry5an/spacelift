# Spacelift Spaces hierarchical Okta mapped Terraform Module

This module streamlines creating team, application, and environment-level Spacelift spaces, according to the Spacelift best-practices topology. It also intelligently resolves Okta identity groups to custom Role ID's, switching automatically between production and non-production roles depending on the given space type.

## Purpose

Suppose you have:
1.  A pre-existing Spacelift root Space ID.
2.  Custom Roles already created in Spacelift (e.g. an "Admin" role for Production, and an "Admin" role for Non-Production).
3.  Okta groups synced to your Identity Provider.

You can declare a single `teams` map describing your organizational layout. This module unfolds the nested dictionary into `spacelift_space`, `spacelift_idp_group_mapping`, and recursive `spacelift_role_attachment` resources. By setting `is_prod = true` deeply inline inside environment spaces, the correct permissions cascade naturally without having to specify verbose rules for every namespace.

## Example Usage

```hcl
module "spaces" {
  source = "./modules/spacelift-spaces"

  root_space_id = "root" # Your root space ID

  role_definitions = {
    "admin" = {
      non_prod_role_id = "rol_admin_nonprod_1234"
      prod_role_id     = "rol_admin_prod_1234"
    }
    "reader" = {
      non_prod_role_id = "rol_reader_nonprod_5678"
      prod_role_id     = "rol_reader_prod_5678"
    }
  }

  teams = {
    "platform" = {
      description = "Platform Engineering Team space"
      role_mappings = [
        {
          okta_group_name = "okta-platform-admins"
          role_name       = "admin" # Attaches non-prod role by default at the team tier
        }
      ]

      apps = {
        "kubernetes" = {
          description = "K8s App Space"
          
          environments = {
            "dev" = {
              description = "K8s Dev Environment Space"
              is_prod     = false # Attaches non-prod roles
              role_mappings = [
                {
                  okta_group_name = "okta-platform-devs"
                  role_name       = "admin" # Attaches `non_prod_role_id`
                }
              ]
            }
            "prod" = {
              description = "K8s Prod Environment Space"
              is_prod     = true # IMPORTANT: This flags the logic to switch to `prod_role_id`
              role_mappings = [
                {
                  okta_group_name = "okta-platform-devs"
                  role_name       = "reader" # Developers get the `prod_role_id` reader permissions
                },
                {
                  okta_group_name = "okta-platform-admins"
                  role_name       = "admin" # Admins get the `prod_role_id` admin permissions
                }
              ]
            }
          }
        }
      }
    }
  }
}
```
