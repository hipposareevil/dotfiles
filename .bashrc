PS1="[\u@\h] \W> "
alias ll='ls -lAh'
alias la='ls -Ah'
alias lr='ls -lrht'
alias rm="~/bin/junkIt"
export rm="~/bin/junkIt"

export PATH=/home/sam/bin:/opt/maven/bin::$PATH


export http_proxy=http://www-proxy.us.oracle.com:80/
export ftp_proxy=http://www-proxy.us.oracle.com:80/
export FTP_PROXY=http://www-proxy.us.oracle.com:80/
export ALL_PROXY=socks://www-proxy.us.oracle.com:80/
export all_proxy=socks://www-proxy.us.oracle.com:80/
export HTTPS_PROXY=http://www-proxy.us.oracle.com:80/
export https_proxy=http://www-proxy.us.oracle.com:80/
export no_proxy=localhost,127.0.0.0/8,oraclecorp.com,oracle.com
export HTTP_PROXY=http://www-proxy.us.oracle.com:80/


export MARKPATH=$HOME/.marks
function jump { 
    cd -P "$MARKPATH/$1" 2>/dev/null || echo "No such mark: $1"
}
function mark { 
    mkdir -p "$MARKPATH"; ln -s "$(pwd)" "$MARKPATH/$1"
}
function unmark { 
    rm -i "$MARKPATH/$1"
}
function marks {
    ls -l "$MARKPATH" | sed 's/  / /g' | cut -d' ' -f9- | sed 's/ -/\t-/g' && echo
}

function _completemarks {
  reply=($(ls $MARKPATH))
}

