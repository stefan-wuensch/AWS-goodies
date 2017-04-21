#!/usr/bin/env bash

# final-build-with-EFS.sh
# To be called by Launch Config User Data.
# This script only contains EFS mounting code, so
# it should be used as a starting point.


echo "#####################################################################################"
echo "Starting ${0} at $( date )"

# These two lines help identify this script version for matching S3 with Bitbucket
ls -l "${0}"
md5sum "${0}"




########################################################################################################################
########################################################################################################################
# Start - Mount EFS (NFS) export
#
# by Stefan Wuensch January 2017
#
# Validated with https://www.shellcheck.net/
#
# 2017-01-19 manual example for EFS mounting
# mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 fs-3280247b.efs.us-east-1.amazonaws.com:/ /data-efs
#
# Changes
# 2017-03-28: 	Added EFS name suffix to allow mounting multiple EFS on one instance
# 		Make MOUNTPOINT variable all caps to indicate it never changes after assignment
# 		Improve error checking & error messages; add more comments
# 		Add check for EFS hostname in DNS
#
#
# Notes on EFS
# https://docs.aws.amazon.com/efs/latest/ug/mounting-fs-mount-cmd-dns-name.html
# https://docs.aws.amazon.com/efs/latest/ug/mount-fs-auto-mount-onreboot.html
# https://docs.aws.amazon.com/efs/latest/ug/mounting-fs-mount-cmd-general.html
#
# IMPORTANT:
# The ONLY things you should need to change in this entire block of code
# doing the EFS mount are:
# 1) The "DNSZONE" variable 	(example value: "campusservices.cloud.huit.harvard.edu")
# 2) The "MOUNTPOINT" variable 	(example value: "/data")
# 3) The "EFSNAMESUFFIX" variable (example value: "backup" but it can be null "")
# Everything else comes from EC2 Instance Tags.
#
# Required EC2 Tags on the Instance:
#  product	(example value: "maximo")
#  environment	(example value: "prod")
#
# Example EFS Mount Target DNS name constructed from the example values above,
# if the instance was in AZ us-east-1b:
#   us-east-1b.maximo-prod-efs-backup.prod.campusservices.cloud.huit.harvard.edu
#
# NOTE: most likely you will have to manually create a Route 53 A record
# for the Mount Target in EACH AZ, until Amazon adds the ability to make
# a Route 53 Alias to EFS.
#
# Also note: Since DNS is not case-sensitive, the values of the "product" and
# "environment" tags are not case-sensitive (for this purpose) either!
# It could be "prod" or "Prod" or "PROD" because DNS doesn't care.
# However, the tag Name IS case-sensitive. Because of that, note that the
# two "aws ec2 describe-tags" calls each have a match string for the Value
# which allows for the first letter to be upper or lower case.
# Those filters for Key Name are "Values=?nvironment" and "Values=?roduct".
# If you get "not found" errors from those, make sure your Key Name is
# either "Environment" or "environment" for example.



############ Only change these three variables #########################################################################
DNSZONE="campusservices.cloud.huit.harvard.edu"		# Change this as needed - MUST end with TLD like .edu, .com
MOUNTPOINT="/data"					# Change this as needed - MUST begin with a slash "/"
EFSNAMESUFFIX="backup"					# Change this as needed - only allowed: [a-z], dash "-", null ""
############ Only change these three variables #########################################################################



echo -e "\n\nStarting EFS for ${MOUNTPOINT} setup section of ${0} at line $LINENO $( date )\n"
exitError=0
FSTAB="/etc/fstab"

# The previous EFS AZ mount target might be mounted from the fstab entries
# if they were "baked" into the AMI, so we absolutely must unmount it.
# If we didn't, we'd probably get an overlay mount which is bad news.
umount -f "${MOUNTPOINT}"


# jq is used in the parsing of instance meta-data "instance-identity" for the
# region. If jq can't be installed, the AWS_DEFAULT_REGION will be obtained
# by parsing the AZ. We probably need jq for other things anyway though.
yum --enablerepo=hcdo -y install jq


