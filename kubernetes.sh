CONTAINER_NAME="ep-api"
# Log
log () {
    >&2 echo ">> $1"
    >&2 echo ""
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


# Get pods on a node
k.get.pods.for.node () {
    if [ -z "$1" ]
    then
        echo "Must supply node name to test"
        return 1
    fi

    node=$1

    echo "Getting pods for node '${node}'"
    log ">>k get pods -o wide  --all-namespaces | grep $node"

    pods=$(kubectl get pods -o wide  --all-namespaces | grep $node)

    echo "${pods}"
}

# Get all worker nodes
k.get.worker.nodes () {
    log "k get nodes -l kops.k8s.io/instancegroup=nodes"
    nodes=$(kubectl get nodes -l kops.k8s.io/instancegroup=nodes)

    echo "${nodes}"
}

# Get all master nodes
k.get.master.nodes () {
    log "k get nodes -l kops.k8s.io/instancegroup!=nodes"
    nodes=$(kubectl get nodes -l kops.k8s.io/instancegroup!=nodes)

    echo "${nodes}"
}


# Get all pods 
k.get.pods () {
    log "k get pods -o wide"
    pods=$(kubectl get pods -o wide)
    echo "${pods}"
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
