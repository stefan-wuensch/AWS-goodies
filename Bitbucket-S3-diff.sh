#!/usr/bin/env bash

#############################################################################################################
# Bitbucket-S3-diff.sh
# 
# by Stefan Wuensch, Summer 2016
# 
# Usage: Bitbucket-S3-diff.sh [ --sync-metadata ]
# 
# This is all a big wrapper around a cool / sneaky way of running "diff" to compare a local directory
# against a remote location inside an AWS S3 bucket. The S3_BUCKET_LOCATION_FILE tells this script
# where to find the remote S3 location to compare to the local directory which contains that file.
# 
# The general idea is:
# 1) Run an "S3 sync" dry run (don't actually do anything, just report)
# 2) Take the output from the "S3 sync" command and iterate over each object that it wants to copy
# 3) Compare each object, and show useful info about what's different or if they are the same
# 
# NOTE: This script assumes that Bitbucket is the "source of truth" and that you want to be eventually
# copying _from_ Bitbucket _to_ S3. However, since this script does not actually do anything (it merely
# finds and displays differences and makes suggestions on what CLI commands to run) you still have the 
# option of copying something _from_ S3. You just need to be careful when you reverse the order of the args.
# 
# Tip: most output from this script (when it runs without input validation errors) is all shell-commented 
# with leading '#' other than useful AWS CLI commands that you might want to run. This (hopefully) makes
# it really easy to run individual "aws s3 cp" operations by simply copying and pasting the example line.
# 
# Usage suggestion: Since this script iterates across all objects in the location which "s3 sync" has shown
# to be different in ANY way, it can be annoying for some people to see all the output for matching objects.
# (The "s3 sync" wants to copy items based on metadata NOT contents - which is why I wrote this script!)
# Instead of reading through lots of "Same" you can try running "Bitbucket-S3-diff.sh >/dev/null ; echo $?"
# If you get a non-zero exit status you know something didn't match, and you should run it again and
# examine the output. If you do get a zero exit status, everything matches and you can move on. :-)
# Also, if you get "There were no differences found" but there's lots of output saying "Same" then you know
# that ONLY the objects' metadata is different - so there should be no harm in doing the "s3 sync" in full
# because then all the metadata will also be matching.
# 
#############################################################################################################


#############################################################################################################
# This is the main file to indicate where the S3 location is for this directory in the local checkout
# 
# Details of S3_BUCKET_LOCATION_FILE: 
#   - must exist in the current working directory (cwd)
#   - must contain the AWS account name and the S3 path, comma-delimited
#   - example:    admints,s3://admints-stage-bucket/fastcat
#   - only the first line of the file will be processed
#   - only one remote location can be mapped to each directory in the local repo checkout
# 
S3_BUCKET_LOCATION_FILE=".s3-location.txt"
#############################################################################################################

export PATH=/bin:/usr/bin:/usr/local/bin	# for safety

