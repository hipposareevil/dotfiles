alias g.fetch="git fetch origin"
alias g.pull="git pull"
alias g.master="git checkout master"
alias g.log="git shortlog --summary --numbered"

alias g.get.remote.tags="git ls-remote --tags origin"

# Get commit for tag and show logs
function g.get.tag() {
    if [ -z "$1" ]
    then
        echo "Must supply git tag"
        return 1
    fi
    if [[ "$1" == "-h" ]]; then
        echo "Usage: $0 [git tag]"
        echo "Show git commit and history for tag"
    fi

    tag=$1
    commit=$(git rev-list -n 1 $tag)
    git log -p $commit    
}
