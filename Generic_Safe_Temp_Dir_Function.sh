#!/usr/bin/env bash

# by Stefan Wuensch 2016-06-08
# 
# This code can be dropped into any bash script for setting up a temporary
# directory. The directory will be created with a unique name on disk, and will
# be automatically removed (along with all the contents) when the script
# completes. Note that the "EXIT" being trapped will catch any exit of the 
# script that includes this code - not just user-generated signals like ^C.
# 
# This code assumes the global variable name WORKDIR will be the temporary directory.
# 
# Note: This file contains code to be included in other scripts. This code doesn't
# do anything useful all by itself. :-)



########################################################################################################
# Set up a unique working directory stored in $WORKDIR and a cleanup function.
# The working directory and all its contents will be removed on termination of this script.
# 
# The cleanup function will ONLY remove the working directory if:
#   - the directory name variable is NOT "/" (for obvious safety)
#   - the directory name to be removed starts with the same string as WORKDIRPREFIX (more safety)
# 
# Assumptions:
#   - the global variable $WORKDIR will be used for the absolute path to the working directory
#   - the signals HUP, INT, QUIT, TERM, EXIT will not be trapped by anything else
#   - if you do trap those signals for other purposes, you'll need to include "exit_cleanup"
# 
# Requirements:
#   - mktemp   https://www.mktemp.org/manual.html  (almost always included with modern *NIX distros)
#   - the filesystem / location which contains $WORKDIRPREFIX needs to be writable

WORKDIRPREFIX="/tmp" 	# Change this to whatever you want; should be absolute (starting with '/')
WORKDIRPREFIXLENGTH=$(( $( echo ${WORKDIRPREFIX} | wc -c ) - 1 ))	# Don't count the newline in the length

function exit_cleanup() {
	exitStatus="${?}" 	# This will snag the exit status of whatever triggered the EXIT 'trap'
	[[ -n "${1}" ]] && exitStatus="${1}" 	# However, an arg to this function takes precedence
	[[ -z "${exitStatus}" ]] && exitStatus=1 	# Set a default if there's nothing yet

	[[ -z "${WORKDIR}" ]] && echo "Error - no dir name received" && exit 1 	# dummy-check
	[[ "${WORKDIR}" == "/" ]] && echo "No I will not remove /" && exit 1 	# Most important safety check!

	# This conditional makes sure the $WORKDIR starts with the same string we set as the $WORKDIRPREFIX
	# If it doesn't, it's possible the variable $WORKDIR was modified in a way that could be dangerous. 
	[[ "$( echo ${WORKDIR} | head -c ${WORKDIRPREFIXLENGTH} )" != "${WORKDIRPREFIX}" ]] && 
				echo "Working dir ${WORKDIR} not expected - not removing" && 
				exit 1

	# Since the actual cleanup is 'rm -rf' (which is silent) we'll check to make sure 
	# the working directory actually exists - otherwise there'd be no notification of a problem.
	[[ ! -d "${WORKDIR}" ]] && echo "Error - working directory ${WORKDIR} not found!" && exit 1

	echo "" ; echo "${0} Exiting - cleaning up work dir ${WORKDIR}"
	rm -rf "${WORKDIR}"		# All the work up to this point is to do the '-rf' safely!
	trap "" HUP INT QUIT TERM EXIT 	# Clear the trap since we're done
	exit ${exitStatus}
}

# Make the actual directory, then make it private
WORKDIR="$( mktemp -d ${WORKDIRPREFIX}/$( basename ${0} )_XXXXXXXXXX 2>/dev/null )"
[[ -z "${WORKDIR}" ]] && echo "Error - problem creating working dir in ${WORKDIRPREFIX}" && exit 1
chmod 0700 "${WORKDIR}" || exit_cleanup 1 	# Use the chmod as a test to make sure the dir was created

# Set trapping of signals to call the cleanup function.
# Because "EXIT" is included, this will trap _any_ exit from the script which includes this code.
# You don't have to manually call "exit_cleanup" before "exit" this way. Yay!
trap "exit_cleanup 127" HUP INT QUIT TERM
trap "exit_cleanup" EXIT
# Note: the "EXIT" trap has no arg to the function because we want to operate on the exit status $?
# of the script. In other words if you call "exit 3" the last thing exit_cleanup() will do is exit with 3.
########################################################################################################

