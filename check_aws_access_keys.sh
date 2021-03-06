#!/usr/bin/env bash

# check_aws_access_keys.sh
# Stefan Wuensch, 2017
#
# Usage: check_aws_access_keys.sh [ name-of-AWS-config-profile ]
#
# Requires:
# 	- AWS CLI
# 	- AWS IAM User Access Key(s) in either or both:
# 		~/.aws/config
# 		~/.aws/credentials
#
# Optional:
# 	- User IAM Policy allowed actions iam:GetUser and iam:ListAccountAliases
#
# Example Output:
# 	deploy : deploy-account@mycompany-production
# 	my-dev-profile : john_doe@johns-AWS-dev-account
# 	not-working-keys : error@error
# 	prod : john_doe@mycompany-production
#
# This takes "profile" entries from your AWS config & credentials files and outputs
# the IAM user name _and_ the AWS Account Name for each profile. In other words, you
# can give it a bunch of keys and it will tell you the username and account name
# if you don't know them! This is handy because sometimes you don't want to name
# the "profile" in the config file the same as the AWS Account name or username,
# and over time you might forget which key is which! (I have done that!)
#
# If no argument is given, this will grab all "profile" entries from your ~/.aws/config
# and/or ~/.aws/credentials files. An optional argument can be given if you want to
# check only that one profile. (Only one arg will be used. Any others will be ignored.)
#
# If there's an error getting the username or the account name (or both) the
# string "error" will replace the item that could not be found. If you get
# "error@error" for output, it most likely means that Access Key has been
# disabled / revoked.
#
# Note: if the IAM User account for a certain Access Key / profile does not have
# the IAM permission iam:ListAccountAliases, an attempt will still be made to grab
# the AWS Account numeric ID. If the output for a particular profile looks like
# "john_doe@123456789012" then you know the Access Key is working, but the
# iam:ListAccountAliases permission is not given to that IAM User account.
#
# See also:
# http://docs.aws.amazon.com/cli/latest/userguide/cli-multiple-profiles.html
# http://docs.aws.amazon.com/cli/latest/userguide/cli-config-files.html
# http://docs.aws.amazon.com/IAM/latest/APIReference/API_GetUser.html
# http://docs.aws.amazon.com/IAM/latest/APIReference/API_ListAccountAliases.html
#

# Grab everything from the AWS CLI config, except if it's commented out with a leading ';'
configProfiles=$( grep profile ${HOME}/.aws/config 2>/dev/null | grep -v '^;' | sed -e 's/^.*profile //g' | cut -d\] -f1 )

# Grab everything from the AWS CLI credentials, except if it's commented out with a leading ';'
# Note the 'awk' is using a regex so that we can use _both_ '[' and ']' as field separators.
credentialsProfiles=$( grep '\[' ${HOME}/.aws/credentials 2>/dev/null | grep -v '^;' | awk -F'[\]\[]' '{print $2}' )

# Take all the profile names and make one list, removing dupes. Since profile names can't contain spaces,
# we can simply transform them into newlines in order to do a simple unique operation.
profiles=$( ( echo ${configProfiles} ; echo ${credentialsProfiles} ) | tr ' ' '\n' | sort | uniq )

# If we got nothing, say so and bail.
if [[ -z "${profiles}" ]] ; then
	>&2 echo "Found no AWS account profiles. Nothing to do. Check \"${HOME}/.aws/config\" and \"${HOME}/.aws/credentials\" files."
	exit 1
fi

# If we get args use the first one as the profile name instead of the list of all profiles,
# but only if it's actually in the list of everything found in the two files.
if [[ $# -gt 0 ]] ; then
	if $( echo "${profiles}" | egrep -q "^${1}$" ) ; then
		profiles="${1}"
	else
		>&2 echo "Profile \"${1}\" not found in ${HOME}/.aws/config nor ${HOME}/.aws/credentials - bailing out."
		exit 2
	fi
fi

# Now loop through all the account profiles and test each one.
for profile in $( echo ${profiles} ) ; do

	# First try getting the UserName from IAM. This requires iam:GetUser permission.
	username=$( aws iam get-user --query User.UserName --output=text --profile=${profile} 2>/dev/null ) || username="error"

	# Now try to get the AWS Account name. This requires iam:ListAccountAliases permission.
	# Note how I'm being sneaky and doing a two-word echo on error, so that no matter if it's
	# success or failure the 'awk' will still be valid. This is better/easier than trying to get the
	# exit state of something early in a pipeline. Example: 'foo | bar || baz' tests exit of 'bar' not 'foo'.
	accountName=$( ( aws iam list-account-aliases --output text --profile ${profile} 2>/dev/null || echo eek error ) | awk '{print $2}' )

	# Now a bonus check which will always work, no matter what IAM User permissions are there (or not).
	# This fails only if the key is invalid. However, this can't get the account name - only the AWS account ID number.
	# This is a fall-back in case the IAM User account doesn't have iam:GetUser and/or iam:ListAccountAliases
	# so that we'll get something... better than nothing. Why bother doing the "get-user" call above if we
	# can _always_ get the UserName from this? Options. I like having options.
	# Only do this next "get-caller-identity" if either of the previous ones failed though.
	if [[ "${username}" == "error" ]] || [[ "${accountName}" == "error" ]] ; then

		# Note 1: This is doing a process-substitution so that we can use "read" to get two variables set at once
		# in the easiest possible way. http://www.tldp.org/LDP/abs/html/process-sub.html
		# Note 2: The 'awk' is using a regex so that we can use _both_ ':' and '/' as field separators. Sweet!!
		read accountID callerName < <( aws sts get-caller-identity --query=Arn --output=text --profile=${profile} 2>/dev/null | awk -F'[:/]' '{print $5,$7}' )
	fi

	# Now - finally - if we had any problems on the first attempts, and we _did_ get something
	# back from the "get-caller-identity" call, then use the ones that worked.
	[[ "${username}" == "error"    ]] && [[ -n "${callerName}" ]] && username=${callerName}
	[[ "${accountName}" == "error" ]] && [[ -n "${accountID}"  ]] && accountName=${accountID}

	# If after all of that the output is "error@error" we can be 100% certain that the Access Keys
	# are busted (meaning the IAM user account is dead) for the profile specified.
	echo "${profile} : ${username}@${accountName}"
done
