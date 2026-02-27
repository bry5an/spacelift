variable "team_name" {
  description = "The name of the team."
  type        = string
}

variable "team_description" {
  description = "Description of the team space."
  type        = string
  default     = "Managed by Terraform"
}

variable "okta_groups" {
  description = "List of Okta groups following the standard naming convention: Spacelift_<app>_<team>_<permission_level>_<env>"
  type        = list(string)
  default     = []
}

variable "apps" {
  description = "A structured map defining the hierarchy of applications and environments for the team."
  type = map(object({
    description = optional(string, "Managed by Terraform")
    environments = optional(map(object({
      description = optional(string, "Managed by Terraform")
    })), {})
  }))
  default = {}

  validation {
    condition = alltrue(flatten([
      for app_name, app_config in var.apps : [
        for env_name, env_config in coalesce(app_config.environments, {}) : contains(["dev", "test", "prod"], env_name)
      ]
    ]))
    error_message = "Environment names must be either 'dev', 'test', or 'prod'."
  }
}

variable "nonprod_reader_role" {
  description = "Spacelift Role ID for Non-Prod Reader."
  type        = string
}

variable "prod_reader_role" {
  description = "Spacelift Role ID for Prod Reader."
  type        = string
}

variable "nonprod_maintainer_role" {
  description = "Spacelift Role ID for Non-Prod Maintainer."
  type        = string
}

variable "prod_maintainer_role" {
  description = "Spacelift Role ID for Prod Maintainer."
  type        = string
}
