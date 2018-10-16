alias g.fetch="git fetch origin"
alias g.pull="git pull"

alias g.log="git shortlog --summary --numbered"


## git
function g.proxy() {
  git config --global --add https.proxy http://rmdc-proxy.oracle.com:80
  git config --global --add http.proxy http://rmdc-proxy.oracle.com:80
}

function g.unproxy() {
  git config --global --unset-all http.proxy  
  git config --global --unset-all https.proxy  
}
