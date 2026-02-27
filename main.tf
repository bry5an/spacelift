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
