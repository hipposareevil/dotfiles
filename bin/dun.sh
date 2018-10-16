#!/bin/bash

# Utility to copy merged (conflicted) files into a shared area.  It will keep track of who has
# finished which file via the DONE_FILE.  A lock file is used to coordinate copying of files over.
#
# The command 'dun.sh init' should be run from the merging branch before anything is copied over:
# $ dun.sh init
# It will create list of conflicted files to be resolved.

# This command must be run from the merging branch before files are copied over:
# > 
# It creates original list of files to merge and a working copy (done.txt)

# remote machine
REMOTE="slc05hfh"

# root git directory
ROOT_DIR="/scratch/sjackson/mydev/drm/nimbula/exalogic-controlplane"

# working directory for dun
WORKING_DIR="/scratch/sjackson/dun"

# file with list of files to be manually merged
DONE_FILE="${WORKING_DIR}/done.txt"
# delimiter between user & file (in DONE_FILE)
DELIM=":"

# file with list of top level directories that are in use.
# format is "directory : user"
RESERVED_FILE="${WORKING_DIR}/reserved.txt"

# lockfile on remote machine
LOCKFILE="$WORKING_DIR/mergeit.lock"

ERROR="[ERROR]->"

GREP="/bin/grep"

if [ -z "$SSHUSER" ]; then
  SSHUSER=$USER    
fi


error()
{
  echo "Usage: $0 file/to/scp "
  echo " [-mine] [-localmine] [-others] [-todo] "
  echo " [-reserve <directory>]  [-unreserve <directory>] [-rmlock] [-compare]"
  echo " [-init]"
  echo ""
  echo "* -mine : lists all files modified by me"
  echo "* -localmine : lists all files modified by me locally (not on remote server)"
  echo "* -others : lists all files modified by everyone else"
  echo "* -todo : lists all remaining files"
  echo "* -listReserved: list reserved directories"
  echo "* -reserve <directory> : reserve a directory so others won't clobber it"
  echo "* -unreserve <directory> : unreserve a directory so others can now clobber"
  echo "* -rmlock : manually remove lock file"
  echo "* -compare : compare local git changes to those on remote"
  echo "* -init: initialize files on server side.  Should only be done once."
  echo ""
  echo "Mandatory environment variable(s):"
  echo "* SSHUSER - SSH as this user to the machine '$REMOTE', "
  echo "          name also used to mark the file as completed."
  echo ""
  echo "* SSH keys must be enabled for the SSHUSER for machine '$REMOTE'."
  echo ""
}

