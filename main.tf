locals {
  # ----------------------------------------------------------------------------
  # Space Hierarchy Flattenening
  # ----------------------------------------------------------------------------

  # Flatten Teams
  teams = merge([
    for team_name, team_config in var.teams : {
      (team_name) = {
        name        = team_name
        description = team_config.description
      }
    }
  ]...)

  # Flatten Apps
  apps = merge([
    for team_name, team_config in var.teams : {
      for app_name, app_config in coalesce(team_config.apps, {}) : "${team_name}-${app_name}" => {
        team_name   = team_name
        name        = app_name
        description = app_config.description
      }
    }
  ]...)

  # Flatten Environments
  environments = merge([
    for team_name, team_config in var.teams : merge([
      for app_name, app_config in coalesce(team_config.apps, {}) : {
        for env_name, env_config in coalesce(app_config.environments, {}) : "${team_name}-${app_name}-${env_name}" => {
          team_name   = team_name
          app_name    = app_name
          name        = env_name
          description = env_config.description
          is_prod     = env_config.is_prod
        }
      }
    ]...)
  ]...)

  # ----------------------------------------------------------------------------
  # Role Mapping Flattenening
  # ----------------------------------------------------------------------------

  # Collect all specified Okta groups globally for `spacelift_idp_group_mapping`
  all_okta_groups = distinct(compact(flatten([
    for team_config in values(var.teams) : [
      concat(
        coalesce([for r in coalesce(team_config.role_mappings, []) : r.okta_group_name], []),
        flatten([
          for app_config in values(coalesce(team_config.apps, {})) : concat(
            coalesce([for r in coalesce(app_config.role_mappings, []) : r.okta_group_name], []),
            flatten([
              for env_config in values(coalesce(app_config.environments, {})) : coalesce([for r in coalesce(env_config.role_mappings, []) : r.okta_group_name], [])
            ])
          )
        ])
      )
    ]
  ])))

  # Flatten Team level role mappings
  team_role_mappings = flatten([
    for team_name, team_config in var.teams : [
      for role_mapping in coalesce(team_config.role_mappings, []) : {
        key             = "team-${team_name}-${role_mapping.okta_group_name}-${role_mapping.role_name}"
        space_key       = team_name
        okta_group_name = role_mapping.okta_group_name
        role_name       = role_mapping.role_name
        is_prod         = false
        space_type      = "team"
      }
    ]
  ])

  # Flatten App level role mappings
  app_role_mappings = flatten([
    for team_name, team_config in var.teams : [
      for app_name, app_config in coalesce(team_config.apps, {}) : [
        for role_mapping in coalesce(app_config.role_mappings, []) : {
          key             = "app-${team_name}-${app_name}-${role_mapping.okta_group_name}-${role_mapping.role_name}"
          space_key       = "${team_name}-${app_name}"
          okta_group_name = role_mapping.okta_group_name
          role_name       = role_mapping.role_name
          is_prod         = false
          space_type      = "app"
        }
      ]
    ]
  ])

  # Flatten Environment level role mappings
  env_role_mappings = flatten([
    for team_name, team_config in var.teams : [
      for app_name, app_config in coalesce(team_config.apps, {}) : [
        for env_name, env_config in coalesce(app_config.environments, {}) : [
          for role_mapping in coalesce(env_config.role_mappings, []) : {
            key             = "env-${team_name}-${app_name}-${env_name}-${role_mapping.okta_group_name}-${role_mapping.role_name}"
            space_key       = "${team_name}-${app_name}-${env_name}"
            okta_group_name = role_mapping.okta_group_name
            role_name       = role_mapping.role_name
            is_prod         = coalesce(env_config.is_prod, false)
            space_type      = "env"
          }
        ]
      ]
    ]
  ])

  all_role_mappings = concat(local.team_role_mappings, local.app_role_mappings, local.env_role_mappings)
}

# ------------------------------------------------------------------------------
# Create Spaces
# ------------------------------------------------------------------------------

resource "spacelift_space" "team" {
  for_each = local.teams

  name            = each.value.name
  description     = each.value.description
  parent_space_id = var.root_space_id
}

resource "spacelift_space" "app" {
  for_each = local.apps

  name            = each.value.name
  description     = each.value.description
  parent_space_id = spacelift_space.team[each.value.team_name].id
}

resource "spacelift_space" "environment" {
  for_each = local.environments

  name            = each.value.name
  description     = each.value.description
  parent_space_id = spacelift_space.app["${each.value.team_name}-${each.value.app_name}"].id
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

  space_id             = each.value.space_type == "team" ? spacelift_space.team[each.value.space_key].id : (each.value.space_type == "app" ? spacelift_space.app[each.value.space_key].id : spacelift_space.environment[each.value.space_key].id)
  idp_group_mapping_id = spacelift_idp_group_mapping.mapping[each.value.okta_group_name].id
  role_id              = each.value.is_prod ? var.role_definitions[each.value.role_name].prod_role_id : var.role_definitions[each.value.role_name].non_prod_role_id
}
