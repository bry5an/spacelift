variable "root_space_id" {
  description = "The ID of the root Spacelift space under which the team spaces will be created."
  type        = string
}

variable "role_definitions" {
  description = "A mapping of logical role names (e.g., 'admin', 'reader') to their respective non-production and production Spacelift Custom Role IDs."
  type = map(object({
    non_prod_role_id = string
    prod_role_id     = string
  }))
  default = {}
}

variable "teams" {
  description = "A structured map defining the hierarchy of teams, their applications, and environments."
  type = map(object({
    description = optional(string, "Managed by Terraform")
    role_mappings = optional(list(object({
      okta_group_name = string
      role_name       = string
    })), [])
    apps = optional(map(object({
      description = optional(string, "Managed by Terraform")
      role_mappings = optional(list(object({
        okta_group_name = string
        role_name       = string
      })), [])
      environments = optional(map(object({
        description = optional(string, "Managed by Terraform")
        is_prod     = optional(bool, false)
        role_mappings = optional(list(object({
          okta_group_name = string
          role_name       = string
        })), [])
      })), {})
    })), {})
  }))
  default = {}
}
