module "cloudwatch_retention_policy" {
    source = "../modules/cloudwatch-retention-policy"
    retention_days = 8
}