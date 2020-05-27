alias k="kubectl"

CONTAINER_NAME="ep-api"
# Log
log () {
    >&2 echo ">> $1"
    >&2 echo ""
}

# Create and enter a toolkit pod
k.toolkit() {
    echo "Running alpine.toolkit:"
    echo "kubectl run shell --generator=run-pod/v1  --rm -i --tty --image hipposareevil/alpine.toolkit -- bash"
    kubectl run shell --generator=run-pod/v1  --rm -i --tty --image hipposareevil/alpine.toolkit -- bash
}

k.work() {
    export KUBECONFIG=/Users/samuel.jackson/.kube/config
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


# Get image version of helm chart
h.get.version () {
    if [ -z "$1" ]
    then
        echo "Must supply helm chart installation. e.g. 'superfunk-tenant'"
        return 1
    fi
    if [[ "$1" == "-h" ]]; then
        echo "Usage: $0 [helm name]"
        echo "Get docker image version for the helm chart"
        echo ""
        echo "$0 superfunk-tenant"
        return 1
    fi


    helm_name=$1

    result=$(helm get all ${helm_name} | grep image | grep harbor | awk '{print $2}' | sed s/\"//g)
    echo "Helm chart '${helm_name}' is running:"
    echo "$result"
}



# Deploy tenant via helm chart
# Must supply name of helm instance

# deploy with repo 'tenant-service'
h.deploy.tenant.dev () {
    if [ -z "$1" ]
    then
        echo "Must supply helm/service name"
        return 1
    fi
    if [[ "$1" == "-h" ]]; then
        echo "Usage: $0 [helm name] <tag name>"
        echo "Deploy from the 'tenant-service'"
        echo "Defaults to using latest tag"
        echo ""
        echo "$0 super-helm-name <ai.3.2.1>"
        return 1
    fi

    helm_name=$1
    image_tag=$2

    _h.deploy.tenant "$helm_name" "tenant-service" "${image_tag}"
}

# deploy with normal repo 'docker'
h.deploy.tenant () {
    if [ -z "$1" ]
    then
        echo "Must supply helm/service name"
        return 1
    fi

    if [[ "$1" == "-h" ]]; then
        echo "Usage: $0 [helm name] <tag name>"
        echo "Deploy from the 'docker' repo"
        echo "Defaults to using latest tag"
        echo ""
        echo "$0 super-helm-name <ai.3.2.1>"
        return 1
    fi



    helm_name=$1
    image_tag=$2
    

    _h.deploy.tenant "$helm_name" "docker" "${image_tag}"
}

_h.deploy.tenant () {
    helm_name="$1"
    repo_name="$2"
    image_tag="$3"

    service_name="tenant-service"
    full_repo="harbor.k8s.platform.einstein.com/${repo_name}"

    # validate we are in correct repo
    git_remote=$(git remote -v 2>&1 | head -1)
    if [[ $git_remote != *"einsteinplatform/helm.git"* ]]; then
        echo "Must be in the helm git repo directory: 'github.com/einsteinplatform/helm.git'"
        return 1
    fi

    # get root of repo
    git_root=$(git rev-parse --show-toplevel)

    # Get latest version
    if [ ! -z "$image_tag" ]; then
        TAG_TO_USE="$image_tag"
    else
        TAG_TO_USE=$(curl -H "accept: application/json" -L -s -q -k -X GET \
                          "harbor.k8s.platform.einstein.com/api/repositories/${repo_name}/${service_name}/tags" \
                         | jq -r ".[] | [.name] | .[]" | sort -V | grep -v SNAPSHOT | grep -v ai | tail -1)

    fi

    log "Creating helm chart: $helm_name"
    log "Using tag: $TAG_TO_USE"


    yaml="${git_root}/ep-tenant/values/dev-usw2.yaml"

    # Upgrade
    log "helm upgrade --install $helm_name prod/ep-common -f ${yaml} --set appName=${helm_name} --set docker.tag=$TAG_TO_USE --set docker.repository=${full_repo}"

    echo "Deploying ${helm_name} with 'tenant-service:${TAG_TO_USE}'"

    result=$(helm upgrade --install $helm_name \
                  prod/ep-common \
                  -f ${yaml} \
                  --set appName=${helm_name} \
                  --set docker.repository=${full_repo} \
                  --set docker.tag=$TAG_TO_USE)
    echo "$result"
}

# Get tags for repo
# e.g.--> h.get.tags docker tenant-service
h.get.tags() {
    repo_name="$1"
    service_name="$2"

    if [[ "$1" == "-h" ]]; then
        echo "Usage: $0 [repo name] [service name]"
        echo "Get list of tags for a repo and service name" 
        echo ""
        echo "$0 tenant-service tenant-service"
        echo "$0 docker tenant-service"
        return 1
    fi

    LATEST=$(curl -H "accept: application/json" -L -s -q -k -X GET \
                  "harbor.k8s.platform.einstein.com/api/repositories/${repo_name}/${service_name}/tags" \
                 | jq -r ".[] | [.name] | .[]" | sort -V)

    echo "$LATEST"
}


# Deploy application service via helm chart
# Must supply name of helm instance

# deploy with repo 'application-service'
h.deploy.application.dev () {
    if [ -z "$1" ]
    then
        echo "Must supply helm/service name"
        return 1
    fi
    if [[ "$1" == "-h" ]]; then
        echo "Usage: $0 [helm name] <tag name>"
        echo "Deploy from the 'application-service' repo"
        echo "Defaults to using latest tag"
        echo ""
        echo "$0 super-helm-name <ai.3.2.1>"
        return 1
    fi

    helm_name=$1
    image_tag=$2


    _h.deploy.application "$helm_name" "application-service" "${image_tag}"
}

# deploy with normal repo 'docker'
h.deploy.application () {
    if [ -z "$1" ]
    then
        echo "Must supply helm/service name"
        return 1
    fi
    if [[ "$1" == "-h" ]]; then
        echo "Usage: $0 [helm name] <tag name>"
        echo "Deploy from the 'docker' repo"
        echo "Defaults to using latest tag"
        echo ""
        echo "$0 super-helm-name <ai.3.2.1>"
        return 1
    fi

    helm_name=$1
    image_tag=$2

    _h.deploy.application "$helm_name" "docker" "${image_tag}"
}

_h.deploy.application () {
    helm_name="$1"
    repo_name="$2"
    image_tag="$3"
    service_name="application-service"
    full_repo="harbor.k8s.platform.einstein.com/${repo_name}"

    # validate we are in correct repo
    git_remote=$(git remote -v 2>&1 | head -1)
    if [[ $git_remote != *"einsteinplatform/helm.git"* ]]; then
        echo "Must be in the helm git repo directory: 'github.com/einsteinplatform/helm.git'"
        return 1
    fi

    # get root of repo
    git_root=$(git rev-parse --show-toplevel)

    # Get latest version
    if [ ! -z "$image_tag" ]; then
        TAG_TO_USE="$image_tag"
    else
        TAG_TO_USE=$(curl -H "accept: application/json" -L -s -q -k -X GET \
                          "harbor.k8s.platform.einstein.com/api/repositories/${repo_name}/${service_name}/tags" \
                         | jq -r ".[] | [.name] | .[]" | sort -V | grep -v SNAPSHOT | tail -1)
    fi

    yaml="${git_root}/ep-api/values/dev-usw2.yaml"

    # Upgrade
    log "helm upgrade --install $helm_name prod/ep-common -f ${yaml} --set appName=${helm_name} --set docker.tag=$TAG_TO_USE --set docker.repository=${full_repo}"

    echo "Deploying ${helm_name} with 'application-service:${TAG_TO_USE}'"

    result=$(helm upgrade --install $helm_name \
                  prod/ep-common \
                  -f ${yaml}  \
                  --set appName=${helm_name} \
                  --set docker.repository=${full_repo} \
                  --set docker.tag=$TAG_TO_USE)
    echo "$result"
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



#########################################################
# OLD
#########################################################

# Get pods for a tkc id
kk.get.tkc.pods () {
    if [ -z "$1" ]
    then
        echo "Must supply tkc id to test"
        return 1
    fi

    log "ko get po -l tkc_id=$1"
    ko get po -l tkc_id=$1 -o wide
}

# get Tenant Agent version for cluster
kk.get.ta.version () {
   if [ -z "$1" ]
    then
        echo "Must supply cluster/tkc id to test"
        return 1
    fi


   log "Getting TKC pods for '$1'"
   pods=$(kk.get.tkc.pods $1)
   # get the TA pod
   ta_pod=$(echo "$pods" | grep "\-ta\-" | awk '{print $1}')

   log "Tenant-Agent pod: $ta_pod"

   # describe pod
   describe_pod=$(kubectl -n ns-user-oke describe pod/$ta_pod)
   image=$(echo "$describe_pod" | grep "tenant-agent\:" -B 0 -A 4 | grep "Image\:" | awk '{print $2}')

   echo "Image: $image"
}


# List pods on a specific node
kk.list.node.pods () {
    if [ -z "$1" ]
    then
        echo "Must supply node to test"
        return 1
    fi

    log "ko get po --all-namespaces --field-selector=spec.nodeName=$1"
    ko get po --all-namespaces --field-selector=spec.nodeName=$1
}

# list containers for a pod
kk.list.containers () {
    if [ -z "$1" ]
    then
        echo "Must supply pod to test"
        return 1
    fi

    log "ko get pods "$1" -o jsonpath='{.spec.containers[*].name}' | xargs"
    ko get pods "$1" -o jsonpath='{.spec.containers[*].name}' | xargs
}

# Exec /bin/sh into the kube proxy
kk.kube.proxy() {
    if [ -z "$1" ]
    then
        echo "Must supply TKC id to test"
        return 1
    fi

    local tkc_id=$1

    all_pods=$(kk.get.pods $tkc_id)
    addon_pods=$(echo "$all_pods" |  grep addons | awk '{print $1}')

    log ">>ko exec -it $addon_pods  -c kube-proxy -- /bin/sh"
    ko exec -it "$addon_pods"  -c kube-proxy -- /bin/sh
}

# Check TKC for health
kk.check.tkc.health () {
    if [ -z "$1" ]
    then
        echo "Must supply pod to test"
        return 1
    fi

    if [[ "$1" == "-h" ]]; then
        echo "kk.check.tkc.health [TKC_ID]: Checks health endpoint on metrics for tkc"
        return 0
    fi

    local id=$1
    unset full_pod_id

    # check if incoming ID is full pod id
    if [[ $id == oke-tkm-oke* ]]; then
        result=$(echo "$id" | grep "\-ta\-")
        if [ $? -eq 0 ]; then
            full_pod_id="$id"
        fi
    fi

    # is full_pod_id set?
    if [ -z ${full_pod_id+x} ]; then
        # not set..
        # get id from kubectl get po...
        echo "Getting full pod id via kubectl for '$id'"
        full_pod_id=$(kubectl -n ns-user-oke get po -l tkc_id=$id | grep "\-ta\-")
        if [ $? -ne 0 ]; then
            echo "Unable to find 'ta' pod for '$id'"
            echo "error: $full_pod_id"
            return 1
        fi

        full_pod_id=$(echo "$full_pod_id" | awk '{print $1}')
        echo "Got full tk pod id: $full_pod_id "
        echo ""
    fi

    # we have full pod id
    location=$(cat $KUBECONFIG | grep "current-context:" | sed "s/current-context: //")
    echo "Looking at pod '$full_pod_id' in location '$location'"

    # run command to get metrics
    echo ""
    echo "Running 'kubectl -n ns-user-oke exec -it '$full_pod_id' -c tenant-agent -- curl localhost:8002/metrics | grep tkc_health_check'"
    echo ""

    result=$(kubectl -n ns-user-oke exec -it "$full_pod_id" -c tenant-agent -- curl localhost:8002/metrics | grep tkc_health_check)

    echo "RESULT:"
    echo "---------------------------------"
    echo "$result"
    echo "---------------------------------"


    echo ""
    # get the '1' gauge and check for health
    one_gauge=$(echo "$result" | grep "\} 1")

    # check bug of having two 1 gauges
    num=$(echo "$one_gauge" | wc -l)
    if [ $num -gt 1 ]; then
        echo "!! Gauge is showing healthy and unhealthy."
        return 1
    fi


    healthy=$(echo "$one_gauge" | grep "\,healthy=\"true\"")
    if [ $? -eq 0 ]; then
        # healthy
        echo "TKC health check is healthy"
    else
        echo "!!!!!!!!!!!!!!!!"
        echo "TKC health check is NOT healthy"
    fi

    unset full_pod_id
}

# Check if we can run kubectl against this node
kk.testnode () {
    if [ -z "$1" ]
    then
        echo "Must supply node to test"
        return 1
    fi

    if [[ "$1" == "-h" ]]; then
        echo "kk.testnode [NODE]: Creates test pod against node with kubectl"
        return 0
    fi

    # get node name
    node=$1

    testname=$(echo $node | awk -F. '{print $1}')
    testname="test-${testname}"

    # get location
    location=$(cat $KUBECONFIG | grep "current-context:" | sed "s/current-context: //")
    echo "Testing kubectl against '$node' in '$location'"
    echo "Making test pod '${testname}'"

    kubectl run -it --rm --restart=Never \
            $testname \
            --image=oraclelinux:7-slim \
            --overrides="{\"spec\":{\"nodeName\": \"$node\"}}" \
            /bin/bash

    echo "done kubectl test"
}

# Verify kk.testnode's pod is running on correct node
kk.verify.testnode () {
    if [ -z "$1" ]
    then
        echo "Must supply node to vierfy"
        return 1
    fi

    if [[ "$1" == "-h" ]]; then
        echo "kk.verify.testnode [NODE]: Prints out location of test pod"
        return 0
    fi

    # get node name
    node=$1

    testname=$(echo $node | awk -F. '{print $1}')
    testname="test-${testname}"

    kubectl get pods \
            -o wide \
            --all-namespaces \
        | grep "$testname"
}


# Check clusters on a node
kk.check.clusters () {
    if [ "$#" -eq 0 ]; then
        echo "Err: Must supply node name."
        exit 1
    fi

    if [[ "$1" == "-h" ]]; then
        echo "kk.check.clusters [NODE]: Checks all clusters that are running on the node for healthyness"
        return 0
    fi

    bold=$(tput bold)
    normal=$(tput sgr0)

    # get node name
    node=$1
    # get kubeconfig info for printing
    location=$(cat $KUBECONFIG | grep "current-context:" | sed "s/current-context: //")
    echo "Investigating node '$node' in environment '$location'"

    # get all pods on that node
    pods=$(kubectl get pods -o wide  --all-namespaces | grep $node)

    # just get tkms pods
    tkms=$(echo "$pods" | grep "oke-tkm")
#    echo "$tkms"

    # get the cluster ids for tkms pods
    cluster_ids=$(echo "$tkms" | awk '{print $2}' | awk -F- '{print $4}' | sort | uniq)
#    echo "$cluster_ids"

    # check each cluster for correct # of etcds
    echo "Checking out each cluster for viable etcd pods...."
    echo ""
    echo "cluster-id  OK running/unknown"
    echo "----------- -- ---------------"
    while IFS= read -r cluster_id ; do
        # look at $cluster_id
        echo -n "$cluster_id  "
        temp_pods=$(kubectl -n ns-user-oke get pods -l tkc_id="$cluster_id" | grep etcd)
        num_running=$(echo "$temp_pods" | grep -i Running | wc -l | xargs)
        num_unknown=$(echo "$temp_pods" | grep -i Unknown | wc -l | xargs)

        if [ "$num_running" -ne 4 ]; then
            echo "${bold}✗${normal}"
            echo "Cluster $cluster_id has incorrect number of etcd pods: $num_running, expected 4 (including the exporter)"
        else
            echo "✓ ${num_running}/${num_unknown}"
        fi
    done <<< "$cluster_ids"

    echo ""
    echo "! done !"
}
