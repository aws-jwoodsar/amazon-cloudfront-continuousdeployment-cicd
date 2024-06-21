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

import sys
from pip._internal import main
main(['install', '-I', '-q', 'boto3', '--target', '/tmp/', '--no-cache-dir', '--disable-pip-version-check'])
sys.path.insert(0,'/tmp/')
import boto3
import os
import json
import cfnresponse

production_distribution = os.environ['CLOUDFRONT_PRODUCTION_ID']
continuous_deployment_id = os.environ['CLOUDFRONT_CONTINUOUS_DEPLOYMENT_ID']
cloudfront_client = boto3.client('cloudfront')

def lambda_handler(event, context):
    print(boto3.__version__)
    if 'RequestType' in event and 'Delete' in event['RequestType']:
        cfnresponse.send(event, context, cfnresponse.SUCCESS, {}, '')
    elif (event['RequestType'] == 'Create') or (event['RequestType'] == 'Update'):
        try:
            distribution_config_response = cloudfront_client.get_distribution_config(Id=production_distribution)
            distribution_config = distribution_config_response['DistributionConfig']
            distribution_config['ContinuousDeploymentPolicyId'] = continuous_deployment_id
            print(distribution_config)
            distribution_etag = distribution_config_response['ETag']
            cloudfront_client.update_distribution(DistributionConfig=distribution_config, Id=production_distribution, IfMatch=distribution_etag)
            cfnresponse.send(event, context, cfnresponse.SUCCESS, {}, '')
        except Exception as e:
            print(e)
            cfnresponse.send(event, context, cfnresponse.FAILED, {}, '')