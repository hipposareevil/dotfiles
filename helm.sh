###############
# Helm related functions
# 
###############

VAULT_ADDRESS="https://vault.dev.platform.einstein.com"

drop_dot_dir=$(dirname $0)
source ${drop_dot_dir}/helm.db.sh

logit() {
    if [ -z $1 ]; then
        echo
    else
        echo "[$1]"
    fi
}

# Get image version of helm chart
h.get.version () {
    if [ -z "$1" ]
    then
        echo "Usage: $0 [helm name]"
        echo "Must supply helm chart installation. e.g. 'superfunk-tenant'"
        return 1
    fi
    if [[ "$1" == "-h" ]]; then
        echo "Usage: $0 [helm name]"
        echo "Get docker image version for the helm chart"
        echo ""
        echo "Example:"
        echo "$0 superfunk-tenant"
        return 1
    fi

    helm_name=$1

    result=$(helm get all ${helm_name} | grep image | grep harbor | awk '{print $2}' | sed s/\"//g)
    echo "Helm chart '${helm_name}' is running:"
    echo "$result"
}



# Get chart versions from repo
h.get.repo () {
    if [[ "$1" == "-h" ]]; then
        echo "Usage: $0 <chart name>"
        echo "Get helm repo by name"
        echo ""
        echo "Example:"
        echo "$0 ep-common"
        return 1
    fi

    default="prod"
    chart=${1:-$default}
    echo "Looking for chart '${chart}'"
    top=$(helm search repo prod --versions | head -1)
    results=$(helm search repo prod --versions | grep -v bitnami | grep ${chart})
    echo "$top"
    echo "$results"
}


#####
# Get namespace name
# 
#####
k.get.namespace () {
    namespace=$(kubectl config view --minify | grep namespace | awk '{print $2}')
    echo "$namespace"
}

# Annotate the namespace so we can connect to vault
_h.annotate () {
    namespace=$(k.get.namespace)
    exists=$(k describe namespace ${namespace} | grep Annotations | grep "iam.amazonaws.com/permitted")
    if [ $? -eq 0 ]; then
        logit "Namespace '${namespace}' correctly annotated."
    else
        logit "Namespace '${namespace}' missing annotation. Adding now"
        k annotate --overwrite namespace ${namespace} "iam.amazonaws.com/permitted=.*"
    fi
}

# Validate (and add) helm repo
_h.add.prod.repo () {
    logit "Add 'prod' to helm repo"
    exists=$(helm repo list | grep "harbor.k8s.platform.einstein.com/chartrepo/prod")
    if [ $? -eq 0 ]; then
        logit "'prod' already in helm repo"
    else
        helm repo add prod https://harbor.k8s.platform.einstein.com/chartrepo/prod
    fi
}




########
# Deploy tenant service via helm chart
########
h.deploy.tenant () {
    _h.deploy.service "tenant" "$@"
}

########
# Deploy application service via helm chart
########
h.deploy.application () {
    _h.deploy.service "application" "$@"
}


#########
# Deploy a service
#
# params:
# 1- application or tenant service name
#########
_h.deploy.service () {
    # Service name (application or tenant)
    service_name=$1
    shift
    if [[ $service_name == "application" ]]; then
        helm_subdir="ep-api"
    else
        helm_subdir="ep-tenant"
    fi

    # init vars with defaults
    namespace=$(k.get.namespace)
    helm_name="${namespace}-${service_name}"
    # which repo, 'docker' or developer version (application-service/tenant-service)
    docker_repo="docker"
    send_logs=0
    image_tag=""
    database_url="application-db.dev.platform.einstein.com"

    # parse options
    POSITIONAL=()
    while [[ $# -gt 0 ]]
    do
        key="$1"
        case $key in
            -h|--help|\?)
                _h.deploy.help "h.deploy.${service_name}" "${service_name}"
                shift
                return 1
                ;;
            -n|--name)
                helm_name="$2"
                shift 2
                ;;
            -t|--tag)
                image_tag="$2"
                shift 2
                ;;
            -db)
                database_url="${namespace}-app-db-postgresql"                
                shift
                ;;
            -d|--dev)
                docker_repo="${service_name}-service"
                shift
                ;;
            -l|--logs)
                send_logs=1
                shift
                ;;

        esac
    done
    set -- "${POSITIONAL[@]}" # restore positional parameters

    #######
    # Do work

    # validate we are in correct repo
    git_remote=$(git remote -v 2>&1 | head -1)
    if [[ $git_remote != *"einsteinplatform/helm.git"* ]]; then
        echo "Must be in the helm git repo directory: 'github.com/einsteinplatform/helm.git'"
        return 1
    fi
    # get root of repo
    git_root=$(git rev-parse --show-toplevel)

    # validate the annotations & repo
    _h.annotate
    _h.add.prod.repo

    # name of service in repo
    docker_service_name="${service_name}-service"
    # full harbor repo
    full_repo="harbor.k8s.platform.einstein.com/${docker_repo}"

    # Determine tag to use. If not passed in, get latest from repo
    if [ ! -z "$image_tag" ]; then
        TAG_TO_USE="$image_tag"
    else
        TAG_TO_USE=$(curl -H "accept: application/json" -L -s -q -k -X GET \
                          "harbor.k8s.platform.einstein.com/v2/${docker_repo}/${docker_service_name}/tags/list" \
                         | jq -r ".tags | .[]" | grep -v SNAPSHOT | grep -v ai | sort -V | tail -1 )
    fi

    # Grab the dev yaml and make a version without the extraIngress
    dev_yaml="${git_root}/${helm_subdir}/values/dev-usw2.yaml"
    new_yaml="/tmp/dev-usw2.yaml"
    sed '/extraIngress/,$d' $dev_yaml > $new_yaml

    # Upgrade
    # send logs to sumo? default to no
    if [ $send_logs -eq 1 ]; then
        annotation=""
    else
        annotation="--set appConfigs.annotations.\"sumologic\.com/exclude\"=\"true\""
    fi

    logit "Deploying ${helm_name} with '${docker_repo}/${docker_service_name}:${TAG_TO_USE}'"
    logit ""
    logit "helm upgrade --install $helm_name prod/ep-common -f ${dev_yaml} --set ingress.urlOverride='' --set appConfigs.environ.EINSTEIN1_DATABASE_URL=${database_url} --set appName=${helm_name} --set docker.tag=$TAG_TO_USE --set docker.repository=${full_repo} ${annotation}"
    logit ""

    result=$(helm upgrade --install $helm_name \
                  prod/ep-common \
                  -f ${dev_yaml}  \
                  --set appConfigs.environ.EINSTEIN1_DATABASE_URL="${database_url}" \
                  --set appName=${helm_name} \
                  --set ingress.urlOverride="" \
                  --set docker.repository=${full_repo} \
                  --set docker.tag=$TAG_TO_USE \
                  ${annotations} )
    logit "$result"
}


