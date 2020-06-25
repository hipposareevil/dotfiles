###############
# Helm related functions
# 
###############


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



# Deploy postgres
# This will create a secret that is then used in the DB startup
h.deploy.database () {
    # validate annotations
    _h.annotate

    # create secrets if necessary
    logit ""
    logit "Install the DB secrets"
    k.install.db.secrets

    # deploy the database
    logit ""
    logit "Deploy the Database"
    _h.deploy.db

    # run db-manager
    logit ""
    logit "Run DB Manager"
    h.run.db.manager
}


# Run db-manager against db in k8s
h.run.db.manager () {
    namespace=$(kubectl config view --minify | grep namespace | awk '{print $2}')
    db_name="${namespace}-app-db"

    # Wait for the db to startup
    logit "Waiting for '${db_name}' to come up"
    for i in {1..10}
    do
        running=$(k get pods | grep ${db_name} | awk '{print $3}')
        if [[ $running == "Running" ]]; then
            logit "DB '${db_name}' is running."
            break
        else
            logit "Waiting for DB to come up"
        fi
        sleep 15s
    done

    # Create some variables
    database_url="${db_name}-postgresql"
    db_manager_image="harbor.k8s.platform.einstein.com/docker/einstein-db-manager"

    logit ""
    logit "Get tags for db-manager"

    # use latest db-manager, ignoring 'ai' and 'snapshot
    latest_tag=$(curl -H "accept: application/json" -L -s -q -k -X GET \
                 "harbor.k8s.platform.einstein.com/v2/docker/einstein-db-manager/tags/list" \
                 | jq -r ".tags | .[]" \
                 | grep -v "ai" | grep -v "snapshot" | sort -V | tail -1)

    logit "Using ${db_manager_image}:${latest_tag}"

    # delete any old job
    exists=$(k get job db-manager 2> /dev/null)
    if [ $? -eq 0 ]; then
        # job exists, delete it
        logit "Deleting old db-manager job"
        k delete job db-manager > /dev/null 
        logit ""
    fi

    # run DB job
read -d '' db_yaml <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: db-manager
spec:
  template:
    metadata:
      annotations: 
        iam.amazonaws.com/role: dev-ecp-application-service-role
    spec:
      containers:
      - name: db-manager
        image: ${db_manager_image}:${latest_tag}
        env:
          - name: APP_ENVIRONMENT
            value: "dev"
          - name: EINSTEIN1_DATABASE_USER
            value: "application_dev"
          - name: EINSTEIN1_DATABASE_URL
            value: "${database_url}"
          - name: EINSTEIN1_DATABASE_NAME
            value: "application"
          - name: VAULT_EINSTEIN1_DATABASE_PASSWORD
            value: "rds_password"
          - name: EINSTEIN1_SETTINGS_PATH
            value: "dev-secure.dcos.aws.-.db-manager-service"
      restartPolicy: Never
  backoffLimit: 1
EOF

   logit "Deploying db-manager job"
   echo "${db_yaml}" | kubectl apply -f -
   logit "db-manager done"
}

# Deploy the DB
_h.deploy.db () {
    #############
    # Add bitnami to helm repo
    logit "Add 'bitnami' to helm repo"
    exists=$(helm repo list | grep bitnami)
    if [ $? -eq 0 ]; then
        logit "bitnami already in helm repo"
    else
        helm repo add bitnami https://charts.bitnami.com/bitnami
    fi

    # deploy DB as ${namespace}-app-db
    namespace=$(kubectl config view --minify | grep namespace | awk '{print $2}')
    db_name="${namespace}-app-db"

    #############
    # Install db
    logit ""
    logit "Install database '${db_name}'"
    # does the db already exist?
    exists=$(k get pods | grep ${db_name})
    if [ $? -eq 0 ]; then
        logit "Database '${db_name}' already exists"
    else
        helm install ${db_name} \
             bitnami/postgresql \
             --set image.tag=10.13.0 \
             --set postgresqlDatabase=application  \
             --set existingSecret=postgres-secret \
             --set initdbScriptsSecret=init-scripts-secret
        logit "Created database '${db_name}'"
    fi
}

# Install secrets for k8s DB
k.install.db.secrets() {
    set +x

    SECRET=postgres-secret
    INIT_SCRIPT=init-scripts-secret

    exists_already=$(kubectl get secret ${SECRET} 2> /dev/null)
    if [ $? -eq 0 ]; then
        logit "Secret ${SECRET} already exists. Skipping creation."
    else
        # create password for root of postgres
        PASSWORD=$(openssl rand -base64 32)
        kubectl create secret generic $SECRET --from-literal=postgresql-password=$PASSWORD
    fi


    exists_already=$(kubectl get secret ${INIT_SCRIPT} 2> /dev/null)
    if [ $? -eq 0 ]; then
        logit "Secret ${INIT_SCRIPT} already exists. Skipping creation."
    else

        # get password from vault
        VAULT_PASSWORD=$(vault read -address=${VAULT_ADDRESS} secret/application-service/rds_password -format=json | jq -r .data.secret)

        echo "PGPASSWORD=\$POSTGRES_PASSWORD psql -U postgres -c \"create user application_dev with encrypted password '$VAULT_PASSWORD'\"" > /tmp/script.sh
        echo "PGPASSWORD=\$POSTGRES_PASSWORD psql -U postgres -c \"grant all privileges on database application to application_dev\"" >> /tmp/script.sh
        echo "PGPASSWORD=\$POSTGRES_PASSWORD psql -U postgres -c \"alter user application_dev with SUPERUSER\"" >> /tmp/script.sh

        # create secret 'init-script-secret'
        kubectl create secret generic ${INIT_SCRIPT} --from-file=/tmp/script.sh
        rm /tmp/script.sh
    fi
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
    logit "helm upgrade --install $helm_name prod/ep-common -f ${dev_yaml} --set ingress.urlOverride='' --set appConfigs.environ.EINSTEIN1_DATABASE_URL=${database_url} --set appName=${helm_name} --set docker.tag=$TAG_TO_USE --set docker.repository=${full_repo} --set deployment.strategy.rollingUpdate.maxSurge=100 "
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
    #                  --set deployment.strategy.rollingUpdate.maxSurge=100)
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
    logit "helm upgrade --install $helm_name prod/ep-common -f ${dev_yaml} --set ingress.urlOverride='' --set appConfigs.environ.EINSTEIN1_DATABASE_URL=${database_url} --set appName=${helm_name} --set docker.tag=$TAG_TO_USE --set docker.repository=${full_repo} --set deployment.strategy.rollingUpdate.maxSurge=100"
    logit ""

    result=$(helm upgrade --install $helm_name \
                  prod/ep-common \
                  -f ${dev_yaml}  \
                  --set appConfigs.environ.EINSTEIN1_DATABASE_URL="${database_url}" \
                  --set appName=${helm_name} \
                  --set ingress.urlOverride="" \
                  --set docker.repository=${full_repo} \
                  --set docker.tag=$TAG_TO_USE)
##                  --set deployment.strategy.rollingUpdate.maxSurge=100)
    logit "$result"
}


