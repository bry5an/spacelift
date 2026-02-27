output "team_space_id" {
  description = "The Spacelift Space ID of the team."
  value       = spacelift_space.team.id
}

output "app_space_ids" {
  description = "A map of app names pointing to their Spacelift Space ID."
  value       = { for k, v in spacelift_space.app : k => v.id }
}

output "environment_space_ids" {
  description = "A map of <app>-<env> names pointing to their Spacelift Space ID."
  value       = { for k, v in spacelift_space.environment : k => v.id }
}

output "idp_group_mappings" {
  description = "A map of created Okta IdP Group names to their respective Spacelift mapping IDs."
  value       = { for k, v in spacelift_idp_group_mapping.mapping : k => v.id }
}
