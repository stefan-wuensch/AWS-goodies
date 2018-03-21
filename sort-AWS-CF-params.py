#!/usr/bin/env python

###################################################################################################
# sort-AWS-CF-params.py
#
# by Stefan Wuensch, 2016-2017
#
# This script sorts and formats AWS CloudFormation JSON Parameters.
# Why would you want to sort JSON??? By applying a consistent sort order
# to CloudFormation JSON you can do direct comparison between different
# JSON files. This means that (for example) when working with multiple tiers of
# one application (dev/test/stage/prod) you can simply "diff" the parameters.
# If the JSON was not sorted and uniformly formatted, you would have to actually
# parse & process the JSON to compare it; you wouldn't be able to use simple,
# conventional tools like "diff".
#
#
# Input: AWS CloudFormation JSON Parameters (ParameterKey / ParameterValue) on STDIN
#   Typically this means pipe the JSON to this script, such as 'cat' a local file
#   or "curl -s" an Amazon sample, or run an AWS CLI command which generates Parameters in JSON.
#
#
# Output: Sorted and formatted JSON Parameters on STDOUT
#   Typically output from this script would be saved to a file (see usage examples below)
#   but piping to "diff" is also useful.
#
#
# Usage examples:
#   % cat faads-dev-elb-cw-cf.parameters.json | sort-AWS-CF-params.py > faads-dev-elb-cw-cf.parameters.sorted.json
#   % cat faads-dev-elb-cw-cf.parameters.json | sort-AWS-CF-params.py | diff - faads-prod-elb-cw-cf.parameters.json
#   % aws cloudformation describe-stacks --stack-name maximo-prod-elb-cf | jq '.Stacks[].Parameters' | sort-AWS-CF-params.py > maximo-prod-elb-cf.parameters.json
#
#
# References:
# https://aws.amazon.com/blogs/devops/passing-parameters-to-cloudformation-stacks-with-the-aws-cli-and-powershell/
# http://docs.aws.amazon.com/cli/latest/reference/cloudformation/create-stack.html
# https://confluence.huit.harvard.edu/display/~srw812/AWS+Tips+and+Tricks
#
#
# To Do: Add file input/output instead of just stdin/stdout
#
###################################################################################################
#
# Example input - note how the formatting is inconsistent and everything is out-of-order.
#
# [ {   "ParameterKey": "InstanceAMI",
#    "ParameterValue": "ami-a4827dc9"
#  },
#     {
#         "ParameterValue": "dev",
#         "ParameterKey": "Environment"
#     },
#     {
#     "ParameterKey": "AssetID",
#       "ParameterValue": "8955"
#     },
#     {
#      "ParameterKey": "BucketName",
#      "ParameterValue": "adts-deploy-dev-bucket"
#     },
#     {
#         "ParameterValue": "admints-dev-faads-standard-dev-20160609",
#         "ParameterKey": "KeyName"
#     },
#     {"ParameterKey": "InstanceType", "ParameterValue": "t2.small"},
#     {
#         "ParameterKey": "SecurityGroups",
#         "ParameterValue": "sg-121b9269"
#     },
#     {   "ParameterKey": "ApplicationName",
#         "ParameterValue": "faads"
#     }
# ]
#
#
# Example output after processing the above input - now it has uniform formatting,
# and all the ParameterKey/ParameterValue pairs are in order!
# [
#     {
#         "ParameterKey": "ApplicationName",
#         "ParameterValue": "faads"
#     },
#     {
#         "ParameterKey": "AssetID",
#         "ParameterValue": "8955"
#     },
#     {
#         "ParameterKey": "BucketName",
#         "ParameterValue": "adts-deploy-dev-bucket"
#     },
#     {
#         "ParameterKey": "Environment",
#         "ParameterValue": "dev"
#     },
#     {
#         "ParameterKey": "InstanceAMI",
#         "ParameterValue": "ami-a4827dc9"
#     },
#     {
#         "ParameterKey": "InstanceType",
#         "ParameterValue": "t2.small"
#     },
#     {
#         "ParameterKey": "KeyName",
#         "ParameterValue": "admints-dev-faads-standard-dev-20160609"
#     },
#     {
#         "ParameterKey": "SecurityGroups",
#         "ParameterValue": "sg-121b9269"
#     }
# ]
#
#
###################################################################################################


import sys, json, select

# For now (until the next version) this script only works on STDIN.
if not select.select( [ sys.stdin, ], [], [], 5 )[ 0 ]:		# Check for data, waiting 5 sec. max
	print "Error: This program expects a CloudFormation JSON Template on STDIN. (For example, via a pipe.)"
	sys.exit( 1 )

inputJSON = json.loads( sys.stdin.read() )
parameters = {}
parameterNames = []
outputJSON = []

for parameterDict in inputJSON:
	parameterNames.append( parameterDict[ 'ParameterKey' ] )	# Make an array so that we can sort it
	parameters[ parameterDict[ 'ParameterKey' ] ] = parameterDict[ 'ParameterValue' ]
# 	print "parameters:\n", json.dumps( parameters, sort_keys = True, indent = 4 )		# Debugging output

parameterNames.sort()
# outputJSON.append( parameterNames )		# Debugging output

# Now put it all back together, now that it's sorted by parameter name (the value of ParameterKey)
for parameterName in parameterNames:
	thisParam = {}
	thisParam[ 'ParameterKey' ] = parameterName
	thisParam[ 'ParameterValue' ] = parameters[ parameterName ]
	outputJSON.append( thisParam )

# print "parameterNames:\n", json.dumps( parameterNames, sort_keys = True, indent = 4 )		# Debugging output
print json.dumps( outputJSON, sort_keys = True, indent = 4 )
