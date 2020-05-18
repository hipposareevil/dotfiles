# taken from:
# * http://techanic.net/2012/12/30/my_git_prompt_for_zsh.html
# * kolo

setopt prompt_subst

autoload -U colors && colors
autoload -Uz vcs_info

GIT_PROMPT_SYMBOL="%{$fg[blue]%}±"
GIT_PROMPT_PREFIX="%{$fg[green]%}[%{$reset_color%}"
GIT_PROMPT_SUFFIX="%{$fg[green]%}]%{$reset_color%}"
GIT_PROMPT_AHEAD="%B%F{green}>NUM%{$reset_color%}"
GIT_PROMPT_BEHIND="%B%F{orange}<NUM%{$reset_color%}"
GIT_PROMPT_MERGING="%{$fg_bold[magenta]%}MERGING%{$reset_color%}"
GIT_PROMPT_BISECT="%{$fg_bold[magenta]%}Bisect%{$reset_color%}"
GIT_PROMPT_CHERRY_PICKING="%{$fg_bold[magenta]%}Cherry-picking%{$reset_color%}"
GIT_PROMPT_UNTRACKED="%{$fg_bold[red]%}●%{$reset_color%}"
GIT_PROMPT_MODIFIED="%{$fg_bold[yellow]%}●%{$reset_color%}"
GIT_PROMPT_STAGED="%{$fg_bold[green]%}●%{$reset_color%}"

GIT_PROMPT_REBASE_MERGE_INTERACTIVE="%{$fg_bold[magenta]%}REBASE-i%{$reset_color%}"
GIT_PROMPT_REBASE_MERGE="%{$fg_bold[magenta]%}REBASE-m%{$reset_color%}"



