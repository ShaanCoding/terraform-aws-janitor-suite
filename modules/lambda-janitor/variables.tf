variable "versions_to_keep" {
  type    = number
  default = 3
  validation {
    condition     = var.versions_to_keep >= 0
    error_message = "The number of versions to keep must be a non-negative integer."
  }
  description = "How many versions to keep, even if they are not aliased."
}