# This flag from the command arg will determine whether or not we
# copy from local to S3 if the only thing that differs is the metadata.
ALLOWED_ARG="--sync-metadata"
COPY_FOR_METADATA="N"
if [[ $# -ne 0 ]] ; then
	if [[ "${1}" == "${ALLOWED_ARG}" ]] ; then
		COPY_FOR_METADATA="Y"
	else
		echo "Usage: $0 [ ${ALLOWED_ARG} ]"
		exit 1
	fi
fi


# Check our inputs. Note we're only taking line 1 of the file.
[[ ! -f "${S3_BUCKET_LOCATION_FILE}" ]] && echo "Error: Where is the ${S3_BUCKET_LOCATION_FILE}?" && exit 1
[[ $( wc -l "${S3_BUCKET_LOCATION_FILE}" | awk '{print $1}' ) -eq 0 ]] && echo "Error: $( /bin/pwd -P )/${S3_BUCKET_LOCATION_FILE} appears empty" && exit 2
[[ $( wc -l "${S3_BUCKET_LOCATION_FILE}" | awk '{print $1}' ) -gt 1 ]] && echo "# Warning: only using line 1 of ${S3_BUCKET_LOCATION_FILE}"
S3_BUCKET_ACCOUNT="$( head -1 ${S3_BUCKET_LOCATION_FILE} | cut -d, -f1 )"
S3_BUCKET_LOCATION="$( head -1 ${S3_BUCKET_LOCATION_FILE} | cut -d, -f2 )"
[[ -z "${S3_BUCKET_ACCOUNT}" ]] && echo "Error: Didn't get an AWS Account name in ${S3_BUCKET_LOCATION_FILE}"  && exit 1
[[ -z "${S3_BUCKET_LOCATION}" ]] && echo "Error: Didn't get an S3 bucket path in ${S3_BUCKET_LOCATION_FILE}"   && exit 1


# Capture signals and force an exit because the AWS CLI seems to have its own signal handling that gets in the way
trap "exit 127" EXIT HUP INT QUIT TERM

# Now just for extra safety, give confirmation that we are going to actually 
# run a 'cp' operation if there's no differences in the file contents and
# it's only the metadata which is different. (and if the command arg was given)
if [[ "${COPY_FOR_METADATA}" == "Y" ]] ; then
	echo -e "\n# Got argument \"${ALLOWED_ARG}\" so copy to S3 _will be run_ if metadata is the ONLY difference. (Meaning, the file contents are identical.)"
	echo -e "# Hit ^C now if you don't want this!"
	printf "# 5..." ; sleep 2 ; printf "4..." ; sleep 2 ; printf "3..." ; sleep 2 ; printf "2..." ; sleep 2 ; printf "1..." ; sleep 2 ; echo "Go."
fi


# Now check to see if we can access the S3 location.
# A failure is usually going to be one of three things... Either:
# 1) the remote S3 location doesn't exist (duh)
# 2) your STS credentials are expired or not set
# 3) your STS credentials are for a different AWS account
aws s3 ls "${S3_BUCKET_LOCATION}/" >/dev/null 2>&1
if [[ ${?} -ne 0 ]] ; then
	echo -e "\n# ***** Error: Can't do \"aws s3 ls ${S3_BUCKET_LOCATION}/\" *****"
	echo -e "# Check your STS token / session to be for \"${S3_BUCKET_ACCOUNT}\" and make sure that the remote location is valid for that account."
	[[ -n "${AWS_PROFILE}" ]] && echo "# (Your current STS session appears to be for \"${AWS_PROFILE}\")"
	exit 1
fi


# Output some (hopefully) useful summary info about what's about to happen
echo -e "\n####################################################################################################"
echo -e "# Local content:  $( /bin/pwd -P )"
echo -e "# Remote content: ${S3_BUCKET_ACCOUNT} ${S3_BUCKET_LOCATION}"
echo -e "####################################################################################################"
echo -e "\n# Doing a diff based on a dry run of the following \"aws s3 sync\":"
echo -e "aws s3 sync $( /bin/pwd -P ) ${S3_BUCKET_LOCATION} --dryrun"
echo -e "# (Run that command without the \"--dryrun\" to upload all the following changes to S3.)"
echo -e "# Note: Remote file may be reported by diff as '-' if not a text file"
# echo -e "\n# NOTE: The \"aws s3 sync\" and \"aws s3 cp\" examples are for copying _TO_ S3."
# echo -e "# To copy _FROM_ S3 to local, reverse the arguments.\n"

cumulativeDiffExit=0 		# This tracks our overall sucess / failure
foundAnyS3Differences="N" 	# This tracks if the "s3 sync" actually found anything different

# Here we go! First thing is to run an "s3 sync" dry run. Then we parse the output from that.
# Note we're adusting the output with 'tr' because the usual display of "s3 sync" over-writes
# a line of output that we want by sending a '\r'. It looks nice when you run it, but without 
# changing the CR to a NL we wouldn't get the 'grep' to work properly.
# Note the input to the 'while' loop is via process substitution, because bash would run a subshell
# if we were piping it in... and a subshell can't modify our 'cumulativeDiffExit' for tracking total diffs.
while read -r local remote ; do 
	foundAnyS3Differences="Y" 	# If we are actually running in the loop, "s3 sync" found at least one thing
	echo -e "#==============================================================================================================" 
	echo -e "< local file: ${local}"
	echo -e "> remote file: ${remote}\n"
	aws s3 ls "${remote}" >/dev/null 2>&1	# This checks if the remote object is there or not
	if [[ ${?} -eq 0 ]] ; then
		aws s3 cp "${remote}" - 2>/dev/null | diff "${local}" -	# The real work is done right here
		diffExit=${?}
		if [[ ${diffExit} -eq 0 ]] ; then
			echo -e "# Same (only the metadata differs)\n"
			if [[ "${COPY_FOR_METADATA}" == "Y" ]] ; then
				cpCommand="aws s3 cp ${local} ${remote}"
				echo "# Doing \"${cpCommand}\""
				sleep 3
				printf "# "		# This makes sure the output from the "s3 cp" looks like a comment
				eval "${cpCommand}"
			fi
		fi
	else
		echo -e "# Remote object not found"
		diffExit=1
	fi
	cumulativeDiffExit=$(( cumulativeDiffExit + diffExit ))
	[[ ${diffExit} -ne 0 ]] && echo -e "\n# To upload ONLY this file to S3, run the following while in $( /bin/pwd -P )/" &&
		echo "aws s3 cp ${local} ${remote}"
	echo -e "\n\n"
done < <( aws s3 sync . "${S3_BUCKET_LOCATION}" --dryrun 2>&1 | tr '\r' '\n' | grep -i upload | awk '{print $3,$5}' )

if [[ ${cumulativeDiffExit} -eq 0 ]] ; then
	echo -e "# ************ There were no differences found! ************ \n"
	if [[ "${foundAnyS3Differences}" != "N" ]] ; then
		echo -e "# Since all the objects above differ _only_ by metadata and NOT by content,"
		echo -e "# you can safely run the following sync command. (You need to remove the \"--dryrun\" yourself.)"
		echo -e "aws s3 sync $( /bin/pwd -P ) ${S3_BUCKET_LOCATION} --dryrun"
		echo -e "# This will update S3 so subsequent runs of this script won't show all the long output as just now.\n"
	fi
fi

# Remove the trap to exit as specified.
trap "" EXIT HUP INT QUIT TERM

[[ ${cumulativeDiffExit} -eq 0 ]] && exit 0
exit 1
