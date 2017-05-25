#!/usr/bin/env bash

################################################################################
# save-stack.sh
# by Stefan Wuensch, 2016-2017
#
# This script saves to files everything about a running CloudFormation Stack
# that you would need to either re-create the stack from scratch, or simply update
# the stack Parameters in a quick & simple way.
#
################################################################################
#
# Usage:
#   save-stack.sh "name of a CloudFormation Stack"
#
# Required argument:
#   The name of an AWS CloudFormation Stack that is running.
#   (Use of this script on a Stack which is not running has not been tested
#   and may give unexpected and/or incomplete output.)
#
# Required components:
#   1) AWS CLI and active STS session. See AWS_STS_functions also in this repo.
#   2) jq to parse the JSON output. See https://stedolan.github.io/jq/
#   3) Python with the standard included JSON module to apply uniform formatting
#   4) The script 'sort-AWS-CF-params.py' from "python_scripts" of this same repo
#
# Output on STDOUT: None  (unless ${VERBOSE} or ${DEBUG} is set to "true")
#
# Output to three files:   (these examples here use stack name "my-sample-stack" with a JSON template)
#   1) my-sample-stack.template.json 		contains the CF Template of the Stack
#   2) my-sample-stack.describe-stacks.json 	contains all the CF meta-data from the stack
#   3) my-sample-stack.parameters.json 		contains the Parameters of the running stack, sorted
# If the template is YAML, the output file name for 1) would be "my-sample-stack.template.yaml"
#
# Note that the "sort-AWS-CF-params.py" script sorts the Parameters so you can
# easily compare the JSON file to others. This allows you to compare (for example)
# different tiers of the same application using just "diff" because the sort order
# of Dev and Prod would be the same. Also the Python standard JSON formatting
# is essential to being able to "diff" different JSON files. Sorting the Parameters
# is not absolutely required, and if the "sort-AWS-CF-params.py" can't be found
# then this script will continue just fine and still output a usable (but unsorted)
# Parameters file.
#
# This script checked with https://www.shellcheck.net/
#
################################################################################
#
# Detailed Example
#
# % save-stack maximo-test-elb-alarms
# % ls -l
# total 88
# -rw-------  1 johnharvard  staff   6693 Jan 25 12:28 maximo-test-elb-alarms.describe-stacks.json
# -rw-------  1 johnharvard  staff   3259 Jan 25 12:28 maximo-test-elb-alarms.parameters.json
# -rw-------  1 johnharvard  staff  29949 Jan 25 12:28 maximo-test-elb-alarms.template.json
# % head -20 maximo-test-elb-alarms.parameters.json
# [
#     {
#         "ParameterKey": "ApplicationName",
#         "ParameterValue": "Maximo"
#     },
#     {
#         "ParameterKey": "ApplicationTeamName",
#         "ParameterValue": "CampusServices"
#     },
#     {
#         "ParameterKey": "CriticalAlarmTopic",
#         "ParameterValue": "arn:aws:sns:us-east-1:182465728688:maximo-test-elb-application-sns-topic"
#     },
#     {
#         "ParameterKey": "ELBHTTPCodeELB4XXAlarmComparisonOperator",
#         "ParameterValue": "GreaterThanThreshold"
#     },
#     {
#         "ParameterKey": "ELBHTTPCodeELB4XXAlarmEvaluationPeriods",
#         "ParameterValue": "1"
#
#
# After you edit the .parameters.json file with your changes, you can then update the CloudFormation stack like this:
# % aws cloudformation update-stack --stack-name maximo-test-elb-alarms --template-body file://maximo-test-elb-alarms.template.json --parameters file://maximo-test-elb-alarms.parameters.json
#
# This process allows you to quickly update a CloudFormation Stack by dumping what is running,
# so that you don't have to try and find the original template and parameters that were used!
#
# NOTE: once you have used this script & method to save and update a stack, you should ***commit the
# files to version control*** for later use!
#
################################################################################


# Do we want extra output?
# Only allowed values are: "true" or "false" - gets evaluated as an executable.
# Accept ${VERBOSE} and ${DEBUG} if set outside this script, but only if "true" or "false"
# Example:
#    % VERBOSE=true save-stack.sh some-stack-name
#
# First thing safety-check any input environment variables
[[ "${DEBUG}"   != "false" ]] && [[ "${DEBUG}"   != "true" ]] && DEBUG="false"
[[ "${VERBOSE}" != "false" ]] && [[ "${VERBOSE}" != "true" ]] && VERBOSE="false"
# 
# Now we know they are set and safe, so...
# (Setting Debug also gives you Verbose.)
${DEBUG}   && { echo "Debug output On." ; set -x ; VERBOSE="true" ; }
${VERBOSE} && { echo "Verbose output On." ; }


# Need to make sure this is NOT run as root, for extra safety.
# Because we're going to be possibly executing the "sort-AWS-CF-params.py"
# helper script from a location outside of $PATH this should only be
# run as a non-root user.
[[ ${EUID} -eq 0 ]] && { ( >&2 echo "You appear to be running this as root (EUID $EUID). Please run this only as a non-root user." ) ; exit 1 ; }


