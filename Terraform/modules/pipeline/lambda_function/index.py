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
import json
import logging
import os

def lambda_handler(event, context):
    print(event)
    logger = logging.getLogger()
    logger.setLevel(logging.INFO)
    logger.debug(json.dumps(event))

    cf = boto3.client('cloudfront')
    codepipeline = boto3.client('codepipeline')
    job_id = event['CodePipeline.job']['id']

    STAGING_DISTRIBUTION = event['CodePipeline.job']['data']['actionConfiguration']['configuration']['UserParameters']
    PRD_DISTRIBUTION = os.environ['PRD_DISTRIBUTION_ID']

    try:
        logger.info('Example')
        
        # Grabbing ETags from Production
        PRD_ETag = cf.get_distribution(Id=PRD_DISTRIBUTION)['ETag']

        # Grabbing ETags from Staging
        STAGING_ETag = cf.get_distribution(Id=STAGING_DISTRIBUTION)['ETag']

        # Promoting Staging distribution to Production
        cf.update_distribution_with_staging_config(Id=PRD_DISTRIBUTION, StagingDistributionId=STAGING_DISTRIBUTION, IfMatch=f'{PRD_ETag}, {STAGING_ETag}')

        response = codepipeline.put_job_success_result(jobId=job_id)
        logger.debug(response)
    
    except Exception as error:
        logger.exception(error)
        response = codepipeline.put_job_failure_result(
            jobId=job_id,
            failureDetails={
            'type': 'JobFailed',
            'message': f'{error.__class__.__name__}: {str(error)}'
            }
        )
        logger.debug(response)