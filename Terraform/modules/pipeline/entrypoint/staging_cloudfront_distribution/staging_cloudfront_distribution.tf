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

resource "aws_cloudfront_continuous_deployment_policy" "cf_continuous_deployment_policy" {
  enabled = true

  staging_distribution_dns_names {
    items    = [aws_cloudfront_distribution.cf_distribution.domain_name]
    quantity = 1
  }

  traffic_config {
    single_weight_config {
      weight = 0.1
    }
    type = "SingleWeight"
  }
}


resource "aws_cloudfront_distribution" "cf_distribution" {
  enabled             = true
  is_ipv6_enabled     = true
  http_version        = "http2"
  comment             = "Staging CloudFront Distribution"
  default_root_object = "index.html"

  logging_config {
    bucket          = "cloudfront-continuous-deployment-bucket-accesslogging.s3.amazonaws.com"
    include_cookies = false
    prefix          = "cf-distribution-logs"
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "CloudFront-Staging-Distribution"
    viewer_protocol_policy = "https-only"
    min_ttl                = 0
    default_ttl            = 300
    max_ttl                = 1200
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"
  }

  origin {
    domain_name              = "cloudfront-continuous-deployment-bucket-2.s3.us-east-1.amazonaws.com"
    origin_id                = "CloudFront-Staging-Distribution"
    origin_access_control_id = "E2WCWCC6CA2Q9D"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = ["none"]
    }
  }
}

output "staging_cf_distribution_id" {
  description = "Domain Name of the CloudFront Distribution"
  value       = aws_cloudfront_distribution.cf_distribution.id
}

output "cf_distribution_deployment_policy_id" {
  description = "Domain Name of the Continuous Deployment ID"
  value       = aws_cloudfront_continuous_deployment_policy.cf_continuous_deployment_policy.id
}