#####
# Print out deploy help
#
#
# params:
# 1- Calling script name
# 2- service name (tenant or application)
#####
_h.deploy.help () {
    script_name=$1
    service=$2

    namespace=$(k.get.namespace)
    service_name="${namespace}-${service}"

    capitalized_service="$(tr '[:lower:]' '[:upper:]' <<< ${service:0:1})${service:1}"


    echo "Deploy ${capitalized_service} Service from Harbor's 'docker' repo to your namespace."
    echo "Default action is to not forward logs to sumologic. "
    echo ""
    echo "Usage: $script_name [-n helm_name] [-t tag_name] [-d] [-l] [-db]"
    echo ""
    echo "Options: "
    echo "   -n/--name  helm_name - Set Helm name. Defaults to name of '${service_name}'"
    echo "   -t/--tag   tag_name  - Docker image tag. Defaults to the lastest in 'docker' repo"
    echo "   -d/--dev   Use developer git repo '${service}-service' instead of 'docker'"
    echo "   -l/--logs  Send logs to sumologic"
    echo "   -db        Use k8s database instead of RDS. (run 'h.deploy.database' to create one)"
    echo ""
    echo "Examples:"
    echo "${script_name} -n super-funk -t 2020.05.21.16"
    echo "   helm name of super-funk using 2020.05.21.16 tag in docker repo"
    echo "${script_name} -l"
    echo "   helm name of ${service_name}, using latest tag, send logs to sumo."
}
