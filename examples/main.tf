module "cloudwatch_retention_policy" {
    source = "../modules/cloudwatch-retention-policy"
    retention_days = 7
}

module "lambda_janitor" {
    source = "../modules/lambda-janitor"
    versions_to_keep = 2
}