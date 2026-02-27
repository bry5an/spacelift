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
  # Role Mapping Flattenening
  # ----------------------------------------------------------------------------

  # Collect all specified Okta groups globally for `spacelift_idp_group_mapping`
  all_okta_groups = distinct(compact(flatten([
    coalesce([for r in var.team_role_mappings : r.okta_group_name], []),
    flatten([
      for app_config in values(var.apps) : concat(
        coalesce([for r in coalesce(app_config.role_mappings, []) : r.okta_group_name], []),
        flatten([
          for env_config in values(coalesce(app_config.environments, {})) : coalesce([for r in coalesce(env_config.role_mappings, []) : r.okta_group_name], [])
        ])
      )
    ])
  ])))

  # Flatten Team level role mappings
  team_role_mappings = [
    for role_mapping in var.team_role_mappings : {
      key             = "team-${var.team_name}-${role_mapping.okta_group_name}-${role_mapping.role_name}"
      space_key       = var.team_name
      okta_group_name = role_mapping.okta_group_name
      role_name       = role_mapping.role_name
      is_prod         = false
      space_type      = "team"
    }
  ]

  # Flatten App level role mappings
  app_role_mappings = flatten([
    for app_name, app_config in var.apps : [
      for role_mapping in coalesce(app_config.role_mappings, []) : {
        key             = "app-${var.team_name}-${app_name}-${role_mapping.okta_group_name}-${role_mapping.role_name}"
        space_key       = app_name
        okta_group_name = role_mapping.okta_group_name
        role_name       = role_mapping.role_name
        is_prod         = false
        space_type      = "app"
      }
    ]
  ])

  # Flatten Environment level role mappings
  env_role_mappings = flatten([
    for app_name, app_config in var.apps : [
      for env_name, env_config in coalesce(app_config.environments, {}) : [
        for role_mapping in coalesce(env_config.role_mappings, []) : {
          key             = "env-${var.team_name}-${app_name}-${env_name}-${role_mapping.okta_group_name}-${role_mapping.role_name}"
          space_key       = "${app_name}-${env_name}"
          okta_group_name = role_mapping.okta_group_name
          role_name       = role_mapping.role_name
          is_prod         = env_name == "prod"
          space_type      = "env"
        }
      ]
    ]
  ])

  all_role_mappings = concat(local.team_role_mappings, local.app_role_mappings, local.env_role_mappings)

  prod_roles = {
    "reader"     = var.role_ids["prod_reader"]
    "maintainer" = var.role_ids["prod_maintainer"]
  }

  nonprod_roles = {
    "reader"     = var.role_ids["nonprod_reader"]
    "maintainer" = var.role_ids["nonprod_maintainer"]
  }
}

# ------------------------------------------------------------------------------
# Create Spaces
# ------------------------------------------------------------------------------

resource "spacelift_space" "team" {
  name        = var.team_name
  description = var.team_description
}

resource "spacelift_space" "app" {
  for_each = local.apps

  name            = each.value.name
  description     = each.value.description
  parent_space_id = spacelift_space.team.id
}

resource "spacelift_space" "environment" {
  for_each = local.environments

  name            = each.value.name
  description     = each.value.description
  parent_space_id = spacelift_space.app[each.value.app_name].id
}

# ------------------------------------------------------------------------------
# Create Okta Group Mappings (Unique List)
# ------------------------------------------------------------------------------

resource "spacelift_idp_group_mapping" "mapping" {
  for_each = toset(local.all_okta_groups)

  name = each.value
}

# ------------------------------------------------------------------------------
# Create Role Attachments
# ------------------------------------------------------------------------------

resource "spacelift_role_attachment" "role_assignment" {
  for_each = { for mapping in local.all_role_mappings : mapping.key => mapping }

  space_id             = each.value.space_type == "team" ? spacelift_space.team.id : (each.value.space_type == "app" ? spacelift_space.app[each.value.space_key].id : spacelift_space.environment[each.value.space_key].id)
  idp_group_mapping_id = spacelift_idp_group_mapping.mapping[each.value.okta_group_name].id
  role_id              = each.value.is_prod ? local.prod_roles[each.value.role_name] : local.nonprod_roles[each.value.role_name]
}