# Have to get one and only one arg
[[ $# -ne 1 ]] && { ( >&2 echo "Usage: ${0} \"name of AWS CloudFormation Stack\"" ) ; exit 1 ; }
STACK="${1}"

# Sanity check - make sure the stack by that name actually exists!!
if ! aws cloudformation describe-stacks --stack-name "${STACK}" >/dev/null 2>&1 ; then
	( >&2 echo "Error running AWS CLI command \"describe-stacks\" for stack \"${STACK}\"" )
	( >&2 echo "Check the name / spelling / case / capitalization of the CF Stack." )
	( >&2 echo "Also check to make sure you have active STS. https://confluence.huit.harvard.edu/pages/viewpage.action?pageId=32674220" )
	( >&2 echo "and \"AWS_STS_functions\" in https://bitbucket.org/huitcloudservices/hcdo-common-utilities" )
	exit 1
fi


# Have to have jq!
which jq >/dev/null 2>&1 || { ( >&2 echo "Error: Can't find jq. Get it from https://stedolan.github.io/jq/" ) ; exit 1 ; }


# Check to see if we have 'sort-AWS-CF-params.py' in the PATH. If not, we'll check the PWD.
# After that, check ../python_scripts/ in case this script is running from a local check-out of the repo.
# We'll even try it by relative path and absolute path via 'dirname'.
# If still no luck, substitute 'cat' so that we can use the same command pipeline no matter what!!
JSONSORTER="sort-AWS-CF-params.py"
DIRNAME=$( dirname "${0}" )

# Each one of these items making the loop is a potential location of the sorting script we're trying to find.
for try in "${JSONSORTER}" "./${JSONSORTER}" "../python_scripts/${JSONSORTER}" "${DIRNAME}/${JSONSORTER}" "${DIRNAME}/../python_scripts/${JSONSORTER}" ; do
	${VERBOSE} && echo "Trying ${try}"
	if which "${try}" >/dev/null 2>&1 ; then
		${VERBOSE} && echo "Yay! Found ${try}"
		JSONSORTER="${try}"
		break
	fi
done

# After all the work in the loop above, we hopefully ended up with a sorting script located.
# In case we simply exhausted all the attempts without actually finding what we want,
# check one last time and if no luck just use 'cat'.
if ! which "${JSONSORTER}" >/dev/null 2>&1 ; then
	( >&2 echo "Can't find JSON sorting utility ${JSONSORTER}. Parameters file will not be sorted." )
	( >&2 echo "See https://bitbucket.org/huitcloudservices/hcdo-common-utilities" )
	JSONSORTER="cat"
fi
${VERBOSE} && echo "Continuing with JSONSORTER=\"${JSONSORTER}\""


# Time to make the donuts!!

#1 step - Get the Template, extract only the TemplateBody, format it, and save it.
${VERBOSE} && echo "aws cloudformation get-template to ${STACK}.template"
aws cloudformation get-template --stack-name "${STACK}" | jq '.TemplateBody' | python -m json.tool > "${STACK}.template"

# Now figure out if it's JSON or YAML, and act accordingly.
case $( head -c1 "${STACK}.template" ) in

	'{')	${VERBOSE} && echo "Template is JSON"
		# We already have nicely-formatted JSON from the 'python -m json.tool' above, so nothing else needed...
		# ...except to add the extension.
		mv "${STACK}.template" "${STACK}.template.json" ;;

	'"')	${VERBOSE} && echo "Template is YAML"
		# The YAML coming out of the 'aws cloudformation get-template' call is stuffed into a JSON object,
		# so we have to turn it back into readable YAML.
		# This will: 1) edit in-place 2) drop leading quote 3) drop trailing quote
		# 4) convert '\"' to '"' 5) drop extra trailing '\n' 6) change '\n' to actual newline
		sed -i "" -e 's/^"//' -e 's/"$//' -e 's/\\"/"/g' -e 's/\\n$//' -e 's/\\n/\
/g' "${STACK}.template"
		mv "${STACK}.template" "${STACK}.template.yaml" ;;

	*)	echo "Expected JSON or YAML, but ${STACK}.template doesn't look like either." ;;
esac


#2 step - Describe the Stack, format it, and save it.
${VERBOSE} && echo "aws cloudformation describe-stacks to ${STACK}.describe-stacks.json"
aws cloudformation describe-stacks --stack-name "${STACK}" | python -m json.tool > "${STACK}.describe-stacks.json"


#3 step - Pull only the Parameters from the "describe-stacks" file, sort it, format it, and save it.
# Note: even though the JSON sorting script is Python, it doesn't output _exactly_ the same
# JSON format as the Python JSON module "tool" - so we hit it with the same formatter for total consistency!
${VERBOSE} && echo "Pulling parameters only to ${STACK}.parameters.json"
jq -c '.Stacks[].Parameters' "${STACK}.describe-stacks.json" | "${JSONSORTER}" | python -m json.tool > "${STACK}.parameters.json"


${VERBOSE} && echo "These files were just produced:" && ls -l "${STACK}."*


exit 0		# No matter what happened above, we're done.
		# Since this script will output NOTHING to stdout if it runs successfully
		# (and ${VERBOSE}=="false") we will rely on any output from the AWS CLI and/or
		# jq and/or Python to tell us if anything failed.




################################################################################
#
# Bonus shell function!!
#
# In case everything above is too bulky and you want just a simple pared-down
# way of doing all the same stuff, here's a bash function instead.
# This was my original way of saving a stack - nothing more.
# All the code above plus documentation was added to make this more
# usable, understandable, repeatable, and helpful. :-)
#
# Note: this function doesn't yet handle YAML templates. To-do.

function save-stack() {
	aws cloudformation get-template    --stack-name "${1}" | jq '.TemplateBody' | python -m json.tool > "${1}.template.json"
	aws cloudformation describe-stacks --stack-name "${1}" | python -m json.tool > "${1}.describe-stacks.json"
	jq -c '.Stacks[].Parameters' "${1}.describe-stacks.json" | sort-AWS-CF-params.py | python -m json.tool > "${1}.parameters.json"
}

################################################################################