# get list of files I've updated locally.
listLocal() {
    remaining=$(git diff --name-only --diff-filter=U)
    # MERGE_MSG has 3 lines of stuff we don't want on top

    original_temp=$(tail -n +4 .git/MERGE_MSG)
    # remove leading tab spaces
    original=${original_temp//	/}
    # get the diff and sort out non ">" and "<"
    diff=$(diff <(echo "$remaining" | sort | tr -d ' ') <(echo "$original" | sort | tr -d ' ') | egrep "<|>")

    echo "$diff"
}


# print out files we've done locally but not remote
compareLocalRemote() {
    # local will have ">"'s
    local=$(listLocal)
    local=${local//> /}
    remote=$(listMine)
#    echo $local
#    echo $remote

    diff=$(diff <(echo "$local") <(echo "$remote")| egrep "<|>" | sort)
    echo "< are files we've done locally, but are not on SLC."
    echo "> are files on SLC that we haven't done."
    echo "----------------"
    echo "$diff"
}

# reserve a directory
reserveDirectory() {
    directory=$1
    if [ -z "$directory" ]; then
	error
	exit -1
    fi

    echo -n "Reserving ${directory}..."

    # get the lock
    getLock

    # see if directory is reserved
    result=$(ssh $SSHUSER@$REMOTE "${GREP} -i $directory ${RESERVED_FILE}")
    if [ $? -eq 0 ]; then
	# directory is reserved, name is 2nd portion of line
	name=$(echo $result | awk '{split($0,a,":"); print a[2]}' | tr -d ' ')
	echo ""
	echo "${ERROR} Directory $directory already reserved by ${name}."
	removeLock
	exit -1
    fi

    # OK to reserve directory now
    result=$(ssh $SSHUSER@$REMOTE "echo '$directory ${DELIM} ${SSHUSER}' >> ${RESERVED_FILE}")
    if [ $? -eq 0 ]; then
	echo "Reserved $directory for ${SSHUSER}"
    else
	echo ""
	echo "${ERROR} reserving $directory for ${SSHUSER}: $result"
    fi

    removeLock    
}

# unreserve a directory
unreserveDirectory() {
    directory=$1
    if [ -z "$directory" ]; then
	error
	exit -1
    fi

    echo -n "Unreserving ${directory}..."

    # get the lock
    getLock

    # see if directory is truly reserved
    result=$(ssh $SSHUSER@$REMOTE "${GREP} -i $directory ${RESERVED_FILE}")
    code=$?
    if [ $code -ne 0 ]; then
	# directory is not reserved
	echo ""
	echo "${ERROR} Directory $directory is not reserved!"
#debug	echo "> $result <"
	removeLock
	exit -1
    fi

    # check who owns the reservation
    name=$(echo $result | awk '{split($0,a,":"); print a[2]}' | tr -d ' ')
    if [ "${name}" != "${SSHUSER}" ]; then
	echo ""
	echo "${ERROR} ${directory} is owned by ${name}"
	removeLock
	exit -1
    fi
    
    

    # OK to unreserve directory now
    result=$(ssh $SSHUSER@$REMOTE "${GREP} -iv '$directory $DELIM' ${RESERVED_FILE} >> temp && mv temp ${RESERVED_FILE}")

    echo ""
    echo "Unreserved $directory for ${SSHUSER}"

    removeLock    
}

# list directory reservations
listReservedDirectories() {
    result=$(ssh $SSHUSER@$REMOTE "sort ${RESERVED_FILE}")

    echo "Reserved directories:"
    echo "$result"
}

# see if incoming file has been worked on already or is reserved
okToWorkOnFile() {
    fileToCheck=$1

    echo -n "Checking permissions for file '${fileToCheck}'..."

    # get lock
    getLock

    # check if file is already been worked on
    result=$(ssh $SSHUSER@$REMOTE "${GREP} \"${DELIM} \" $DONE_FILE | tr -d ' ' | grep $fileToCheck")
    if [ $? -eq 0 ]; then
	# file has already been worked on
	name=$(echo $result | awk '{split($0,a,":"); print a[1]}')
	echo ""
	echo "${ERROR} File $fileToCheck has already been worked on by $name"
	removeLock
	exit 0
    fi
    echo -n "file level is OK..."

    # Check if file is reserved.  Get the name of top level directory
    directory=$(echo $fileToCheck | awk -F/ '{print $1}')

    result=$(ssh $SSHUSER@$REMOTE "${GREP} -i $directory ${RESERVED_FILE}")
    if [ $? -eq 0 ]; then
	# file exists in reserved section, get name of owner
	# if owner is us, we're ok.  If not, error out
	name=$(echo $result | awk '{split($0,a,":"); print a[2]}' | tr -d ' ')
	if [ "${name}" != "${SSHUSER}" ]; then
	    echo ""
	    echo "${ERROR} ${name} is owner of ${directory}.  Can't copy over file ${fileToCheck}."
	    removeLock
	    exit -1
	fi
    fi

    echo "group level is OK."
    
    # cleanup
    removeLock    
}

# get files I have finished
listMine() {
    result=$(ssh $SSHUSER@$REMOTE "${GREP} \"${SSHUSER}${DELIM} \" $DONE_FILE | tr -d ' '")
    # remove the name
    result_string=${result//${SSHUSER}${DELIM}/}
    echo "$result_string"
}

# get files others have vinished
listOthers() {
    result=$(ssh $SSHUSER@$REMOTE "${GREP} -v \"${SSHUSER}${DELIM} \" $DONE_FILE | grep \"$DELIM\"")
    # remove the name
    result_string=${result//${SSHUSER}${DELIM} /}
    echo "$result_string"
}

# get files left to do
listTodo() {
    result=$(ssh $SSHUSER@$REMOTE "${GREP} -v \"${DELIM} \" $DONE_FILE")
    echo "$result"
}

# get lock
getLock() {
   ssh $SSHUSER@$REMOTE "lockfile -r 0 $LOCKFILE || exit 66"
   error=$?
   if [ $error -ne 0 ]; then
       echo "${ERROR} Unable to get lockfile ($error), please try again shortly."
       exit 1
   fi
}


# remove lock file.  
removeLock() {
    ssh $SSHUSER@$REMOTE "/bin/rm  $LOCKFILE || exit 66"
    error=$?
    if [ $error -ne 0 ]; then
        echo "Unable to get remove lockfile ($error), please try again shortly."
        exit 1
    fi
}


# initialize the files on the server where shared git repo is
initialize() {
    echo "Initializing.."
    git diff --name-only --diff-filter=U > ${WORKING_DIR}/conflicted.files
    cp ${WORKING_DIR}/conflicted.files ${DONE_FILE}
    touch ${RESERVED_FILE}
    echo "done!"
}


######################################
# main
if [ $# -eq 0 ]; then
 error   
fi
arg=$1

for arg in $@
do
  case $arg in
    "-help"|"--help")
     error
     exit 0
     ;;


    "-init")
    initialize
    exit 0
    ;;

    "-localmine")
    echo "LOCAL files I've completed:"
    listLocal
    exit 0
    ;;

    "-compare")
    compareLocalRemote
    exit 0
    ;;

    "-listReserved")
    listReservedDirectories
    exit 0
    ;;

    "-reserve")
    shift
    reserveDirectory $1
    exit 0
    ;;

    "-unreserve")
    shift
    unreserveDirectory $1
    exit 0
    ;;

    "-mine")
     echo "Files I've completed:"
     listMine
     exit 0
     ;;

    "-others")
     echo "Files others have completed:"
     listOthers
     exit 0
     ;;

    "-rmlock")
     echo "Removing lock file"
     removeLock
     exit 0
     ;;

    "-todo")
     echo "Files todo:"
     listTodo
     exit 0
     ;;

    -*)
        echo $arg is an illegal option
     error
     break
     ;;

   esac
done


########
# start 
fileToCopy=$arg

# 00- see if someone has already completed this file, or if it's reserved via directory name
okToWorkOnFile $fileToCopy


# 0- get lock file
getLock
echo -n "got lock..."

# 1- scp to remote area
scp $fileToCopy $SSHUSER@$REMOTE:$ROOT_DIR/$fileToCopy  > /tmp/copyfile 2>&1
error=$?

if [ $error -ne 0 ]; then
    echo ""
    echo "${ERROR} Unable to copy file to remote machine: "
    cat /tmp/copyfile
    removeLock
    exit $error
fi

echo -n "copied file..."

# 2- add file to git
ssh $SSHUSER@$REMOTE "cd $ROOT_DIR; git add $ROOT_DIR/$fileToCopy"

echo -n "added file..."

# 3- mark this file as done
ssh $SSHUSER@$REMOTE "perl -ane 's#$fileToCopy#'$SSHUSER'$DELIM $fileToCopy#; print ' $DONE_FILE > /tmp/dun_file; cp /tmp/dun_file $DONE_FILE "

echo -n "marked dun..."

# x- remove lock file
removeLock

echo "lock removed. Done!"


# done
