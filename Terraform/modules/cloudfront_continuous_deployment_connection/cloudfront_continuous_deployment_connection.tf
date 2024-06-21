# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this
# software and associated documentation files (the "Software"), to deal in the Software
# without restriction, including without limitation the rights to use, copy, modify,
# merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
# PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# IAM Role for the Lambda function
resource "aws_iam_role" "cf_cd_connection_lambda_role" {
  name = "cloudfront-continuous-deployment-role-${substr(data.aws_partition.current.partition, 0, 1)}"

  assume_role_policy = <<-POLICY
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "lambda.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  }
  POLICY

  managed_policy_arns = [
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/CloudFrontFullAccess"
  ]

  tags = {
    Name = "cloudfront-continuous-deployment-role-${substr(data.aws_partition.current.partition, 0, 1)}"
  }
}

data "archive_file" "cf_cd_connection_lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda_function/index.py"
  output_path = "${path.module}/lambda_function.zip"
}

# Lambda function
resource "aws_lambda_function" "cf_cd_connection_lambda" {
  function_name                  = "cloudfront-continuous-deployment-function-${substr(data.aws_partition.current.partition, 0, 1)}"
  role                           = aws_iam_role.cf_cd_connection_lambda_role.arn
  handler                        = "index.lambda_handler"
  memory_size                    = 128
  runtime                        = "python3.10"
  timeout                        = 900
  architectures                  = ["arm64"]
  reserved_concurrent_executions = 5

  source_code_hash = filebase64sha256("lambda_function/index.py")

  environment {
    variables = {
      CLOUDFRONT_PRODUCTION_ID            = data.aws_cloudfront_distribution.production.id
      CLOUDFRONT_CONTINUOUS_DEPLOYMENT_ID = data.aws_cloudfront_continuous_deployment_policy.continuous_deployment.id
    }
  }

  tags = {
    Name = "cloudfront-continuous-deployment-function-${substr(data.aws_partition.current.partition, 0, 1)}"
  }
}

# Custom resource to link the Production Distribution to the Continuous Deployment policy
resource "aws_cloudformation_stack" "cf_cd_connection" {
  name = "cf-cd-connection"

  parameters = {
    ServiceToken = aws_lambda_function.cf_cd_connection_lambda.arn
  }

  template_body = <<-EOF
  {
    "Resources": {
      "rCFCDConnectionCustom": {
        "Type": "Custom::rCFCDConnectionLambda",
        "Properties": {
          "ServiceToken": "${aws_lambda_function.cf_cd_connection_lambda.arn}"
        }
      }
    }
  }
  EOF
}