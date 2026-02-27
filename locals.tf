locals {
  # ----------------------------------------------------------------------------
  # Space Hierarchy Flattenening
  # ----------------------------------------------------------------------------

  # Flatten Apps
  apps = {
    for app_name, app_config in var.apps : app_name => {
      name        = app_name
      description = app_config.description
    }
  }

  # Flatten Environments
  environments = merge([
    for app_name, app_config in var.apps : {
      for env_name, env_config in coalesce(app_config.environments, {}) : "${app_name}-${env_name}" => {
        app_name    = app_name
        name        = env_name
        description = env_config.description
        is_prod     = env_name == "prod"
      }
    }
  ]...)

  # ----------------------------------------------------------------------------
  # Okta Group Parsing
  # ----------------------------------------------------------------------------

  # Collect all specified Okta groups globally for `spacelift_idp_group_mapping`
  all_okta_groups = var.okta_groups

  # Parse Okta groups
  # Expected format: Spacelift_<app>_<team>_<permission_level>_<env>
  # Examples: Spacelift_K8s_CCOE_M_P, Spacelift_K8s_CCOE_RO_T
  parsed_groups = [
    for group in var.okta_groups : {
      group  = group
      parsed = regex("(?i)^Spacelift_([^_]+)_([^_]+)_(RO|M)_(P|T)$", group)
    }
  ]

  # Process parsed groups into role mapping objects
  all_role_mappings = [
    for metadata in local.parsed_groups : {
      key             = "mapping-${metadata.group}"
      space_key       = "${metadata.parsed[0]}-${metadata.parsed[3] == "P" ? "prod" : (metadata.parsed[3] == "T" ? "test" : "dev")}" # app_name - env_name
      okta_group_name = metadata.group
      role_name       = metadata.parsed[2] == "M" ? "maintainer" : "reader"
      is_prod         = metadata.parsed[3] == "P"
      space_type      = "env" # Always assigns to the specific environment space based on naming convention
    }
  ]

  prod_roles = {
    "reader"     = var.prod_reader_role
    "maintainer" = var.prod_maintainer_role
  }

  nonprod_roles = {
    "reader"     = var.nonprod_reader_role
    "maintainer" = var.nonprod_maintainer_role
  }
}
