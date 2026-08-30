variable "environment" {
  description = "Environment name. Selects environments/{environment}.yaml, which carries every other value."
  type        = string
  default     = "production"
}
