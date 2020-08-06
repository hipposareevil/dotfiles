# Work related


# update metrics service name
w.update.metrics.name() {
    if [[ "$1" == "-h" ]]; then
        echo "Usage: $0 [service name]"
        echo "Set the service name for metrics"
        echo ""
        echo "Example:"
        echo "$0 superfunk-application"
        return 1
    fi

    new_name="$1"

    # validate we are in correct repo
    git_remote=$(git remote -v 2>&1 | head -1)
    if [[ $git_remote != *"einstein/application-service.git"* ]]; then
        echo "Must be in the application-service git repo directory: 'github.salesforceiq.com/einstein/application-service.git'"
        return 1
    fi

    # get root of repo
    git_root=$(git rev-parse --show-toplevel)

    file_to_update="${git_root}/application-service-metrics/src/main/java/com/salesforce/einstein/appservice/metrics/config/AppServiceMetricsConfig.java"

    # change file
    sed -i -e s/AppServiceMetric.Tags.APPLICATION_SERVICE/\"$new_name\"/ $file_to_update

    echo "Updated file:"
    echo $file_to_update
}

#######
# maven
function m.core {
    echo "Changing maven for core."
    cp ~/.m2/settings.xml.core  ~/.m2/settings.xml
}

function m.einstein {
    echo "Changing maven for einstein."
    cp ~/.m2/settings.xml.e1  ~/.m2/settings.xml
}

vaultsel () {
	local vaults vault_ldap_user
	vault_ldap_user="samuel.jackson" 
	vaults=("https://vault-ops.build-usw2.platform.einstein.com" "https://vault.build-usw2.platform.einstein.com" "https://vault.dev.platform.einstein.com" "https://vault.staging.platform.einstein.com" "https://vault.rc.platform.einstein.com" "https://vault.prod.platform.einstein.com" "https://vault.rc-euc1.platform.einstein.com" "https://vault.prod-euc1.platform.einstein.com" "https://vault.perf-usw2.platform.einstein.com") 
	VAULT_ADDR=$(printf '%s\n' "${vaults[@]}" | fzf) 
	export VAULT_ADDR
	unset VAULT_TOKEN
	if ! vault token lookup > /dev/null 2>&1
	then
		vault login -no-print -method="ldap" username="$vault_ldap_user"
	fi
	VAULT_TOKEN=$(vault print token) 
	export VAULT_TOKEN
	echo "Switched to Vault cluster \"${VAULT_ADDR}\""
}

