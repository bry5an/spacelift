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
      for env_name, is_enabled in coalesce(app_config.environments, {}) : "${app_name}-${env_name}" => {
        app_name    = app_name
        name        = env_name
        description = "${var.team_name} ${app_name} ${env_name} space"
        is_prod     = env_name == "prod"
      } if is_enabled
    }
  ]...)

  # ----------------------------------------------------------------------------
  # Okta Group Parsing
  # ----------------------------------------------------------------------------

  # Collect all specified Okta groups globally for `spacelift_idp_group_mapping`
  all_okta_groups = var.okta_groups

  # Parse Okta groups
  # Expected format: SLPOC_<app>_<team>_<permission_level>_<env>
  # Examples: SLPOC_K8s_CCOE_M_P, SLPOC_K8s_CCOE_RO_T
  parsed_groups = [
    for group in var.okta_groups : {
      group  = group
      parsed = regex("(?i)^SLPOC_([^_]+)_([^_]+)_(RO|M)_(P|T)$", group)
    }
  ]

  # Process parsed groups into role mapping objects
  all_role_mappings = [
    for metadata in local.parsed_groups : {
      key             = "mapping-${metadata.group}"
      space_key       = "${metadata.parsed[0]}-${metadata.parsed[3] == "P" ? "prod" : "nonprod"}" # <app>-<env> mapping format
      okta_group_name = metadata.group
      role_name       = metadata.parsed[2] == "M" ? "maintainer" : "reader"
      is_prod         = metadata.parsed[3] == "P"
      space_type      = "env" # Always assigns to the specific environment space based on naming convention
    }
    if contains([for k in keys(local.environments) : lower(k)], lower("${metadata.parsed[0]}-${metadata.parsed[3] == "P" ? "prod" : "nonprod"}"))
  ]

  prod_roles = {
    "reader"     = var.prod_reader_role
    "maintainer" = var.prod_maintainer_role
  }

  nonprod_roles = {
    "reader"     = var.nonprod_reader_role
    "maintainer" = var.nonprod_maintainer_role
  }

  # Build a lookup map for case-insensitive space key resolution
  env_key_lookup = { for k in keys(local.environments) : lower(k) => k }
}

# Build a map of group -> list of policy blocks
locals {
  idp_group_policies = {
    for group in toset(local.all_okta_groups) : group => [
      for mapping in local.all_role_mappings : {
        space_id = spacelift_space.environment[local.env_key_lookup[lower(mapping.space_key)]].id
        role_id  = mapping.is_prod ? local.prod_roles[mapping.role_name] : local.nonprod_roles[mapping.role_name]
      }
      if mapping.okta_group_name == group
    ]
  }
}
