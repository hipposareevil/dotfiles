###############
# Kubernetes related functions
# 
###############


alias k="kubectl"
CONTAINER_NAME="ep-api"

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
    log "k get ingress"
    ingress=$(kubectl get ingress)
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
k.proxy() {
    if [ -z "$1" ]
    then
        echo "Must supply pod to test"
        return 1
    fi

    local pod=$1

    log ">>ka exec -it $pod_pods -c ${CONTAINER_NAME} -- /bin/sh"
    k exec -it "$pod" -c ${CONTAINER_NAME} -- /bin/sh
}



