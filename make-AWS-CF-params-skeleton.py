#!/usr/bin/env python2

###################################################################################################
# make-AWS-CF-params-skeleton.py
# 
# by Stefan Wuensch 2016-07-21
# 
# Input: AWS CloudFormation JSON template on STDIN 
#   Typically this means pipe the JSON to this script, such as 'cat' a local file
#   or "curl -s" an Amazon sample, or "aws s3 cp" to '-', or similar.
# 
# Output: JSON skeleton of CloudFormation Parameters file
# 
# Purpose: If you want to generate a CloudFormation Stack from a CF template and a separate 
#   JSON file for Parameters, this will generate the framework of the required Parameters in
#   a JSON file which you can simply edit to fill in each ParameterValue.
# 
# 
# Additional Reading:
#   https://aws.amazon.com/blogs/devops/passing-parameters-to-cloudformation-stacks-with-the-aws-cli-and-powershell/
# 
# 
# To Do: Add file input/output instead of just stdin/stdout
# 
###################################################################################################
# 
# Example:
#   This uses an online sample Amazon CF JSON Template. It is retrieved via curl and processed by this script.
#   Note how each "ParameterValue" contains "REPLACE THIS WITH:" and the "Type", a list of any "AllowedValues", and
#   the "Description" from the template!! (Cool, eh?)
# 
# % curl -s https://s3.amazonaws.com/cloudformation-templates-us-east-1/LAMP_Single_Instance.template | make-AWS-CF-params-skeleton.py
# 
# [
#     {
#         "ParameterKey": "DBName", 
#         "ParameterValue": "REPLACE THIS WITH: String - MySQL database name"
#     }, 
#     {
#         "ParameterKey": "DBPassword", 
#         "ParameterValue": "REPLACE THIS WITH: String - Password for MySQL database access"
#     }, 
#     {
#         "ParameterKey": "DBRootPassword", 
#         "ParameterValue": "REPLACE THIS WITH: String - Root password for MySQL"
#     }, 
#     {
#         "ParameterKey": "DBUser", 
#         "ParameterValue": "REPLACE THIS WITH: String - Username for MySQL database access"
#     }, 
#     {
#         "ParameterKey": "InstanceType", 
#         "ParameterValue": "REPLACE THIS WITH: String - Allowed:[t1.micro, t2.nano, t2.micro, t2.small, t2.medium, t2.large, m1.small, m1.medium, m1.large, m1.xlarge, m2.xlarge, m2.2xlarge, m2.4xlarge, m3.medium, m3.large, m3.xlarge, m3.2xlarge, m4.large, m4.xlarge, m4.2xlarge, m4.4xlarge, m4.10xlarge, c1.medium, c1.xlarge, c3.large, c3.xlarge, c3.2xlarge, c3.4xlarge, c3.8xlarge, c4.large, c4.xlarge, c4.2xlarge, c4.4xlarge, c4.8xlarge, g2.2xlarge, g2.8xlarge, r3.large, r3.xlarge, r3.2xlarge, r3.4xlarge, r3.8xlarge, i2.xlarge, i2.2xlarge, i2.4xlarge, i2.8xlarge, d2.xlarge, d2.2xlarge, d2.4xlarge, d2.8xlarge, hi1.4xlarge, hs1.8xlarge, cr1.8xlarge, cc2.8xlarge, cg1.4xlarge] - WebServer EC2 instance type"
#     }, 
#     {
#         "ParameterKey": "KeyName", 
#         "ParameterValue": "REPLACE THIS WITH: AWS::EC2::KeyPair::KeyName - Name of an existing EC2 KeyPair to enable SSH access to the instance"
#     }, 
#     {
#         "ParameterKey": "SSHLocation", 
#         "ParameterValue": "REPLACE THIS WITH: String -  The IP address range that can be used to SSH to the EC2 instances"
#     }
# ] 
# 
# 
# If you were to save the output of the above example to a file named "example-params.json" (and put in 
#   valid ParameterValue entries) then you could:
# 
# % aws cloudformation create-stack --stack-name my-test-stack --template-body https://s3.amazonaws.com/cloudformation-templates-us-east-1/LAMP_Single_Instance.template --parameters file://example-params.json
# 
# 
# 
###################################################################################################

import sys, json, select

if not select.select( [ sys.stdin, ], [], [], 5 )[ 0 ]:		# Check for data, waiting 5 sec. max
	print "Error: This program expects a CloudFormation JSON Template on STDIN. (For example, via a pipe.)"
	sys.exit( 1 )

inputJSON = json.loads( sys.stdin.read() )[ 'Parameters' ]
parameters = []
outputJSON = []

for parameter in inputJSON:		# This is just so we can sort by parameter name
	parameters.append( parameter )
parameters.sort()

for parameter in parameters:
	thisParam = {}
	thisParam[ 'ParameterKey' ] = parameter
	thisParam[ 'ParameterValue' ] = "REPLACE THIS WITH: "	# We will be appending to this string with the additional stuff below

	if 'Type' in inputJSON[ parameter ]:
		thisParam[ 'ParameterValue' ] += str( inputJSON[ parameter ][ 'Type' ] ) + " - "

	if 'Default' in inputJSON[ parameter ]:
		thisParam[ 'ParameterValue' ] += 'Default:\'' + str( inputJSON[ parameter ][ 'Default' ] ) + "\' - "

	if 'AllowedValues' in inputJSON[ parameter ]:
		thisParam[ 'ParameterValue' ] += 'Allowed:[' + ', '.join( inputJSON[ parameter ][ 'AllowedValues' ] ) + '] - '

	if 'Description' in inputJSON[ parameter ]:
		thisParam[ 'ParameterValue' ] += str( inputJSON[ parameter ][ 'Description' ] )

	outputJSON.append( thisParam )

print json.dumps( outputJSON, sort_keys = True, indent = 4 )
