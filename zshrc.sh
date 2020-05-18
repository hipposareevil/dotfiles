
# root directory where we are located
drop_dot_dir=$(dirname $0)

function git_prompt_info() {
  ref=$(git symbolic-ref HEAD 2> /dev/null) || return
  echo "$ZSH_THEME_GIT_PROMPT_PREFIX${ref#refs/heads/}$ZSH_THEME_GIT_PROMPT_SUFFIX"
}

#alias ssh=$drop_dot_dir/ssh.sh
function title {
    echo -ne "\033]0;"$*"\007"
}


export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8


###
# emacs
alias emacs=~/Dropbox/dotfiles/bin/emacs

alias t=terraform

function diff {
     colordiff -u "$@" | less -RF
}

### ZSH
#ZSH_THEME="kolo"
ZSH_THEME="agnoster"


plugins=(git docker zsh-autosuggestions mvn)

export ZSH=$drop_dot_dir/.oh-my-zsh
source $ZSH/oh-my-zsh.sh

############
# zsh-auto
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=1'
ZSH_AUTOSUGGEST_STRATEGY=match_prev_cmd


# HISTORY stuff
export HISTSIZE=15000
HISTSIZE=15000
SAVEHIST=15000
HISTFILE=~/.history

unsetopt inc_append_history
unsetopt share_history

# Aliases
source $drop_dot_dir/.aliases


####################
# MARKS
export MARKPATH=$HOME/.marks
function jump() { 
    cd -P "$MARKPATH/$1" 2>/dev/null || echo "No such mark: $1"
}
function mark() { 
    mkdir -p "$MARKPATH"; ln -s "$(pwd)" "$MARKPATH/$1"
}
function unmark() { 
    /bin/rm -i "$MARKPATH/$1"
}
function marks() {
    \ls -l "$MARKPATH" | tail -n +2 | sed 's/  / /g' | cut -d' ' -f9- | awk -F ' -> ' '{printf "\033[01;36m%10s \033[00m-> \033[1m%s\n", $1, $2}'
}

function _completemarks {
  reply=($(ls $MARKPATH))
}

compctl -K _completemarks jump
compctl -K _completemarks unmark
# end MARKS
####################

# z / fasd (/usr/local/bin/fasd)
eval "$(fasd --init auto)"

# ls of zip files
function lsz() {
	if [ $# -ne 1 ]
	then
		echo "lsz filename.[tar,tgz,gz,zip,etc]"
		return 1
	fi
	if [ -f $1 ] ; then
		case $1 in
			*.tar.bz2|*.tar.gz|*.tar|*.tbz2|*.tgz) tar tvf $1;;
			*.zip)  unzip -l $1;;
			*)      echo "'$1' unrecognized." ;;
		esac
	else
		echo "'$1' is not a valid file"
	fi
}


###################
## proxy

function proxy() {

export HTTPS_PROXY=http://www-proxy-hqdc.us.oracle.com:80
export HTTP_PROXY=http://www-proxy-hqdc.us.oracle.com:80
export NO_PROXY=localhost,127.0.0.1,.us.oracle.com,.oraclecorp.com,/var/run/docker.sock,.grungy.us

export http_proxy=http://www-proxy-hqdc.us.oracle.com:80
export https_proxy=http://www-proxy-hqdc.us.oracle.com:80
export no_proxy=localhost,127.0.0.1,.us.oracle.com,.oraclecorp.com,/var/run/docker.sock,.grungy.us

  git config --global http.proxy http://rmdc-proxy.oracle.com:80
  git config --global https.proxy http://rmdc-proxy.oracle.com:80
  ALL_PROXY=$http_proxy
}

function unproxy() {
   unset https_proxy
   unset http_proxy
   unset HTTPS_PROXY
   unset HTTP_PROXY
   ALL_PROXY=""
   git config --global --unset https.proxy
   git config --global --unset http.proxy
}

## end proxy
###################

# BD reverse cd
. $drop_dot_dir/.zsh/plugins/bd/bd.zsh

# colors
CYAN='\033[01;36m'
BOLD='\033[1m'
NONE='\033[00m'

########
# bmarks, marker
[[ -s "$drop_dot_dir/.marker/marker.setup" ]] && source "$drop_dot_dir/.marker/marker.setup"

# mark with ctrl +  \
marker_key_mark="${MARKER_KEY_MARK:-\C-[}"
marker_key_get="${MARKER_KEY_GET:-\C-@}"
marker_key_next_placeholder="${MARKER_KEY_NEXT_PLACEHOLDER:-\C-t}"

# list markers
function bmarks {
    echo "Command marks: [${MARKER_DATA_HOME}marks.txt]"
    while read line; do
	command=$(echo "$line" | awk -F'##' '{print $1}')    
	name=$(echo "$line" | awk -F'##' '{print $2}')
	echo -en "${CYAN}"
	printf '%10s' "$name"
	echo -en "${NONE}"
	echo -e "  ${BOLD}$command ${NONE}"
    done < $MARKER_DATA_HOME/marks.txt
}


function wich() {
    which $@
    echo "Finding location of function...."
    # look in dropbox and tools/utils
    ag --ignore "*~" "function $@\(\)" ~/Dropbox $TOOLS_ROOT
}

# Convert simplified wildcard pattern to regex and grep a file listing using
# Silver Searcher (`brew install the_silver_searcher`)
lsgrep ()
{
    NEEDLE="$(echo $@|sed -E 's/\.([a-z0-9]+)$/\\.\1/'|sed -E 's/\?/./'| sed -E 's/[ *]/.*?/g')";
    ag --depth 3 -S -g "$NEEDLE" 2> /dev/null
}


# less
LESSPIPE=`find /usr/local/Cellar | grep src-hilite-lesspipe.sh`
#LESSPIPE=`which src-hilite-lesspipe.sh`
export LESSOPEN="| ${LESSPIPE} %s"
export LESS=' -R -X -F '


########
# OKE
source $drop_dot_dir/oke.sh

########
# git
source $drop_dot_dir/git.sh

########
# docker
source $drop_dot_dir/docker.sh

#######
# maven
function m.core {
    echo "Changing maven for core."
    cp ~/.m2/settings.xml.core  ~/.m2/settings.xml
}

function m.einstein {
    echo "Changing maven for einstein."
    cp ~/.m2/settings.xml.e1  ~/.m2/settings.xml
}


########
# Kubernetes
source $drop_dot_dir/kubernetes.sh

vaultsel () {
	local vaults vault_ldap_user
	vault_ldap_user="samuel.jackson" 
	vaults=("https://vault-ops.build-usw2.platform.einstein.com" "https://vault.build-usw2.platform.einstein.com" "https://vault.dev.platform.einstein.com" "https://vault.staging.platform.einstein.com" "https://vault.rc.platform.einstein.com" "https://vault.prod.platform.einstein.com" "https://vault.rc-euc1.platform.einstein.com" "https://vault.prod-euc1.platform.einstein.com" "https://vault.perf-usw2.platform.einstein.com") 
	VAULT_ADDR=$(printf '%s\n' "${vaults[@]}" | fzf) 
	export VAULT_ADDR
	unset VAULT_TOKEN
	if ! vault token lookup > /dev/null 2>&1
	then
		vault login -no-print -method="ldap" username="$vault_ldap_user"
	fi
	VAULT_TOKEN=$(vault print token) 
	export VAULT_TOKEN
	echo "Switched to Vault cluster \"${VAULT_ADDR}\""
}



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