# Template for the format of the EFS File System host name
# The replacement strings get removed and values from EC2 Instance Tags & user-defined variables put in their place.
# Example: maximo-prod-efs-backup.prod.campusservices.cloud.huit.harvard.edu
# The AZ name is prepended later.
EFShostnameBase="APPNAME-APPENV-efs-SUFFIX.APPENV.${DNSZONE}"
EFShostnameBaseNameReplacement="APPNAME"
EFShostnameBaseEnvReplacement="APPENV"
EFShostnameBaseSuffixReplacement="SUFFIX"
# Next we have to adjust the suffix-replacement string to handle cases where:
# 1) the EFSNAMESUFFIX is null ("") which means we have to drop the last dash from the EFShostnameBase
# 2) the EFSNAMESUFFIX starts with a dash which means we have to make sure we don't end up with
# 	two dash characters before the suffix.
if [[ -z "${EFSNAMESUFFIX}" ]] || [[ "$( echo ${EFSNAMESUFFIX} | cut -c1 )" == "-" ]] ; then
	EFShostnameBaseSuffixReplacement="-${EFShostnameBaseSuffixReplacement}"
fi
# If we didn't do the previous conditionals to possibly modify EFShostnameBaseSuffixReplacement,
# we might end up with hostnames that look like:
#   maximo-prod-efs-.prod.campusservices.cloud.huit.harvard.edu
#   maximo-prod-efs--backup.prod.campusservices.cloud.huit.harvard.edu
# ...which are clearly bogus.

myName=$(basename "${0}")
AWSrecommendedMountOptions="nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2"
fstabMatchingString="comment=this-line-inserted-by-${myName}-for-${MOUNTPOINT}"	# this is how we find any previous entry
NFSmountOptions="${AWSrecommendedMountOptions},${fstabMatchingString}"

mkdir "${MOUNTPOINT}"
if [[ ! -d "${MOUNTPOINT}" ]] ; then
	echo "ERROR prior to line $LINENO - Could not make directory for mount point \"${MOUNTPOINT}\"!"
	exitError=$(( exitError + 1 ))
fi

