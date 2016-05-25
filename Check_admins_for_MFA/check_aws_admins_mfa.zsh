#!/usr/bin/env zsh

# check_aws_admins_mfa.zsh
# by Stefan Wuensch 2016-05-25

# This script checks to make sure that any AWS Admin (a user with 
# membership in an admin group) also is a member of a group which
# forces MFA use.

# Usage:
# check_aws_admins_mfa.zsh [ AWS_account_name]
# 
# The optional argument is an AWS account to check. If no arg is given, all AWS accounts
# found in your AWS config file will be checked.

# Outputs:
# - user names found in an admin group which don't also appear in a force-MFA group, or
# - if all admins are in MFA group, then print "All OK"

# Assumptions:
# - all the AWS accounts you want to check are listed in your $HOME/.aws/config as a "profile" if not given as $1
# - the user running this script (you!) are in an admin group
# - the user running this script (you!) are required to use MFA since you're an admin
# - the only admin group(s) whose members are to be checked for MFA are the members of the same admin group(s) as you
# - the group name which forces MFA simply has the string "mfa" (case insensitive) in it

# To do:
# - examine the Policy of all groups to find which groups grant admin rights (this could be VERY difficult!)
# - examine the Policy of all groups to find the exact group which forces the use of MFA (instead of just looking for a group name with "mfa" in it)


# Sample output:
# % check_aws_admins_mfa.zsh my-aws-account
#   ########################################################################
# MFA code for my-aws-account: 105211
# Username: stefan
# Success.
# Will check the following groups: AWS_Admins
# fred_flintstone is an admin but not in any MFA group - AWS account my-aws-account


# See also:
# https://blogs.aws.amazon.com/security/post/Tx2SJJYE082KBUK/How-to-Delegate-Management-of-Multi-Factor-Authentication-to-AWS-IAM-Users
# https://s3.amazonaws.com/awsiammedia/public/sample/DelegateManagementofMFA/DelegateManagementofMFA_policydocument_060115.txt



#####################################################################################################################

aws_session_unset() {
	unset AWS_PROFILE
	unset AWS_ACCESS_KEY_ID
	unset AWS_SECRET_ACCESS_KEY
	unset AWS_SESSION_TOKEN
	unset AWS_USERNAME
}

#####################################################################################################################

aws_session() {

	aws_session_unset
	[[ $# -ne 2 ]] && echo "Usage: $0 aws_profile MFA_code" && return 1

# 	echo -n "Enter AWS profile: "
# 	local aws_profile
# 	read aws_profile

	grep "profile ${1}" $HOME/.aws/config >/dev/null 2>&1
	if [[ $? -ne 0 ]] ; then
		echo "Profile \"${1}\" not found in $HOME/.aws/config"
		all_profiles=$( grep profile ${HOME}/.aws/config | grep -v '^\;' | awk '{print $2}' | cut -d']' -f1 | sort )
		[[ -z "${all_profiles}" ]] && echo "Found no profiles in ${HOME}/.aws/config" && return 1
		echo "Available profiles:"
		echo "${all_profiles}"
		return 1
	fi
	local aws_profile="${1}"

	local username=$(aws --profile="$aws_profile" --region=us-east-1 iam get-user --query User.UserName --output=text)
	echo "Your username: ${username}"
	local device=$(aws --profile="$aws_profile" iam list-mfa-devices --user-name="$username" --query 'MFADevices[0].SerialNumber' --output=text)
	local sts
	sts=$(aws --profile="$aws_profile" sts get-session-token --duration-seconds=14400 --serial-number="$device" --token-code="${2}" --output=text)
	[[ $? -ne 0 ]] && echo "Problem generating session token. Try again." && return 1

	export AWS_ACCESS_KEY_ID=$(echo "$sts" | cut -f 2)
	export AWS_SECRET_ACCESS_KEY=$(echo "$sts" | cut -f 4)
	export AWS_SESSION_TOKEN=$(echo "$sts" | cut -f 5)
	export AWS_PROFILE="${aws_profile}"
	export AWS_USERNAME="${username}"
# 	echo "Success."
}

#####################################################################################################################

check_admin_users() {

	found_admins_without_MFA="N"

	if [[ -z "${AWS_USERNAME}" ]] ; then
		local username=$(aws --profile="$aws_profile" --region=us-east-1 iam get-user --query User.UserName --output=text)
		[[ -n "${username}" ]] && export AWS_USERNAME=${username}
	fi

	my_admin_groups=$( aws iam list-groups-for-user --user-name="${AWS_USERNAME}" --query='Groups[*].GroupName' --output=text | tr '\t' '\n' | grep -i admin )
	echo "Will check the following groups: \n${my_admin_groups}"

	admin_users=""
	for group in $( echo $my_admin_groups ) ; do
		this_groups_admins=$( aws iam get-group --group-name="${group}" --output=text --query='Users[*].UserName' )
		admin_users="${admin_users} ${this_groups_admins}"
	done

	for user in $( echo $admin_users ) ; do
		mfa_for_user=$( aws iam list-groups-for-user --user-name="${user}" --query='Groups[*].GroupName' --output=text | tr '\t' '\n' | grep -i mfa )
	# 	echo "$user is in $mfa_for_user"
		[[ -z "${mfa_for_user}" ]] && 
			echo "$user is an admin but not in any MFA group - AWS account ${AWS_PROFILE}" && 
			found_admins_without_MFA="Y"
	done

	[[ $found_admins_without_MFA == "N" ]] && echo "All OK - all users in admin groups are also in MFA group"

}

#####################################################################################################################


if [[ $# -eq 0 ]] ; then
	accounts=$( grep profile ~/.aws/config | grep -v '^\;' | cut -d' ' -f2 | cut -d']' -f1 )
else
	accounts="${1}"
fi


for account in $( echo $accounts ) ; do
	echo "########################################################################"
	aws_session_unset
	printf "MFA code for ${account}: "
	read code
	aws_session $account $code
	[[ $? -ne 0 ]] && continue
	check_admin_users
	echo "\n"
done

