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

variable "pRepositoryName" {
  type        = string
  description = "Name of the repository for CloudFront Continuous Deployment Infrastructure Code"
  default     = "CloudFront-ContinuousDeployment"
}

variable "pPipelineName" {
  type        = string
  description = "A name for pipeline"
  default     = "CloudFront-ContinuousDeployment-Pipeline"
}

variable "pCloudFormationStackName" {
  type        = string
  description = "staging_cloudfront_distribution"
  default     = "Name of the Infrastructure Stack in the Development Account"
}

variable "pCloudFormationFileName" {
  type        = string
  description = "staging_cloudfront_distribution."
  default     = "The file name of the stack in Development"
}

variable "pProductionCloudFrontID" {
  type = string
}

variable "pApprovalEmail" {
  type = string
}