#!/usr/bin/env bash

# find-CF-stack-for-AWS-resource.sh
# Stefan Wuensch 2016-08-31
# 
# Usage: find-CF-stack-for-AWS-resource.sh "the name of an AWS resource"
# 
# Requires: The name ("Physical Resource ID") of an AWS resource
# 
# Output: The name of a CloudFormation Stack (if found) which created / manages that resource,
# or an AWS CLI error message which includes "Stack for {resource name} does not exist"
# 
# This script is a really simple wrapper around an AWS query. If you don't know
# which CloudFormation Stack created a particular resource in your AWS account,
# it can be almost impossible to find the stack. This is particularly the case for 
# CloudWatch Alarms, because Alarms do not have the ability to be tagged. (As of 2016-08-31)
# Other AWS resources can be tagged with details like the Stack Name, but 
# in case they are not tagged this script can be used.
# 
# Examples:
#   % find-CF-stack-for-AWS-resource.sh "not-a-real-resource just an example"
#   An error occurred (ValidationError) when calling the DescribeStackResources operation: Stack for not-a-real-resource just an example does not exist
#   % find-CF-stack-for-AWS-resource.sh i-d01e7d4d
#   museDbDeploy-dev-asglc-cf

export PATH=/bin:/usr/bin:/usr/local/bin

[[ $# -ne 1 ]] && echo "Usage: $0 \"name of AWS resource\"" && exit 1

aws cloudformation describe-stack-resources --query 'StackResources[*].[StackName]' --output text --physical-resource-id "${1}" | uniq
