###############
# Helm related functions
# 
###############

VAULT_ADDRESS="https://vault.dev.platform.einstein.com"

. ./helm.db.sh

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

# Not kubernetes, but used by db
vault.login() {
    if [[ "$1" == "-h" ]]; then
        echo "Usage: $0 <username>"
        echo ""
        echo "Log into vault with username"
        return 1
    fi

    user=$1

    echo "Logging into vault '$VAULT_ADDRESS' as user '$user'"

    vault login -address=${VAULT_ADDRESS} -method=ldap username=${user}
}



# Annotate the namespace so vault will work
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

# Validate helm repo
_h.add.prod.repo () {
    logit "Add 'prod' to helm repo"
    exists=$(helm repo list | grep "harbor.k8s.platform.einstein.com/chartrepo/prod")
    if [ $? -eq 0 ]; then
        logit "'prod' already in helm repo"
    else
        helm repo add prod https://harbor.k8s.platformq.einstein.com/chartrepo/prod
    fi
}


# Deploy tenant via helm chart
# deploy with repo 'docker'
h.deploy.tenant () {
    namespace=$(k.get.namespace)
    application_name="${namespace}-tenant"

    if [[ "$1" == "-h" ]]; then
        echo "Usage: $0 [helm name] <tag name>"
        echo ""
        echo "Deploy from the 'docker' repo"
        echo ""
        echo "Defaults to helm name of '$application_name'"
        echo "Defaults to using latest tag"
        echo ""
        echo "Example:"
        echo "$0 <super-helm-name> <2020.06.11.5>"
        return 1
    fi

    if [[ ! -z "$1" ]]; then
        application_name=$1
    fi
    image_tag=$2

    _h.deploy.tenant "$application_name" "docker" "application-db.dev.platform.einstein.com" "${image_tag}"
}


# Deploy tenant via helm chart
# deploy with repo 'tenant-service'
h.deploy.tenant.dev () {
    namespace=$(k.get.namespace)
    application_name="${namespace}-tenant"

    if [[ "$1" == "-h" ]]; then
        echo "Usage: $0 [helm name] <tag name>"
        echo ""
        echo "Deploy from the 'tenant-service' repo"
        echo ""
        echo "Defaults to helm name of '$application_name'"
        echo "Defaults to using latest tag"
        echo ""
        echo "Example:"
        echo "$0 <super-helm-name> <2020.06.11.5>"
        return 1
    fi

    if [[ ! -z "$1" ]]; then
        application_name=$1
    fi
    image_tag=$2

    _h.deploy.tenant "$application_name" "tenant-service" "application-db.dev.platform.einstein.com" "${image_tag}"
}


# deploy with repo 'tenant-service' and DB
h.deploy.tenant.dev.db () {
    namespace=$(k.get.namespace)
    application_name="${namespace}-tenant"
    db_name="${namespace}-app-db-postgresql"

    if [[ "$1" == "-h" ]]; then
        echo "Usage: $0 [helm name] <tag name>"
        echo ""
        echo "Deploy from the 'tenant-service' repo"
        echo "Will use the k8s database instead of RDS."
        echo "(Run 'h.deploy.database' to create one.)"
        echo ""
        echo "Defaults to helm name of '$application_name'"
        echo "Defaults to using latest tag"
        echo ""
        echo "Example:"
        echo "$0 <super-helm-name> <2020.06.11.5>"
        return 1
    fi

    if [[ ! -z "$1" ]]; then
        application_name=$1
    fi
    image_tag=$2

    _h.deploy.tenant "$application_name" "tenant-service" "${db_name}" "${image_tag}"
}


_h.deploy.tenant () {
    helm_name="$1"
    repo_name="$2"
    database_url="$3"
    image_tag="$4"

    service_name="tenant-service"
    full_repo="harbor.k8s.platform.einstein.com/${repo_name}"

    # validate we are in correct repo
    git_remote=$(git remote -v 2>&1 | head -1)
    if [[ $git_remote != *"einsteinplatform/helm.git"* ]]; then
        echo "Must be in the helm git repo directory: 'github.com/einsteinplatform/helm.git'"
        return 1
    fi

    # validate the annotations & repo
    _h.annotate
    _h.add.prod.repo

    # get root of repo
    git_root=$(git rev-parse --show-toplevel)

    # Get latest version
    if [ ! -z "$image_tag" ]; then
        TAG_TO_USE="$image_tag"
    else
        TAG_TO_USE=$(curl -H "accept: application/json" -L -s -q -k -X GET \
                          "harbor.k8s.platform.einstein.com/v2/${repo_name}/${service_name}/tags/list" \
                         | jq -r ".tags | .[]" | grep -v SNAPSHOT | grep -v ai | sort -V | tail -1 )
    fi

    logit "Creating helm chart: $helm_name"
    logit "Using tag: $TAG_TO_USE"

    dev_yaml="${git_root}/ep-tenant/values/dev-usw2.yaml"

    # Upgrade
    logit "helm upgrade --install $helm_name prod/ep-common -f ${dev_yaml} --set ingress.urlOverride='' --set appConfigs.environ.EINSTEIN1_DATABASE_URL=${database_url} --set appName=${helm_name} --set docker.tag=$TAG_TO_USE --set docker.repository=${full_repo}"
    logit ""
    logit "Deploying ${helm_name} with 'tenant-service:${TAG_TO_USE}'"
    logit ""

    result=$(helm upgrade --install $helm_name \
                  prod/ep-common \
                  --set appConfigs.environ.EINSTEIN1_DATABASE_URL="${database_url}" \
                  -f ${dev_yaml} \
                  --set appName=${helm_name} \
                  --set ingress.urlOverride="" \
                  --set docker.repository=${full_repo} \
                  --set docker.tag=$TAG_TO_USE)
    logit "$result"
}


