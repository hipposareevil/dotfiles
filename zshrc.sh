
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


####
# tmux
alias t=tmux


function diff {
     colordiff -u "$@" | less -RF
}

### ZSH
#ZSH_THEME="kolo"
ZSH_THEME="agnoster"

plugins=(git docker zsh-autosuggestions)

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
