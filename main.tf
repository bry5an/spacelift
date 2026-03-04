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
# Create Okta Group -> Role & Space Mappings
# ------------------------------------------------------------------------------

resource "spacelift_idp_group_mapping" "mapping" {
  for_each = local.idp_group_policies

  name = each.key

  dynamic "policy" {
    for_each = each.value
    content {
      space_id = policy.value.space_id
      role     = policy.value.role_id
    }
  }
}
