data "aws_partition" "current" {}

data "aws_ssm_parameter" "lock_table_arn" {
  name = "arn:aws:dynamodb:us-east-1:244158944772:table/terraform-state-cf-cd-cicd-z9xl1n"
}
