
#######
# dad access

function _dad.query {
    scope=$1
    who=$2

    result=$(dad list ${scope} | grep ${who})
    local code=$?
    echo ""
    echo "** ${scope} **"
    if [ $code -eq 0 ]; then
        echo "$result"
        echo "[[ SUCCESS ]]"
    else
        echo "No access for '${who}' in '${scope}'."
        echo "Double checking..."
        # double check with second dad call
        second_result=$(dad check ${scope} ${who})
        code=$?
        if [ $code -eq 0 ]; then
            echo "Access for '${who}' exists for '${scope}'"
            echo "[[ SUCCESS ]]"
        else
            echo "For sure no acccess for '${who}' in '${scope}'"
            echo "[[ Failure ]]"
        fi
    fi
}

# query access for the incoming user against all 3 scopes
function dad.query {
    who=$1

    # get environment
    local env=$(head -1 ~/.dad/credentials)  
    env=$(echo "$env" | awk -F= '{print $2}')

    echo "Looking for enabled scopes for \"${who}\" in environment [${env}]"

    _dad.query "internalApi" ${who}
    _dad.query "internalApiRead" ${who}
    _dad.query "internalApiCredentials" ${who}
}

# Add incoming user to scope
function _dad.add {
    scope=$1
    who=$2

    echo "** Adding '${who}' to scope '${scope}'**"
    result=$(dad member ${scope} add ${who})
    echo "${result}"
    echo ""
}


# Add the incoming user to all 3 scopes
function dad.add_all {
    who=$1

    # get environment
    local env=$(head -1 ~/.dad/credentials)  
    env=$(echo "$env" | awk -F= '{print $2}')

    _dad.add "internalApi" ${who}
    _dad.add "internalApiRead" ${who}
    _dad.add "internalApiCredentials" ${who}
}


# Delete incoming user from scope
function _dad.nuke {
    scope=$1
    who=$2

    echo "** Deleting '${who}' from scope '${scope}'**"
    result=$(dad member ${scope} delete ${who})
    echo "${result}"
    echo ""
}


# Delete the incoming user from all 3 scopes
function dad.nuke_all {
    who=$1

    # get environment
    local env=$(head -1 ~/.dad/credentials)  
    env=$(echo "$env" | awk -F= '{print $2}')

    _dad.nuke "internalApi" ${who}
    _dad.nuke "internalApiRead" ${who}
    _dad.nuke "internalApiCredentials" ${who}
}
