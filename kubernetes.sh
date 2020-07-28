###############
# Kubernetes related functions
# 
###############


alias k="kubectl"

# Log
log () {
    >&2 echo ">> $1"
}

# Create and enter a toolkit pod
k.toolkit() {
    echo "Running alpine.toolkit:"
    echo "kubectl run shell --generator=run-pod/v1  --rm -i --tty --image hipposareevil/alpine.toolkit -- bash"
    kubectl run shell --generator=run-pod/v1  --rm -i --tty --image hipposareevil/alpine.toolkit -- bash
}

# Set the kubeconfig 
k.work() {
    export KUBECONFIG=~/.kube/config
}

# Find anything and describe it
kd () {
    local resource_type resource_name
    resource_type="$(kubectl api-resources --output=name | fzf)" 
    resource_name="$(kubectl get "${resource_type}" --output='jsonpath={.items[*].metadata.name}' | tr -s '[[:space:]]' '\n' | fzf)" 
    kubectl describe "${resource_type}" "${resource_name}"
}

# Get secrets
k.sec () {
    local secret_name secret_field
    secret_name="$(kubectl get secret --output=name | fzf)" 
    secret_field="$(kubectl get "${secret_name}" --output=go-template --template='{{range $k, $v := .data}}{{$k}} {{end}}' | tr -s '[[:space:]]' '\n' | fzf)" 
    kubectl get "${secret_name}" --output="jsonpath={.data.${secret_field}}" | base64 --decode
}

# Get tags for docker repository
# e.g.--> k.get.tags docker tenant-service
k.get.tags() {
    if [[ "$1" == "-h" ]]; then
        echo "Usage: $0 [repo name] [service name]"
        echo "Get list of tags for a repo and service name" 
        echo ""
        echo "$0 tenant-service tenant-service"
        echo "$0 docker tenant-service"
        return 1
    fi

    repo_name="$1"
    service_name="$2"

    if [ $# -ne 2 ];  then
        echo "Must supply repo and service names"
        return 1
    fi


    LATEST=$(curl -H "accept: application/json" -L -s -q -k -X GET \
                  "harbor.k8s.platform.einstein.com/v2/${repo_name}/${service_name}/tags/list" \
                 | jq -r ".tags | .[]" | sort -V )
    echo "$LATEST"
}

k.get.tags.app.dev() {
    echo "Getting developer tags"
    echo "----------------------"
    k.get.tags application-service application-service | grep -v ai 
}

k.get.tags.app() {
    echo "Getting normal tags"
    echo "-------------------"
    k.get.tags docker application-service | grep -v ai 
}

k.get.tags.tenant() {
    echo "Getting normal tags"
    echo "-------------------"
    k.get.tags docker tenant-service | grep -v ai 
}


# Get current namespace
k.get.namespace () {
    namespace=$(kubectl config view --minify | grep namespace | awk '{print $2}')
    echo "$namespace"
}

# Get pods on a node
k.get.pods.for.node () {
    if [ -z "$1" ]
    then
        echo "Must supply node name to test"
        return 1
    fi

    node=$1

    echo "Getting pods for node '${node}'"
    log "get pods -o wide  --all-namespaces | grep $node"

    pods=$(kubectl get pods -o wide  --all-namespaces | grep $node)

    echo "${pods}"
}

# Get all worker nodes
k.get.worker.nodes () {
    log "k get nodes -o wide -l kops.k8s.io/instancegroup=nodes"
    nodes=$(kubectl get nodes -o wide -l kops.k8s.io/instancegroup=nodes)

    echo "${nodes}"
}

# Get all master nodes
k.get.master.nodes () {
    log "k get nodes  -o wide  -l kops.k8s.io/instancegroup!=nodes"
    nodes=$(kubectl get nodes  -o wide -l kops.k8s.io/instancegroup!=nodes)

    echo "${nodes}"
}

function _k.get.pods.header() {
    k get pods -o wide | head -1
}

# Get all pods 
k.get.pods () {
#    log "k get pods -o wide"
    pods=$(kubectl get pods -o wide)
    if [ ! -z $1 ]; then
        _k.get.pods.header
        pods=$(echo "${pods}" | grep $1)
    fi

    echo "${pods}"
}

# get ingresses
k.get.ingress () {
    # get header
    kubectl get ingress | head -1

    # get remaining and then sort
    ingress=$(kubectl get ingress | tail -n +2 |  sort -k 2)
    echo "${ingress}"
}

# list containers for a pod
k.get.containers () {
    if [ -z "$1" ]
    then
        echo "Must supply pod to test"
        return 1
    fi

    log "k get pods \"$1\" -o jsonpath='{.spec.containers[*].name}' | xargs"
    k get pods "$1" -o jsonpath='{.spec.containers[*].name}' | xargs
}

# list all deployments
k.get.all.deployments () {
    log "k get deployments --all-namespaces"
    k get deployments --all-namespaces
}

# list deployments
k.get.deployments () {
    k get deployments
}

# list services
k.get.services () {
    k get services
}

# Exec /bin/sh into the pod
k.exec() {
    if [ -z "$1" ]
    then
        echo "Must supply filter to test"
        return 1
    fi

    if [[ "$1" == "-h" ]]; then
        echo "Usage: $0 [filter]"
        echo "Exec into first pod that matches the filter"
        echo ""
        return 1
    fi

    local filter=$1
    pod=$(kubectl get pods -o wide | grep $filter| head -1 | awk '{print $1}')
    log "Execing into pod '$pod'"
    k exec -it "$pod"  -- /bin/bash
}



