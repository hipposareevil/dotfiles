alias g.fetch="git fetch origin"
alias g.pull="git pull"
alias g.log="git shortlog --summary --numbered"
alias g.get.remote.tags="git ls-remote --tags origin"

function g.fork.refresh() {
    curr=$(git branch --show-current)
    git checkout master
    git pull -p
    git fetch upstream
    git rebase upstream/master
    git push origin
    git checkout "${curr}"
}

function g.master() {
    echo "[Checkout master, fetch, and pull]"
    git checkout master
    git fetch origin
    git pull
}


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
