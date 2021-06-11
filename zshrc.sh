# root directory where we are located
drop_dot_dir=$(dirname $0)

export ZPLUG_HOME=/usr/local/opt/zplug
source $ZPLUG_HOME/init.zsh

alias h=hippowatch.sh

alias ag="ag --hidden"


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
alias emacs=${drop_dot_dir}/bin/emacs

alias t=terraform

function diff {
     colordiff -u "$@" | less -RF
}

### ZSH
#ZSH_THEME="kolo"
ZSH_THEME="agnoster"


# Find backup directory
get.backup.dir() {
    dir=$(_find_source_root)
    if [ -z $dir ]; then
        echo "No backup in this tree."
    else
        echo "Backup root: $dir"
    fi
}

_find_source_root() {
    what_to_find=".backup.directory"

    path=$PWD
    while [[ "$path" != "" && ! -e "$path/$what_to_find" ]]; do
        path=${path%/*}
    done
    echo "$path"
}



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
# from https://github.com/ohmyzsh/ohmyzsh/blob/master/plugins/jump/jump.plugin.zsh
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
    \ls -l "$MARKPATH" |  tail -n +2 | sed 's/  / /g' | cut -d' ' -f9- |sort -k1 | awk -F ' -> ' '{printf "\033[01;36m%10s \033[00m-> \033[1m%s\n", $1, $2}' 
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
    ag --ignore "*~" "function $@\(\)" ${drop_dot_dir} $TOOLS_ROOT
}

# Convert simplified wildcard pattern to regex and grep a file listing using
# Silver Searcher (`brew install the_silver_searcher`)
lsgrep ()
{
    NEEDLE="$(echo $@|sed -E 's/\.([a-z0-9]+)$/\\.\1/'|sed -E 's/\?/./'| sed -E 's/[ *]/.*?/g')";
    ag --depth 3 -S -g "$NEEDLE" 2> /dev/null
}


# less
#LESSPIPE=`find /usr/local/Cellar | grep src-hilite-lesspipe.sh`
#LESSPIPE=`which src-hilite-lesspipe.sh`
#export LESSOPEN="| ${LESSPIPE} %s"
export LESS=' -R -X -F '


########
# git
source $drop_dot_dir/git.sh


######
# Docker, etc

if [ -e "/work/git/dotfiles/hippos" ]; then
    # load work files
    source /work/git/dotfiles/hippos/main.sh
    echo "[Loaded work dot files]"
else
    source $drop_dot_dir/docker.sh
    source $drop_dot_dir/kubernetes.sh
    source $drop_dot_dir/helm.sh
    source $drop_dot_dir/helm.db.sh
    source $drop_dot_dir/work.sh
    echo "[Loaded icloud dotfiles]"
fi

source $drop_dot_dir/work.dad.sh


