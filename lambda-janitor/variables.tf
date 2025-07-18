variable "retention_days" {
  type        = number
  default     = 7
  description = "The number of days to retain logs in CloudWatch. If not specified, the default retention policy will be applied."
}
