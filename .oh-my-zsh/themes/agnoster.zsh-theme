# vim:ft=zsh ts=2 sw=2 sts=2
#
# agnoster's Theme - https://gist.github.com/3712874
# A Powerline-inspired theme for ZSH
#
# # README
#
# In order for this theme to render correctly, you will need a
# [Powerline-patched font](https://github.com/Lokaltog/powerline-fonts).
#
# In addition, I recommend the
# [Solarized theme](https://github.com/altercation/solarized/) and, if you're
# using it on Mac OS X, [iTerm 2](http://www.iterm2.com/) over Terminal.app -
# it has significantly better color fidelity.
#
# # Goals
#
# The aim of this theme is to only show you *relevant* information. Like most
# prompts, it will only show git information when in a git working directory.
# However, it goes a step further: everything from the current user and
# hostname to whether the last call exited with an error to whether background
# jobs are running in this shell will all be displayed automatically when
# appropriate.

### Segment drawing
# A few utility functions to make it easy and re-usable to draw segmented prompts

CURRENT_BG='NONE'
SEGMENT_SEPARATOR=''

# Begin a segment
# Takes two arguments, background and foreground. Both can be omitted,
# rendering default background/foreground.
prompt_segment() {
  local bg fg
  [[ -n $1 ]] && bg="%K{$1}" || bg="%k"
  [[ -n $2 ]] && fg="%F{$2}" || fg="%f"
  if [[ $CURRENT_BG != 'NONE' && $1 != $CURRENT_BG ]]; then
    echo -n " %{$bg%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR%{$fg%} "
  else
    echo -n "%{$bg%}%{$fg%} "
  fi
  CURRENT_BG=$1
  [[ -n $3 ]] && echo -n $3
}

# End the prompt, closing any open segments
prompt_end() {
#  echo ""
  if [[ -n $CURRENT_BG ]]; then
    echo -n " %{%k%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR"
  else
    echo -n "%{%k%}"
  fi
  echo -n "%{%f%}"
  CURRENT_BG=''
}


# Dir: current working directory
prompt_dir() {
  echo ""
  prompt_segment blue black '%2c'
}


### Prompt components
# Each component will draw itself, and hide itself if no information needs to be shown

# Context: user@hostname (who am I and where am I)
prompt_context() {
  if [[ "$USER" != "$DEFAULT_USER" || -n "$SSH_CLIENT" ]]; then
    prompt_segment black default "%(!.%{%F{yellow}%}.)$USER@%m"
  fi
}


