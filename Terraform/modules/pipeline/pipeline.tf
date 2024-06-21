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

# S3 Bucket for CodePipeline Artifacts
resource "aws_s3_bucket" "artifact_store_bucket" {
  force_destroy = true
}

resource "aws_s3_bucket_logging" "artifact_store_bucket" {
  bucket = aws_s3_bucket.artifact_store_bucket.id

  target_bucket = aws_s3_bucket.artifact_store_bucket.id
  target_prefix = "codepipeline-artifact-accesslogs"
}

resource "aws_s3_bucket_lifecycle_configuration" "artifact_store_bucket" {
  bucket = aws_s3_bucket.artifact_store_bucket.id

  rule {
    status = "Enabled"
    id     = "Glacier-Rule"

    transition {
      days          = 60
      storage_class = "GLACIER"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifact_store_bucket" {
  bucket = aws_s3_bucket.artifact_store_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_versioning" "artifact_store_bucket" {
  bucket = aws_s3_bucket.artifact_store_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "artifact_store_bucket_access_block" {
  bucket = aws_s3_bucket.artifact_store_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "artifact_store_bucket_policy" {
  bucket = aws_s3_bucket.artifact_store_bucket.id

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyUnEncryptedObjectUploads",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::${aws_s3_bucket.artifact_store_bucket.id}/*",
      "Condition": {
        "StringNotEquals": {
          "s3:x-amz-server-side-encryption": "aws:kms"
        }
      }
    },
    {
      "Sid": "DenyInsecureConnections",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": "arn:aws:s3:::${aws_s3_bucket.artifact_store_bucket.id}/*",
      "Condition": {
        "Bool": {
          "aws:SecureTransport": "false"
        }
      }
    }
  ]
}
POLICY
}

# CodeCommit Repository
resource "aws_codecommit_repository" "cloudfront_repo" {
  repository_name = "CloudFront-ContinuousDeployment-Repository"
  description     = "Repository for CloudFront Continuous Deployment"
}

# CodePipeline
resource "aws_codepipeline" "cloudfront_pipeline" {
  name     = "CloudFront-ContinuousDeployment-Pipeline"
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    location = aws_s3_bucket.artifact_store_bucket.id
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      input_artifacts  = []
      output_artifacts = ["source_artifact_output"]
      version          = "1"
      configuration = {
        RepositoryName       = aws_codecommit_repository.cloudfront_repo.repository_name
        BranchName           = "main"
        PollForSourceChanges = "false"
      }
    }
  }

  stage {
    name = "Plan"

    action {
      name             = "Terraform-Plan"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_artifact_output"]
      output_artifacts = ["terraform_plan_file"]
      version          = "1"

      configuration = {
        ProjectName          = aws_codebuild_project.terraform_plan.name
        EnvironmentVariables = jsonencode([
          {
            name  = "PIPELINE_EXECUTION_ID"
            value = "#{codepipeline.PipelineExecutionId}"
            type  = "PLAINTEXT"
          }
        ])
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name             = "Terraform-Apply"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_artifact_output", "terraform_plan_file"]
      output_artifacts = ["terraform_deploy"]
      version          = "1"
      namespace = "terraform_outputs"

      configuration = {
        ProjectName          = aws_codebuild_project.terraform_apply.name
        PrimarySource        = "CodeWorkspace"
        EnvironmentVariables = jsonencode([
          {
            name  = "PIPELINE_EXECUTION_ID"
            value = "#{codepipeline.PipelineExecutionId}"
            type  = "PLAINTEXT"
          }
        ])
      }
    }
  }

  stage {
    name = "ManualApproval"

    action {
      name             = "ManualApproval"
      category         = "Approval"
      owner            = "AWS"
      provider         = "Manual"
      input_artifacts  = []
      output_artifacts = []
      version          = "1"
      configuration = {
        NotificationArn = aws_sns_topic.approval_topic.arn
        CustomData      = "A new staging distribution was created for the Production ${var.pProductionCloudFrontID} CloudFormation distribution. Do you want to implement the changes?"
      }
    }
  }

  stage {
    name = "Promotion"

    action {
      name             = "Promote_to_Production"
      category         = "Invoke"
      owner            = "AWS"
      provider         = "Lambda"
      input_artifacts  = ["terraform_deploy"]
      output_artifacts = []
      version          = "1"
      configuration = {
        FunctionName   = aws_lambda_function.promote_lambda.function_name
        UserParameters = "#{terraform_outputs.production_cloudfront_distribution}" ### Need a way to grab the OUTPUT from the Terraform deploy to pass into the Promote Lambda here
      }
    }
  }
}

# CodeBuild Projects
resource "aws_codebuild_project" "terraform_plan" {
  name         = "CloudFront-ContinuousDeployment-Terraform-Plan"
  service_role = aws_iam_role.codebuild.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = var.codebuild_configuration["cb_compute_type"]
    image        = var.codebuild_configuration["cb_image"]
    type         = var.codebuild_configuration["cb_type"]
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec-plan.yml" 
  }
}

resource "aws_codebuild_project" "terraform_apply" {
  name         = "CloudFront-ContinuousDeployment-Terraform-Apply"
  service_role = aws_iam_role.codebuild.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = var.codebuild_configuration["cb_compute_type"]
    image        = var.codebuild_configuration["cb_image"]
    type         = var.codebuild_configuration["cb_type"]
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec-apply.yml" 
  }
}

# IAM Roles
resource "aws_iam_role" "codepipeline" {
  name        = "CloudFront-ContinuousDeployment-CodePipeline-Provision-Role"

  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Principal" : {
            "Service" : "codepipeline.amazonaws.com"
          },
          "Action" : "sts:AssumeRole"
        }
      ]
    }
  )

  inline_policy {
    name = "codepipelinepolicy"
    policy = data.aws_iam_policy_document.codepipeline.json
  }
}

data "aws_iam_policy_document" "codepipeline" {
  statement {
    sid = "CodePipelineAllow"

    actions = [
      "s3:*", ### Will have to narrow down...I assume
    ]

    resources = [
      "*", ### Will have to narrow down...I assume
    ]
  }

  statement {
    actions = [
      "iam:PassRole",
    ]

    resources = [
      aws_iam_role.codebuild.arn,
    ]
  }

  statement {
    actions = [
      "codecommit:BatchGet*",
      "codecommit:BatchDescribe*",
      "codecommit:Describe*",
      "codecommit:Get*",
      "codecommit:List*",
      "codecommit:GitPull",
      "codecommit:UploadArchive",
      "codecommit:GetBranch",
    ]

    resources = [
      "*", ### Will have to narrow down...I assume
    ]
  }

  statement {
    actions = [
      "codebuild:StartBuild",
      "codebuild:StopBuild",
      "codebuild:BatchGetBuilds",
    ]

    resources = [
      aws_codebuild_project.terraform_apply.arn,
      aws_codebuild_project.terraform_plan.arn,
    ]
  }
}

resource "aws_iam_role" "codebuild" {
  name        = "CloudFront-ContinuousDeployment-CodeBuild-Service-Role"

  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Principal" : {
            "Service" : "codebuild.amazonaws.com"
          },
          "Action" : "sts:AssumeRole"
        }
      ]
    }
  )

  inline_policy {
    name = "codebuild_execute_policy"
    policy = data.aws_iam_policy_document.codebuild.json
  }
}

data "aws_iam_policy_document" "codebuild" {
  statement {
    sid = "SSOCodebuildAllow"

    actions = [
      "s3:*",
      "kms:*",
      "ssm:*",
    ]

    resources = [
      "*", ### Will have to narrow down...I assume
    ]
  }

  statement {
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
      "dynamodb:DescribeTable",
      "dynamodb:DescribeContinuousBackups",
      "dynamodb:DescribeTimeToLive",
      "dynamodb:ListTagsOfResource",
    ]

    resources = [
      data.aws_ssm_parameter.lock_table_arn.value,
    ]
  }

  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = [
      "*", 
    ]
  }

  statement {
    actions = [
      "sso:ListInstances",
      "sso:DescribePermissionSet",
      "sso:ListTagsForResource",
      "sso:GetInlinePolicyForPermissionSet",
      "sso:ListAccountAssignments",
      "sso:CreateAccountAssignment",
      "sso:DescribeAccountAssignmentCreationStatus",
      "sso:DeleteAccountAssignment",
      "sso:DescribeAccountAssignmentDeletionStatus",
      "sso:CreatePermissionSet",
      "sso:PutInlinePolicyToPermissionSet",
      "sso:ProvisionPermissionSet",
      "sso:DeleteInlinePolicyFromPermissionSet",
      "sso:DescribePermissionSetProvisioningStatus",
      "sso:DeletePermissionSet",
    ]

    resources = [
      "*", ### Will have to narrow down...I assume
    ]
  }

  statement {
    actions = [
      "identitystore:ListGroups",
    ]

    resources = [
      "*", ### Will have to narrow down...I assume
    ]
  }
}

data "aws_iam_policy_document" "lambda_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "promote_lambda_role" {
  name = "LambdaPromotionRole"

  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json

  managed_policy_arns = [
    "arn:aws:iam::${data.aws_partition.current.partition}:policy/service-role/AWSLambdaBasicExecutionRole",
    "arn:aws:iam::${data.aws_partition.current.partition}:policy/CloudFrontFullAccess"
  ]
}

data "aws_iam_policy_document" "promote_lambda_policy_document" {
  statement {
    sid = "1"

    actions = [
      "codepipeline:PutJobSuccessResult",
      "codepipeline:PutJobFailureResult",
    ]

    resources = [
      "*",
    ]
  }
}

resource "aws_iam_policy" "promote_lambda_policy" {
  name   = "CloudFront-ContinuousDeployment-PromoteLambdaPolicy"
  policy = data.aws_iam_policy_document.promote_lambda_policy_document.json
}

resource "aws_iam_policy_attachment" "promote_lambda_policy_attachment" {
  name       = "CloudFront-ContinuousDeployment-PromoteLambdaPolicyAttachment"
  policy_arn = aws_iam_policy.promote_lambda_policy.arn
  roles      = [aws_iam_role.promote_lambda_role.name]
}

# SNS Topic for Manual Approval
resource "aws_sns_topic" "approval_topic" {
  name              = "CloudFront-ContinuousDeployment-CloudFrontPromotionApprovalTopic"
  kms_master_key_id = "alias/aws/sns"
}

resource "aws_sns_topic_subscription" "approval_topic_subscription" {
  topic_arn = aws_sns_topic.approval_topic.arn
  protocol  = "email"
  endpoint  = var.pApprovalEmail
}

# Lambda Function for Promotion
resource "aws_lambda_function" "promote_lambda" {
  function_name                  = "cloudfront-continuous-deployment-function"
  filename      = "${path.module}/lambda_function/index.zip"
  role                           = aws_iam_role.promote_lambda_role.arn
  handler                        = "index.lambda_handler"
  runtime                        = "python3.9"
  memory_size                    = 128
  timeout                        = 60
  reserved_concurrent_executions = 5

  source_code_hash = filebase64sha256("${path.module}/lambda_function/index.py")

  environment {
    variables = {
      PRD_DISTRIBUTION_ID = var.pProductionCloudFrontID
    }
  }
}

data "archive_file" "promote_lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda_function/index.py"
  output_path = "${path.module}/code_zipped/index.zip"
}