myAZ=$( curl --silent http://169.254.169.254/latest/meta-data/placement/availability-zone )
if [[ -z "${myAZ}" ]] ; then		# Only proceed if we did get our AZ!!
	echo "ERROR prior to line $LINENO - Could not get our AZ from EC2 meta-data so we can't mount ${MOUNTPOINT} with EFS export!"
	exitError=$(( exitError + 1 ))
fi

# First get our EC2 instance ID so we can use that to query for other meta-data
myID=$( curl --silent http://169.254.169.254/latest/meta-data/instance-id )
if [[ -z "${myID}" ]] ; then		# Only proceed if we did get our ID!!
	echo "ERROR prior to line $LINENO - Could not get our Instance ID from EC2 meta-data so we can't get our environment tag!"
	exitError=$(( exitError + 1 ))
fi

AWS_DEFAULT_REGION="us-east-1"		# Set this as a default in case we fail to get the region dynamically below.

# Now go get our actual region. (Planning ahead for a time when we're not only in us-east-1!)  :-)
if [[ -n "$( which jq 2>/dev/null )" ]] ; then
	# We have jq installed
	tryWithJQ=$( curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document | jq '.region' | cut -d'"' -f2 )
	[[ -n "${tryWithJQ}" ]] && AWS_DEFAULT_REGION="${tryWithJQ}"		# Only if we got something back do we use it.
else
	# We don't have jq, so we'll try formatting the JSON with the Python tool.
	tryWithPython=$( curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document | python -m json.tool | grep -i region | awk '{print $2}' | cut -d'"' -f2 )
	[[ -n "${tryWithPython}" ]] && AWS_DEFAULT_REGION="${tryWithPython}"	# Only if we got something back do we use it.
fi

if [[ -z "${AWS_DEFAULT_REGION}" ]] ; then	# Even though we initialized this variable, if the 'curl' attempts fail we still might end up with null. Just being careful.
	echo "ERROR prior to line $LINENO - Could not get our AWS Region from EC2 meta-data so we can't get our tags by using the AWS CLI!"
	exitError=$(( exitError + 1 ))
else
	export AWS_DEFAULT_REGION		# Yay we got a region string so now we export it for the AWS CLI to use.
fi

# Get my "environment" tag value (looking at "myself" via ${myID})
myEnvironment=$( aws ec2 describe-tags --filters "Name=resource-id,Values=${myID}" "Name=resource-type,Values=instance" "Name=key,Values=?nvironment" --query 'Tags[*].Value' --output=text )
if [[ -z "${myEnvironment}" ]] ; then
	echo "ERROR prior to line $LINENO - Could not get our application environment from EC2 instance Tags so we can't build the EFS hostname!"
	exitError=$(( exitError + 1 ))
fi

# Get my "product" tag value (looking at "myself" via ${myID})
myAppName=$( aws ec2 describe-tags --filters "Name=resource-id,Values=${myID}" "Name=resource-type,Values=instance" "Name=key,Values=?roduct" --query 'Tags[*].Value' --output=text )
if [[ -z "${myAppName}" ]] ; then
	echo "ERROR prior to line $LINENO - Could not get our application name from EC2 instance Tags so we can't build the EFS hostname!"
	exitError=$(( exitError + 1 ))
fi

# Now that we finally (hopefully!) have all the metadata we need, replace the parts of the template EFShostnameBase with
# the metadata.
EFShostname=$( echo ${EFShostnameBase} | sed -e "s/${EFShostnameBaseNameReplacement}/${myAppName}/g" -e "s/${EFShostnameBaseEnvReplacement}/${myEnvironment}/g" -e "s/${EFShostnameBaseSuffixReplacement}/${EFSNAMESUFFIX}/g" )
EFShostname="${myAZ}.${EFShostname}"
echo "I constructed EFShostname \"${EFShostname}\""

# Check to make sure that constructed hostname is really out there in DNS!
# If it's not, you might think we would bail out here. Nope - we'll continue to the
# bitter end in case the upcoming $fstabTEMP might be useful for debugging.
if ! host "${EFShostname}" ; then
	echo "ERROR prior to line $LINENO - Could not find \"${EFShostname}\" in DNS! Did you make the Route53 record like you were supposed to do???"
	exitError=$(( exitError + 1 ))
fi

fstabTEMP=$( mktemp -t "${myName}_XXXXXXXXX" 2>/dev/null )				# We have to have a safe temporary file name
grep -v "${fstabMatchingString}" "${FSTAB}" > "${fstabTEMP}"				# Keep everything but the one from last time
echo "${EFShostname}:/ ${MOUNTPOINT} nfs ${NFSmountOptions} 0 0" >> "${fstabTEMP}" 	# Add the new / current mount. For EFS shares it's always just '/'

# Example of what was just done:
# echo "us-east-1b.maximo-prod-efs-backup.prod.campusservices.cloud.huit.harvard.edu:/ /data nfs nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,comment=this-line-inserted-by-final-build.sh 0 0" >> /etc/fstab

# If we had any errors above, we can't properly modify the fstab!
if [[ ${exitError} -eq 0 ]] ; then
	if [[ -s "${fstabTEMP}" ]] ; then		# Only continue if the temp file has stuff in it!
		cp -f -p "${FSTAB}" "${FSTAB}.prev"	# Make a backup
		cat "${fstabTEMP}" > "${FSTAB}"		# This preserves the owner / group / mode
		diff -q "${fstabTEMP}" "${FSTAB}" >/dev/null && rm -f "${fstabTEMP}"	# If something weird happened, keep the temp file
	fi
	echo "$( date ) - added the following line to ${FSTAB}:"
	grep "${fstabMatchingString}" ${FSTAB}		# Show what we did so it gets into the logs
else
	echo "SKIPPING the update to ${FSTAB} because there were ${exitError} errors in trying to gather the values."
	echo "However, there may be something helpful for troubleshooting in the temp file ${fstabTEMP}"
fi

# We're still going to try and mount it in case there was a line in fstab already somehow.
# Note we're not using "$?" per the advice of ShellCheck https://github.com/koalaman/shellcheck/wiki/SC2181
if ! mount "${MOUNTPOINT}" ; then
	echo "Error mounting ${MOUNTPOINT}"
else
	echo "${MOUNTPOINT} mounted OK"
fi

echo -e "\nEnd of EFS setup section of ${0} at line $LINENO \n\n"

# End - Mount EFS (NFS) export
########################################################################################################################
########################################################################################################################




echo "Finished ${0} at $( date )"
echo "#####################################################################################"