prompt_git() {
  local ref dirty
  if $(git rev-parse --is-inside-work-tree >/dev/null 2>&1); then
    dirty=$(parse_git_dirty)

    if [[ $SHOW_STASH_SEGMENT -eq 1 ]]; then
        stash_size=$(git stash list | wc -l | tr -d ' ')
        if [[ stash_size -ne 0 ]]; then
            prompt_segment white black
            echo -n "+${stash_size}"
        fi
    fi

	ref=$(git symbolic-ref HEAD 2> /dev/null)
	if [[ -z $ref ]]; then
	  detached_head=true;
	  ref="$(git show-ref --head -s --abbrev |head -n1 2> /dev/null)";
	  ref_symbol="➦"
	else
	  detached_head=false;
	  ref=${ref/refs\/heads\//}
	  ref_symbol=""
	fi

    remote=${$(git rev-parse --verify ${hook_com[branch]}@{upstream} --symbolic-full-name 2>/dev/null)/refs\/remotes\/}
    if [[ -n ${remote} ]] ; then
      ahead=$(git rev-list ${hook_com[branch]}@{upstream}..HEAD 2>/dev/null | wc -l | tr -d ' ')
      displayed_ahead=" (+${ahead})"
      behind=$(git rev-list HEAD..${hook_com[branch]}@{upstream} 2>/dev/null | wc -l | tr -d ' ')
    else
      ahead=""
      displayed_ahead=""
      behind=""
    fi

    if [[ $behind -ne 0 ]] && [[ $ahead -ne 0 ]]; then
      prompt_segment red black
    else
      if [[ -n $dirty ]]; then
        prompt_segment yellow black
      else
        prompt_segment green black
      fi
    fi

    echo -n "${ref_symbol} ${ref}${displayed_ahead}"

    setopt promptsubst
    autoload -Uz vcs_info

    zstyle ':vcs_info:*' enable git
    zstyle ':vcs_info:*' get-revision true
    zstyle ':vcs_info:*' check-for-changes true
    zstyle ':vcs_info:*' stagedstr '✚'
    zstyle ':vcs_info:git:*' unstagedstr '●'
    zstyle ':vcs_info:*' formats ' %u%c'
    zstyle ':vcs_info:*' actionformats '%u%c'
    vcs_info
    echo -n "${vcs_info_msg_0_}"

    # Displaying upstream dedicated segment
    if [[ -n $remote ]]; then
      if [[ $behind -ne 0 ]]; then
        prompt_segment magenta white
      else
        prompt_segment cyan black
      fi
      # hippos
      remote=$(echo $remote | sed -e "s/origin\///")
      echo -n " $remote (-$behind)"
    fi
  fi
}



# Git: branch/detached head, dirty status
xprompt_git() {
  local ref dirty mode repo_path
  repo_path=$(git rev-parse --git-dir 2>/dev/null)

  if $(git rev-parse --is-inside-work-tree >/dev/null 2>&1); then
    dirty=$(parse_git_dirty)
    ref=$(git symbolic-ref HEAD 2> /dev/null) || ref="➦ $(git show-ref --head -s --abbrev |head -n1 2> /dev/null)"
    if [[ -n $dirty ]]; then
      prompt_segment yellow black
    else
      prompt_segment green black
    fi

    if [[ -e "${repo_path}/BISECT_LOG" ]]; then
      mode=" <B>"
    elif [[ -e "${repo_path}/MERGE_HEAD" ]]; then
      mode=" >M<"
    elif [[ -e "${repo_path}/rebase" || -e "${repo_path}/rebase-apply" || -e "${repo_path}/rebase-merge" || -e "${repo_path}/../.dotest" ]]; then
      mode=" >R>"
    fi

    setopt promptsubst
    autoload -Uz vcs_info

    zstyle ':vcs_info:*' enable git
    zstyle ':vcs_info:*' get-revision true
    zstyle ':vcs_info:*' check-for-changes true
    zstyle ':vcs_info:*' stagedstr '✚'
    zstyle ':vcs_info:git:*' unstagedstr '●'
    zstyle ':vcs_info:*' formats ' %u%c'
    zstyle ':vcs_info:*' actionformats ' %u%c'
    vcs_info

    echo -n "${ref/refs\/heads\// }${vcs_info_msg_0_%% }${mode}"
  fi
}


# Virtualenv: current working virtualenv
prompt_virtualenv() {
  local virtualenv_path="$VIRTUAL_ENV"
  if [[ -n $virtualenv_path && -n $VIRTUAL_ENV_DISABLE_PROMPT ]]; then
    prompt_segment blue black "(`basename $virtualenv_path`)"
  fi
}

# Status:
# - was there an error
# - am I root
# - are there background jobs?
prompt_status() {
  local symbols
  symbols=()
  [[ $RETVAL -ne 0 ]] && symbols+="%{%F{red}%}✘"
  [[ $UID -eq 0 ]] && symbols+="%{%F{yellow}%}⚡"
  [[ $(jobs -l | wc -l) -gt 0 ]] && symbols+="%{%F{cyan}%}⚙"

  [[ -n "$symbols" ]] && prompt_segment black default "$symbols"
}



# proxy or not
parse_proxy() {
    if [ ! -z $http_proxy ]; then
        echo -n "[¶]" 
    fi
}

# oke tunnel info
tunnel_env_file=/work/tunnel_env

parse_tunnel() {
    left="➘"
    right="➚"
    if [ -f $tunnel_env_file ]; then
     # get tunnel info
      info=$(cat $tunnel_env_file)
      where=$(echo "$info" |  awk -F- '{print $2}')
      if [[ "${info}" =~ (prd) ]]; then
        prompt_segment black red
        echo -n "${left}Prod.${where}${right}" 
#        echo -n "☿Prod.${where}☿" 
      fi
      if [[ "${info}" =~ (dev) ]]; then
        prompt_segment green white
        echo -n "${left}Dev.${where}${right}"
#        echo -n "☿Dev.${where}☿"
      fi
      if [[ "${info}" =~ (integ) ]]; then
        prompt_segment blue white
        echo -n "${left}Integ.${where}${right}" 
#        echo -n "☿Integ.${where}☿" 
      fi
    fi
}

# get the location our kubeconfig is pointing to
parse_kubeconfig() {
   if [ ! -z $KUBECONFIG ]; then
     location=$(cat $KUBECONFIG | grep "current-context:" | sed "s/current-context: //")
     prompt_segment cyan white
     echo -n "❑${location}❑"
   fi
}




## Main prompt
build_prompt() {
  RETVAL=$?
  parse_proxy
  parse_tunnel
  parse_kubeconfig
      
#  prompt_status
#  prompt_virtualenv
#  prompt_context
  prompt_git
  prompt_dir
  prompt_end
}

PROMPT='%{%f%b%k%}$(build_prompt) '



