###############
# Helm and Kubernetes Database functions
# 
###############

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


# Get RDS password from vault 
k.get.rds.password() {
    RDS_PASSWORD=$(vault read -address=${VAULT_ADDRESS} secret/application-service/rds_password -format=json | jq -r .data.secret)
    export RDS_PASSWORD
}

# Dump the DB info from k8s db
k.dump.db() {
    namespace=$(kubectl config view --minify | grep namespace | awk '{print $2}')
    db_name="${namespace}-app-db"
    database_url="${db_name}-postgresql"

    if [[ "$1" == "-h" ]]; then
        echo "Usage: $0"
        echo "Dump the Postgres DB '${db_name}' into file 'dump'"
        return 1
    fi

    echo "Getting password from '$VAULT_ADDRESS'"
    VAULT_PASSWORD=$(vault read -address=${VAULT_ADDRESS} secret/application-service/rds_password -format=json | jq -r .data.secret)
    if [ $? -ne 0 ]; then
        echo "*****"
        echo "Unable to read from vault:"
        echo "$VAULT_PASSWORD"
        echo ""
        echo "Run 'vault.login'"
        echo "*****"
    fi

    echo "Creating container to dump the database '${database_url}' as 'application_dev'"
    kubectl run "${namespace}-db-client-dump" \
            --rm --tty -i \
            --restart='Never' \
            --namespace "${namespace}" \
            --image docker.io/bitnami/postgresql:10.13.0 \
            --env="PGPASSWORD=$VAULT_PASSWORD" \
            --command -- pg_dump \
            --host ${database_url} \
            -U application_dev \
            -d application \
            -p 5432 \
            > dump
}


# Dump the DB info from RDS db
k.dump.real.db() {
    namespace=$(kubectl config view --minify | grep namespace | awk '{print $2}')
    database_url="application-db.dev.platform.einstein.com"

    if [[ "$1" == "-h" ]]; then
        echo "Usage: $0"
        echo "Dump the Postgres DB '${database_url}' into file 'dump.rds'"
        return 1
    fi

    echo "Getting password from '$VAULT_ADDRESS'"
    VAULT_PASSWORD=$(vault read -address=${VAULT_ADDRESS} secret/application-service/rds_password -format=json | jq -r .data.secret)
    if [ $? -ne 0 ]; then
        echo "*****"
        echo "Unable to read from vault:"
        echo "$VAULT_PASSWORD"
        echo ""
        echo "Run 'vault.login'"
        echo "*****"
    fi

    echo "Creating container to dump the database '${database_url}' as 'application_dev'"
    kubectl run "${namespace}-db-client-dump" \
            --rm --tty -i \
            --restart='Never' \
            --namespace "${namespace}" \
            --image docker.io/bitnami/postgresql:10.9.0 \
            --env="PGPASSWORD=$VAULT_PASSWORD" \
            --command -- pg_dumpall \
            --host ${database_url} \
            -U application_dev \
            -d application \
            -p 5432 \
            > dump.rds
}


# Get into k8s db
k.exec.db () {
    namespace=$(kubectl config view --minify | grep namespace | awk '{print $2}')
    db_name="${namespace}-app-db"
    database_url="${db_name}-postgresql"

    if [[ "$1" == "-h" ]]; then
        echo "Usage: $0"
        echo "Exec into Postgres DB '${db_name}' in the existing cluster"
        return 1
    fi

    echo "Getting password from '$VAULT_ADDRESS'"
    VAULT_PASSWORD=$(vault read -address=${VAULT_ADDRESS} secret/application-service/rds_password -format=json | jq -r .data.secret)
    if [ $? -ne 0 ]; then
        echo "*****"
        echo "Unable to read from vault:"
        echo "$VAULT_PASSWORD"
        echo ""
        echo "Run 'vault.login'"
        echo "*****"
    fi

    # k get secret "postgres-secret" --output="jsonpath={.data.postgresql-password}" | base64 --decode

    echo "Creating container to connect to database '${database_url}' as 'application_dev'"

    kubectl run "${namespace}-db-client" \
            --rm --tty -i \
            --restart='Never' \
            --namespace "${namespace}" \
            --image docker.io/bitnami/postgresql:10.13.0 \
            --env="PGPASSWORD=$VAULT_PASSWORD" \
            --command -- psql \
            --host ${database_url} \
            -U application_dev \
            -d application -p 5432
}


# Get into k8s db
k.exec.real.db () {
    namespace=$(kubectl config view --minify | grep namespace | awk '{print $2}')
    database_url="application-db.dev.platform.einstein.com"

    if [[ "$1" == "-h" ]]; then
        echo "Usage: $0"
        echo "Exec into Postgres DB '${database_url}' in the existing cluster"
        return 1
    fi

    echo "Getting password from '$VAULT_ADDRESS'"
    VAULT_PASSWORD=$(vault read -address=${VAULT_ADDRESS} secret/application-service/rds_password -format=json | jq -r .data.secret)
    if [ $? -ne 0 ]; then
        echo "*****"
        echo "Unable to read from vault:"
        echo "$VAULT_PASSWORD"
        echo ""
        echo "Run 'vault.login'"
        echo "*****"
    fi

    # k get secret "postgres-secret" --output="jsonpath={.data.postgresql-password}" | base64 --decode

    echo "Creating container to connect to real dev database '${database_url}' as 'application_dev'"

    kubectl run "${namespace}-db-client" \
            --rm --tty -i \
            --restart='Never' \
            --namespace "${namespace}" \
            --image docker.io/bitnami/postgresql:10.9.0 \
            --env="PGPASSWORD=$VAULT_PASSWORD" \
            --command -- psql \
            --host ${database_url} \
            -U application_dev \
            -d application -p 5432
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

    echo "Creating $SECRET"
    exists_already=$(kubectl get secret ${SECRET} 2> /dev/null)
    if [ $? -eq 0 ]; then
        logit "Secret ${SECRET} already exists. Skipping creation."
    else
        # create password for root of postgres
        PASSWORD=$(openssl rand -base64 32)
        kubectl create secret generic $SECRET --from-literal=postgresql-password=$PASSWORD
    fi


    echo "Creating $INIT_SCRIPT"
    exists_already=$(kubectl get secret ${INIT_SCRIPT} 2> /dev/null)
    if [ $? -eq 0 ]; then
        logit "Secret ${INIT_SCRIPT} already exists. Skipping creation."
    else
        # get password from vault
        VAULT_PASSWORD=$(vault read -address=${VAULT_ADDRESS} secret/application-service/rds_password -format=json | jq -r .data.secret)
        if [ $? -ne 0 ]; then
            echo "*****"
            echo "Unable to read from vault:"
            echo "$VAULT_PASSWORD"
            echo "*****"
        fi

        echo "PGPASSWORD=\$POSTGRES_PASSWORD psql -U postgres -c \"create user application_dev with encrypted password '$VAULT_PASSWORD'\"" > /tmp/script.sh
        echo "PGPASSWORD=\$POSTGRES_PASSWORD psql -U postgres -c \"grant all privileges on database application to application_dev\"" >> /tmp/script.sh
        echo "PGPASSWORD=\$POSTGRES_PASSWORD psql -U postgres -c \"alter user application_dev with SUPERUSER\"" >> /tmp/script.sh

        # create secret 'init-script-secret'
        kubectl create secret generic ${INIT_SCRIPT} --from-file=/tmp/script.sh
#        rm /tmp/script.sh
    fi
}