# Show different symbols as appropriate for various Git repository states
parse_git_state() {
 if git rev-parse --git-dir > /dev/null 2>&1; then

  # Compose this value via multiple conditional appends.
  local GIT_STATE=""

  local NUM_BEHIND="$(git log --oneline ..@{u} 2> /dev/null | wc -l | tr -d ' ')"
  if [ "$NUM_BEHIND" -gt 0 ]; then
    GIT_STATE=$GIT_STATE${GIT_PROMPT_BEHIND//NUM/$NUM_BEHIND}
  fi

  local NUM_AHEAD="$(git log --oneline @{u}.. 2> /dev/null | wc -l | tr -d ' ')"
  if [ "$NUM_AHEAD" -gt 0 ]; then
    SPACE_IT=""
    if [ "$NUM_BEHIND" -gt 0 ]; then
      SPACE_IT=" "
    fi
    GIT_STATE=$GIT_STATE$SPACE_IT${GIT_PROMPT_AHEAD//NUM/$NUM_AHEAD}
  fi

  $(git rev-parse 2> /dev/null)
  result=$?
  if [ $result -eq 0 ]; then
      local GIT_DIR="$(git rev-parse --git-dir 2> /dev/null)"

      if [ -n $GIT_DIR ] && test -r $GIT_DIR/MERGE_HEAD; then
	  GIT_STATE=$GIT_STATE$GIT_PROMPT_MERGING
      fi
      if [ -n $GIT_DIR ] && test -r $GIT_DIR/CHERRY_PICK_HEAD; then
	  GIT_STATE=$GIT_STATE$GIT_PROMPT_CHERRY_PICKING
      fi
      if [ -n $GIT_DIR ] && test -r $GIT_DIR/BISECT_LOG; then
	  GIT_STATE=$GIT_STATE$GIT_PROMPT_BISECT
      fi
      
      if [ -n $GIT_DIR ] && test -r $GIT_DIR/rebase-merge/interactive; then
	  GIT_STATE=$GIT_STATE$GIT_PROMPT_REBASE_MERGE_INTERACTIVE
      elif [ -n $GIT_DIR ] && test -d $GIT_DIR/rebase-merge/; then
	  GIT_STATE=$GIT_STATE$GIT_PROMPT_REBASE_MERGE
      fi
      
      if [[ -n $(git ls-files --other --exclude-standard 2> /dev/null) ]]; then
	  GIT_STATE=$GIT_STATE$GIT_PROMPT_UNTRACKED
      fi
      
      if ! git diff --quiet 2> /dev/null; then
	  GIT_STATE=$GIT_STATE$GIT_PROMPT_MODIFIED
      fi
      
      if ! git diff --cached --quiet 2> /dev/null; then
	  GIT_STATE=$GIT_STATE$GIT_PROMPT_STAGED
      fi
      
      if [[ -n $GIT_STATE ]]; then
	  echo "$GIT_PROMPT_PREFIX$GIT_STATE$GIT_PROMPT_SUFFIX"
      fi
  fi
 fi
}


parse_weather() {
    weather=$(cat ~/weather/current.weather)

    if [ ! -z "${weather}" ]; then
       echo "${weather} "
    fi
}

# create branch information
parse_branch() {

  # check that we are in a git repo
  if git rev-parse --git-dir > /dev/null 2>&1; then
     currentBranch=$(git rev-parse --abbrev-ref HEAD)

     set -o pipefail
     upstreamBranch=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>&1 | grep -v "No upstream configured")
     returnCode=${PIPESTATUS[0]}
     if [ "$returnCode" -ne "0" ]; then
        upstreamBranch=" "
     fi

     # origin portion
     originString=""

     if [[ $upstreamBranch == origin/master ]];then
	 originString="%B%F{orange}(↑ master)%{$reset_color%} "
     elif [[ $upstreamBranch == master ]];then
	 originString="%B%F{orange}(master)%{$reset_color%} "
     elif [[ $upstreamBranch == origin/$currentBranch ]];then
	 # our branch, so print nothing
	 originString=""
     elif [[ $upstreamBranch == origin* ]];then
	 # someone else branch, so print !!
	 upbranch=${upstreamBranch/origin\//}
	 originString="%B%F{orange}[↑ ${upbranch}]%{$reset_color%} "
     fi

     echo "%B%F{green}[$currentBranch] $originString"
  fi
}


parse_clienv() {
   if [ ! -z ${CLI_TEST_HOME+x} ]; then
     val="%B%F{red}‡%{$reset_color%}" 
     echo -n "$val"
   fi
}

#DOCKER_TLS=1
#DOCKER_TLS_VERIFY=1
#DOCKER_HOST=tcp://willprogramforfood.com:2376
# parse env for docker variables
parse_docker_env() {
    if [ -z ${DOCKER_HOST} ]; then
        echo ""
        return
    else
        # get host
        docker_host=$(echo "$DOCKER_HOST" | sed s#tcp:..## | awk -F':' '{print $1}')
        if [[ $docker_host == *"willprogramforfood"* ]]; then
            docker_host="wpff"
        fi
        if [[ $docker_host == *"us.oracle.com"* ]]; then
            docker_host=$(echo "$docker_host" | sed s#.us.oracle.com##)
        fi
    fi

    echo "%B%F{black}¦$docker_host¦%{$reset_color%} "
}

parse_git_submodule() {
    ignoreme=$(cd "$(git rev-parse --show-toplevel 2>/dev/null)/.." && git rev-parse --is-inside-work-tree 2>/dev/null)
    if [ $? -eq 0 ]; then
        # in a submodule
        echo -n "§"
    fi
}

# Sparkline for git
parse_git_sparkline() {
 if git rev-parse --git-dir > /dev/null 2>&1; then

    $(type ack 2>&1 >/dev/null)
    if [ $? -ne 0 ]; then
        return 0
    fi
    $(type tac 2>&1 >/dev/null)
    if [ $? -ne 0 ]; then
        return 0
    fi
    $(type bc 2>&1 >/dev/null)
    if [ $? -ne 0 ]; then
        return 0
    fi

    # get username. use cut to get 2nd half of "user.name=foo bar"
    user=$(git config -l | grep "user.name" | cut -d '=' -f 2)

    sparkline=$(git log --author "$user"  --since=14.days --stat |ack '^ \d' |cut -f5,7 -d' ' |tr ' ' '+' |bc |tac |spark)
    echo "$sparkline"
 fi
}

# Kubernetes
prompt_kubecontext() {
  local context=$(kubectl config view -ojsonpath='{.current-context}')
  local namespace=$(kubectl config view -ojsonpath="{.contexts[?(@.name == '$context')].context.namespace}")
  local k8s_prefix="%{$fg_bold[blue]%}k8s:"
  local color="%{$fg[yellow]%}("

  if [[ -z "$namespace" ]]; then
    namespace="default"
  fi

  if [[ $namespace == *"prod"* || $namespace == "kube-system" ]]; then
      color="%{$fg[red]%}"
  fi

  echo " $k8s_prefix$color$context $namespace)%{$reset_color%}"
}


# proxy or not
parse_proxy() {
    if [ ! -z $http_proxy ]; then
        echo "[¶]"
    fi
}

# oke tunnel info
tunnel_env_file=/work/tunnel_env

parse_tunnel() {
    if [ -f $tunnel_env_file ]; then
      left=">>"
      right=">"
      # get tunnel info
      info=$(cat $tunnel_env_file)
      where=$(echo "$info" |  awk -F- '{print $2}')

      if [[ "${info}" =~ (prd) ]]; then
        echo -e "%{$fg[red]%}${left}PROD.${where}${right}%{$reset_color%} "
      fi
      if [[ "${info}" =~ (dev) ]]; then
        echo -e "%{$fg[blue]%}${left}Dev.${where}${right}%{$reset_color%} "
      fi
      if [[ "${info}" =~ (integ) ]]; then
        echo -e "%{$fg[green]%}${left}Integ.${where}${right}%{$reset_color%} "
      fi
    fi
}



setopt prompt_subst

#PROMPT='${ret_status} %{$fg[cyan]%}%c%{$reset_color%} $(prompt_kubecontext) $(parse_git_state)'
PROMPT='$(parse_weather)%{$fg[blue]%}$(parse_docker_env)$(parse_branch)%{$fg[white]%}%c%{$reset_color%}$(parse_git_state)$(parse_proxy)$(prompt_kubecontext)> '

#PREVPROMPT='$(parse_weather)%B%F{green}$(parse_docker_env)$(parse_tunnel)$(parse_branch)%B%F{white}%2c%{$reset_color%} $(parse_git_state)$(parse_proxy)> '

# OLD
#PROMPT='$(parse_weather)%B%F{green}$(parse_git_submodule)$(parse_branch)%B%F{white}%2c%{$reset_color%} $(parse_git_state)> '
#RPROMPT='$(parse_git_sparkline) $(parse_docker_env)'

autoload -U add-zsh-hook