k.get.namespace () {
    namespace=$(kubectl config view --minify | grep namespace | awk '{print $2}')
    echo "$namespace"
}

# Deploy application service via helm chart
# uses docker repo
h.deploy.application () {
    namespace=$(k.get.namespace)
    application_name="${namespace}-application"

    if [[ "$1" == "-h" ]]; then
        echo "Usage: $0 <helm name> <tag name>"
        echo ""
        echo "Deploy from the 'docker' repo"
        echo ""
        echo "Defaults to helm name of '$application_name'"
        echo "Defaults to using latest tag"
        echo ""
        echo "Example:"
        echo "$0 <super-helm-name> <2020.05.21.16>"
        return 1
    fi

    if [[ ! -z "$1" ]]; then
        application_name=$1
    fi
    image_tag=$2

    _h.deploy.application "$application_name" "docker" "application-db.dev.platform.einstein.com" "${image_tag}"
}
# Deploy application service via helm chart
h.deploy.application.dev () {
    namespace=$(k.get.namespace)
    application_name="${namespace}-application"

    if [[ "$1" == "-h" ]]; then
        echo "Usage: $0 <helm name> <tag name>"
        echo ""
        echo "Deploy from the 'application-service' repo"
        echo ""
        echo "Defaults to helm name of '$application_name'"
        echo "Defaults to using latest tag"
        echo ""
        echo "Example:"
        echo "$0 <super-helm-name> <2020.05.21.16>"
        return 1
    fi

    if [[ ! -z "$1" ]]; then
        application_name=$1
    fi
    image_tag=$2

    _h.deploy.application "$application_name" "application-service" "application-db.dev.platform.einstein.com" "${image_tag}"
}

# deploy with repo 'application-service' and use local db
h.deploy.application.dev.db () {
    namespace=$(k.get.namespace)
    application_name="${namespace}-application"
    db_name="${namespace}-app-db-postgresql"

    if [[ "$1" == "-h" ]]; then
        echo "Usage: $0 <helm name> <tag name>"
        echo ""
        echo "Deploys Application Service from the 'application-service' repo."
        echo "Will use the k8s database instead of RDS."
        echo "(Run 'h.deploy.database' to create one.)"
        echo ""
        echo "Defaults to helm name of '$application_name'"
        echo "Defaults to using latest tag."
        echo ""
        echo "Example:"
        echo "$0 <super-helm-name> <2020.05.21.16>"
        return 1
    fi

    if [[ ! -z "$1" ]]; then
        application_name=$1
    fi
    image_tag=$2

    _h.deploy.application "${application_name}" "application-service" "${db_name}" "${image_tag}"
}



# deploy with repo 'docker' and use local db
h.deploy.application.db () {
    namespace=$(k.get.namespace)
    application_name="${namespace}-application"
    db_name="${namespace}-app-db-postgresql"

    if [[ "$1" == "-h" ]]; then
        echo "Usage: $0 <helm name> <tag name>"
        echo ""
        echo "Deploys Application Service from the 'docker' repo."
        echo "Will use the k8s database instead of RDS."
        echo "(Run 'h.deploy.database' to create one.)"
        echo ""
        echo "Defaults to helm name of '$application_name'"
        echo "Defaults to using latest tag."
        echo ""
        echo "Example:"
        echo "$0 <super-helm-name> <2020.05.21.16>"
        return 1
    fi

    if [[ ! -z "$1" ]]; then
        application_name=$1
    fi
    image_tag=$2

    _h.deploy.application "${application_name}" "docker" "${db_name}" "${image_tag}"
}



_h.deploy.application () {
    helm_name="$1"
    repo_name="$2"
    database_url="$3"
    image_tag="$4"

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

    # validate the annotations & repo
    _h.annotate
    _h.add.prod.repo

    # Get latest version
    if [ ! -z "$image_tag" ]; then
        TAG_TO_USE="$image_tag"
    else
        TAG_TO_USE=$(curl -H "accept: application/json" -L -s -q -k -X GET \
                          "harbor.k8s.platform.einstein.com/v2/${repo_name}/${service_name}/tags/list" \
                         | jq -r ".tags | .[]" | grep -v SNAPSHOT | grep -v ai | sort -V | tail -1 )
    fi

    dev_yaml="${git_root}/ep-api/values/dev-usw2.yaml"

    # Upgrade
    logit "Deploying ${helm_name} with 'application-service:${TAG_TO_USE}'"
    logit ""
    logit "helm upgrade --install $helm_name prod/ep-common -f ${dev_yaml} --set ingress.urlOverride='' --set appConfigs.environ.EINSTEIN1_DATABASE_URL=${database_url} --set appName=${helm_name} --set docker.tag=$TAG_TO_USE --set docker.repository=${full_repo}"
    logit ""

    result=$(helm upgrade --install $helm_name \
                  prod/ep-common \
                  -f ${dev_yaml}  \
                  --set appConfigs.environ.EINSTEIN1_DATABASE_URL="${database_url}" \
                  --set appName=${helm_name} \
                  --set ingress.urlOverride="" \
                  --set docker.repository=${full_repo} \
                  --set docker.tag=$TAG_TO_USE)
    logit "$result"
}


