alias k=kubectl
alias ko="kubectl -n ns-user-oke"
alias ks="kubectl -n ns-user-sj"

# Get pods for a tkc id
k.get.pods () {
    if [ -z "$1" ]
    then
        echo "Must supply tkc id to test"
        return 1
    fi

    echo ">> ko get po -l tkc_id=$1"
    ko get po -l tkc_id=$1
}

# Get containers for a pod
k.get.containers () {
    if [ -z "$1" ]
    then
        echo "Must supply pod to test"
        return 1
    fi

    echo ">> ko get pods "$1" -o jsonpath='{.spec.containers[*].name}' | xargs"
    ko get pods "$1" -o jsonpath='{.spec.containers[*].name}' | xargs
}

# Check TKC for health
k.check.tkc.health () {
    if [ -z "$1" ]
    then
        echo "Must supply pod to test"
        return 1
    fi

    if [[ "$1" == "-h" ]]; then
        echo "k.check.tkc.health [TKC_ID]: Checks health endpoint on metrics for tkc"
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
k.testnode () {
    if [ -z "$1" ]
    then
        echo "Must supply node to test"
        return 1
    fi

    if [[ "$1" == "-h" ]]; then
        echo "k.testnode [NODE]: Creates test pod against node with kubectl"
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

# Verify k.testnode's pod is running on correct node
k.verify.testnode () {
    if [ -z "$1" ]
    then
        echo "Must supply node to vierfy"
        return 1
    fi

    if [[ "$1" == "-h" ]]; then
        echo "k.verify.testnode [NODE]: Prints out location of test pod"
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
k.check.clusters () {
    if [ "$#" -eq 0 ]; then
        echo "Err: Must supply node name."
        exit 1
    fi

    if [[ "$1" == "-h" ]]; then
        echo "k.check.clusters [NODE]: Checks all clusters that are running on the node for healthyness"
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
