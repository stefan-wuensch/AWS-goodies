#######################################################################################################################
# This is a set of zsh functions that do the same / similar things to the ones 
# that I developed with Al for bash. 
# 
# I expanded them to allow a one-liner use case:
# 	aws_session {aws-account-name} {MFA-code}
# 
# Example:
# 	aws_session stefanaccount 923741
# 
# Note the extra varation for files, using "aws configure set" and "aws configure get"
# I am a bit proud of how that all works!! :-)


# To-do: Add more comments.
# For better documentation in the meantime, see:
# https://github.com/stefan-wuensch/AWS-goodies/blob/master/AWS_STS_functions.bash


#######################################################################################################################

aws_session_unset() {
	unset AWS_PROFILE
	unset AWS_ACCESS_KEY_ID
	unset AWS_SECRET_ACCESS_KEY
	unset AWS_SESSION_TOKEN
	unset AWS_USERNAME
}



#######################################################################################################################

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
	echo "Success."
}



#######################################################################################################################

aws_session_files_unset() {
# 	aws configure set aws_access_key_id     "" --profile="${AWS_PROFILE}"
# 	aws configure set aws_secret_access_key "" --profile="${AWS_PROFILE}"
# 	aws configure set aws_session_token     "" --profile="${AWS_PROFILE}"
	profile="${AWS_PROFILE}"
	[[ $# -ge 1 ]] && profile="${1}"
	[[ -z "${profile}" ]] && echo "Error - didn't get a profile name either as command arg or as environment \$AWS_PROFILE" && return
# 	aws --profile="${profile}" configure get aws_session_token >/dev/null 2>&1 && aws --profile="${profile}" configure set aws_session_token ""
	for item in aws_access_key_id aws_secret_access_key aws_session_token ; do
		aws --profile="${profile}" configure get $item >/dev/null 2>&1 && aws --profile="${profile}" configure set $item ""
	done
	unset AWS_SESSION_TOKEN
	unset AWS_PROFILE
}

#######################################################################################################################

aws_session_files() {

	[[ $# -ne 2 ]] && echo "Usage: $0 aws_profile MFA_code" && return

# 	echo -n "Enter AWS profile: "
# 	local aws_profile
# 	read aws_profile

	grep "profile ${1}" $HOME/.aws/config >/dev/null 2>&1
	if [[ $? -ne 0 ]] ; then
		echo "Profile \"${1}\" not found in $HOME/.aws/config"
		all_profiles=$( grep profile ${HOME}/.aws/config | awk '{print $2}' | cut -d']' -f1 | sort )
		[[ -z "${all_profiles}" ]] && echo "Found no profiles in ${HOME}/.aws/config" && return
		echo "Available profiles:"
		echo "${all_profiles}"
		return
	fi
	local aws_profile="${1}"
	aws_session_files_unset "$aws_profile"

	local username=$(aws --profile="$aws_profile" --region=us-east-1 iam get-user --query User.UserName --output=text)
	[[ -z "${username}" ]] && echo "Error - couldn't get username for $aws_profile" && return
	echo "Found username \"${username}\""

	local device=$(aws --profile="$aws_profile" iam list-mfa-devices --user-name="$username" --query 'MFADevices[0].SerialNumber' --output=text)
	[[ -z "${device}" ]] && echo "Error - couldn't get device for $username" && return
	echo "Found device \"${device}\""

	local sts	# Can't define "local" at the same time as assignment, because then the exit status comes from the 'local' not the assignment!
	sts=$(aws --profile="$aws_profile" sts get-session-token --duration-seconds=14400 --serial-number="$device" --token-code="${2}" --output=text)
	[[ $? -ne 0 ]] && echo "Problem generating session token. Try again." && return

# 	export AWS_ACCESS_KEY_ID=$(echo "$sts" | cut -f 2)
# 	export AWS_SECRET_ACCESS_KEY=$(echo "$sts" | cut -f 4)
# 	export AWS_SESSION_TOKEN=$(echo "$sts" | cut -f 5)
# 	IFS=$'\t'
# 	sts_array=($sts)
# 	aws configure set aws_access_key_id     "${sts_array[ 2 ] }" --profile="${AWS_PROFILE}"
# 	aws configure set aws_secret_access_key "${sts_array[ 4 ] }" --profile="${AWS_PROFILE}"
# 	aws configure set aws_session_token     "${sts_array[ 5 ] }" --profile="${AWS_PROFILE}"
#------
	aws configure set aws_access_key_id     $(echo "${sts}" | cut -f 2) --profile="${aws_profile}"
	aws configure set aws_secret_access_key $(echo "${sts}" | cut -f 4) --profile="${aws_profile}"
	aws configure set aws_session_token     "$(echo ${sts} | cut -f 5)" --profile="${aws_profile}"

	export AWS_SESSION_TOKEN="active in files"
	export AWS_PROFILE="${aws_profile}"
	echo "Success."
}



#######################################################################################################################

# This function can be called as part of your PROMPT in .zshrc to show the AWS account name in the shell prompt!

# Example: PROMPT='%B%m%b:%U%n%u:%! $(aws_profile_prompt)%# '
# That will give a prompt that looks like:
# 	mercury:wuensch:10116 [stefanaccount] %
# Note you have to also "setopt prompt_subst" in your .zshrc for prompt substitution command execution to work.

aws_profile_prompt() {
	[[ -n "${AWS_SESSION_TOKEN}" ]] && [[ -n "${AWS_PROFILE}" ]] && echo "[${AWS_PROFILE}] "
}


#######################################################################################################################

