variable "team_name" {
  description = "The name of the team."
  type        = string
}

variable "team_description" {
  description = "Description of the team space."
  type        = string
  default     = "Managed by Terraform"
}

variable "team_role_mappings" {
  description = "Role mappings for the team space."
  type = list(object({
    okta_group_name = string
    role_name       = string
  }))
  default = []
}

variable "apps" {
  description = "A structured map defining the hierarchy of applications and environments for the team."
  type = map(object({
    description = optional(string, "Managed by Terraform")
    role_mappings = optional(list(object({
      okta_group_name = string
      role_name       = string
    })), [])
    environments = optional(map(object({
      description = optional(string, "Managed by Terraform")
      role_mappings = optional(list(object({
        okta_group_name = string
        role_name       = string
      })), [])
    })), {})
  }))
  default = {}

  validation {
    condition = alltrue(flatten([
      for app_name, app_config in var.apps : [
        for env_name, env_config in coalesce(app_config.environments, {}) : contains(["dev", "prod"], env_name)
      ]
    ]))
    error_message = "Environment names must be either 'dev' or 'prod'."
  }
}

variable "role_ids" {
  description = "Map of role logical names to Spacelift Role IDs. Expected keys: nonprod_reader, prod_reader, nonprod_maintainer, prod_maintainer."
  type        = map(string)
}
