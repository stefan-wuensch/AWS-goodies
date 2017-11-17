#!/usr/bin/env bash


####################################################################################################
# display_AWS_identity()
#
# Function by Stefan Wuensch 2017-11-17
#
# This displays the AWS IAM User Name and AWS Account Name, so that not only
# is it clear what's happening, but also there's a validation of the AWS
# session / credentials. This works with STS (keys & MFA stored in environment
# variables) and SAML (HKey session).
#
# Usage: Paste this into any bash script, then simply call it by
# including "display_AWS_identity" somewhere in your script.
#
# This function performs output to STDOUT only, so it won't
# interrupt any other program flow. However, if you do want to
# bail out on a failure to validate the credentials, simply
# un-comment the line near the end that contains "exit".
# You can also process the return state of this function:
# 0 -> OK, 1 -> Error
#
# This script checked with https://www.shellcheck.net/


function display_AWS_identity() {

	# First try getting the UserName from IAM. This requires iam:GetUser permission.
	username=$( aws iam get-user --query User.UserName --output=text 2>/dev/null ) || username="error"

	# Now try to get the AWS Account name. This requires iam:ListAccountAliases permission.
	# Note how I'm being sneaky and doing a two-word echo on error, so that no matter if it's
	# success or failure the 'awk' will still be valid. This is better/easier than trying to get the
	# return state of something early in a pipeline. Example: 'foo | bar || baz' tests return of 'bar' not 'foo'.
	accountName=$( ( aws iam list-account-aliases --output text 2>/dev/null || echo eek error ) | awk '{print $2}' )

	# Now a bonus check which will always work, no matter what IAM User permissions are there (or not).
	# This fails only if credentials are invalid. However, this can't get the account name - only the AWS account ID number.
	# This is a fall-back in case the IAM User account doesn't have iam:GetUser and/or iam:ListAccountAliases
	# so that we'll get something... better than nothing. Why bother doing the "get-user" call above if we
	# can _always_ get the UserName from this? Options. I like having options.
	# Only do this next "get-caller-identity" if either of the previous ones failed though.
	if [[ "${username}" == "error" ]] || [[ "${accountName}" == "error" ]] ; then

		# Note 1: This is doing a process-substitution so that we can use "read" to get three variables set at once
		# in the easiest possible way. http://www.tldp.org/LDP/abs/html/process-sub.html
		# Note 2: The 'awk' is using a regex so that we can use _both_ ':' and '/' as field separators. Sweet!!
		read -r accountID roleName HKey_email < <( aws sts get-caller-identity --query=Arn --output=text 2>/dev/null | awk -F'[:/]' '{print $5,$7,$8}' )
	fi

	# Now - finally - if we had any problems on the first attempts, and we _did_ get something
	# back from the "get-caller-identity" call, then use the ones that worked.
	[[ "${username}" == "error"    ]] && [[ -n "${roleName}" ]] && username=${roleName}
	[[ "${accountName}" == "error" ]] && [[ -n "${accountID}"  ]] && accountName=${accountID}

	# If however we're using a SAML auth session, we want to show the email address.
	[[ -n "${HKey_email}" ]] && username=${HKey_email}

	# If after all of that the output contains "error" we can be 100% certain that the credentials
	# are busted (meaning the IAM user account is dead) for the profile specified or current session.
	if echo "${username} ${accountName}" | grep -q error ; then
		echo "ERROR: Problem validating active AWS session / credentials. You may need to check or refresh your access keys or STS."
		# exit 1	# Un-comment this line to exit here if there's a problem. Otherwise...
		return 1	# This allows you to act upon the result of this function if you want.
	else
		echo "Found active AWS session/credentials for \"${username}\" in account \"${accountName}\""
		return 0	# This allows you to act upon the result of this function if you want.
	fi

}
# function display_AWS_identity() END
####################################################################################################


# This is here so that this file can simply be used stand-alone.
# Note we're exiting with the return state of the function, but
# you can use the return value for other logic in your code.
display_AWS_identity
exit $?
