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

terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.20.1"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

### Module for CodePipeline Infrastructure
module "pipeline" {
  source                   = "./modules/pipeline"
  pRepositoryName          = var.pRepositoryName
  pPipelineName            = var.pPipelineName
  pCloudFormationStackName = var.pCloudFormationStackName
  pCloudFormationFileName  = var.pCloudFormationFileName
  pProductionCloudFrontID  = var.pProductionCloudFrontID
  pApprovalEmail           = var.pApprovalEmail
}

### Module for Infrastructure Validate, Plan, Apply and Destroy - CodePipeline
# module "cloudfront_continuous_deployment_connection" {
#   source = "./modules/cloudfront_continuous_deployment_connection"
# }
