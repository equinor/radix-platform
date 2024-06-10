function listandindex() {
    local ip_clusters="$1"
    local name
    local ip
    j=0

    printf "${fmt}" "    #" "Location" "IP"
    while read -r i; do
        name=$(jq -n "${i}" | jq -r .name)
        ip=$(jq -n "${i}" | jq -r .ip)
        current_ip_clusters+=("{\"id\":\"${j}\",\"name\":\"${name}\",\"ip\":\"${ip}\"},")
        printf "${fmt}" "   (${j})" "${name}" "${ip}"
        ((j = j + 1))
    done < <(printf "%s" "${ip_clusters}" | jq -c '.clusters[]')
}

function addclusters() {
    local ip_clusters="$1"
    local name
    local ip
    while read -r i; do
        name=$(jq -n "${i}" | jq -r .name)
        ip=$(jq -n "${i}" | jq -r .ip)
        current_ip_clusters+=("{\"name\":\"${name}\",\"ip\":\"${ip}\"},")
    done < <(printf "%s" "${ip_clusters}" | jq -c '.clusters[]')
}

function add-single-ip-to-clusters() {
    local master_ip_clusters=$1
    local temp_file_path=$2
    local new_ip=$3
    local new_location=$4
    current_ip_clusters=("{ \"clusters\": [ ")
    addclusters "${master_ip_clusters}"
    current_ip_clusters+=("{\"name\":\"${new_location}\",\"ip\":\"${new_ip}\"}")
    current_ip_clusters+=(" ] }")
    master_ip_clusters=$(jq <<<"${current_ip_clusters[@]}" | jq '.' | jq 'del(.clusters [] | select(.id == "99"))')
    master_ip_clusters_base64=$(jq <<<"${master_ip_clusters[@]}" | jq '{clusters:[.clusters[] | {name,ip}]}' | base64)
    echo $master_ip_clusters_base64 | sed -E 's#\s+##g' >$temp_file_path
}

function delete-single-ip-from-clusters() {
    local master_ip_clusters=$1
    local temp_file_path=$2
    local name_to_delete=$3
    local current_ip_clusters=("{ \"clusters\": [ ")
    addclusters "${master_ip_clusters}"
    current_ip_clusters+=("{\"id\":\"99\",\"name\":\"dummy\",\"ip\":\"0.0.0.0\"} ] }")
    master_ip_clusters=$(jq <<<"${current_ip_clusters[@]}" | jq '.' | jq "del(.clusters [] | select(.name == \"${name_to_delete}\"))" | jq 'del(.clusters [] | select(.id == "99"))')
    master_ip_clusters_base64=$(jq <<<"${master_ip_clusters[@]}" | jq '{clusters:[.clusters[] | {name,ip}]}' | base64)
    echo $master_ip_clusters_base64 | sed -E 's#\s+##g' >$temp_file_path
}

function run-interactive-ip-clusters-wizard() {
    local master_ip_clusters
    local temp_file_path
    local USER_PROMPT
    local i
    local fmt
    local fmt2
    local current_ip_clusters

    master_ip_clusters=$1
    temp_file_path=$2
    USER_PROMPT=$3
    i=0
    fmt="%-8s%-33s%-12s\n"
    fmt2="%-41s%-45s\n"
    current_ip_clusters=("{ \"clusters\": [ ")

    if [[ -z "${USER_PROMPT}" ]]; then
        USER_PROMPT=true
    fi

    while true; do
        printf "\nCurrent clusters configuration:"
        printf "\n"
        printf "\n   > WHERE:"
        printf "\n   ------------------------------------------------------------------"
        printf "\n   -  RADIX_ZONE                       : %s" "${RADIX_ZONE}"
        printf "\n   -  AZ_RADIX_ZONE_LOCATION           : %s" "${AZ_RADIX_ZONE_LOCATION}"
        printf "\n   -  AZ_RESOURCE_KEYVAULT             : %s" "${AZ_RESOURCE_KEYVAULT}"
        printf "\n   -  SECRET_NAME                      : %s" "${SECRET_NAME}"
        printf "\n"
        printf "\n   Please inspect and approve the listed networks before you continue:"
        printf "\n"

        listandindex "${master_ip_clusters}"
        current_ip_clusters+=("{\"id\":\"99\",\"name\":\"dummy\",\"ip\":\"0.0.0.0/32\"} ] }")
        if [[ $USER_PROMPT == true ]]; then
            while true; do
                printf "\n"
                read -r -p "Is above list correct? (Y/n) " yn
                case ${yn} in
                [Yy]*)
                    clusters_ok=true
                    break
                    ;;
                [Nn]*)
                    clusters_ok=false
                    break
                    ;;
                *) printf "\nPlease answer yes or no.\n" ;;
                esac
            done
        else
            clusters_ok=true
        fi

        if [[ ${clusters_ok} == false ]]; then
            while true; do
                printf "\n"
                read -r -p "Please press 'a' to add or 'd' to delete entry (a/d) " adc
                case ${adc} in
                [Aa]*)
                    addip=true
                    removeip=false
                    break
                    ;;
                [Dd]*)
                    removeip=true
                    addip=false
                    break
                    ;;
                [Cc]*) break ;;
                *) printf "\nPlease press 'a' or 'd' (Hit 'C' to cancel any updates).\n" ;;
                esac
            done
        fi

        if [[ ${addip} == true ]]; then
            while [ -z "${new_location}" ]; do
                printf "\nEnter name: "
                read -r new_location
            done

            while [ -z "${new_ip}" ]; do
                printf "\nEnter ip address in x.x.x.x format: "
                read -r new_ip
            done

            printf "\nAdding name %s at %s... " "${new_location}" "${new_ip}"
            current_ip_clusters=("{ \"clusters\": [ ")
            addclusters "${master_ip_clusters}"
            update_keyvault=true
            current_ip_clusters+=("{\"name\":\"${new_location}\",\"ip\":\"${new_ip}\"}")
            current_ip_clusters+=(" ] }")
            master_ip_clusters=$(jq <<<"${current_ip_clusters[@]}" | jq '.' | jq 'del(.clusters [] | select(.id == "99"))')
            printf "Done.\n"
            unset addip
        fi

        if [[ ${removeip} == true ]]; then
            printf "\nEnter name number of which you want to remove: "

            while [ -z "${delete_ip}" ]; do
                read -r delete_ip
            done

            master_ip_clusters=$(jq <<<"${current_ip_clusters[@]}" | jq '.' | jq "del(.clusters [] | select(.id == \"${delete_ip}\"))" | jq 'del(.clusters [] | select(.id == "99"))')
            update_keyvault=true
            unset removeip
        fi

        if [[ ${clusters_ok} == true ]]; then
            break
        else
            printf "\n"
            while true; do
                read -r -p "Are you finished with list and update Azure? (Y/n) " yn
                case ${yn} in
                [Yy]*)
                    finished_ok=true
                    break
                    ;;
                [Nn]*)
                    clusters_ok=false
                    unset delete_ip
                    unset new_location
                    unset new_ip
                    break
                    ;;
                *) printf "\nPlease answer yes or no." ;;
                esac
            done
            if [[ ${finished_ok} == true ]]; then
                break
            fi

        fi
    done

    master_ip_clusters_base64=$(jq <<<"${master_ip_clusters[@]}" | jq '{clusters:[.clusters[] | {name,ip}]}' | base64)
    echo $master_ip_clusters_base64 | sed -E 's#\s+##g' >$temp_file_path
}

function getWhitelist() {
    if [[ -z "$RADIX_ZONE_ENV" ]]; then
        echo "ERROR: Please provide RADIX_ZONE_ENV" >&2
        exit 1
    else
        if [[ ! -f "$RADIX_ZONE_ENV" ]]; then
            echo "ERROR: RADIX_ZONE_ENV=$RADIX_ZONE_ENV is invalid, the file does not exist." >&2
            exit 1
        fi
        source "$RADIX_ZONE_ENV"
    fi

    SECRET_NAME="acr-clusters-ips-${RADIX_ENVIRONMENT}"
    MASTER_ACR_IP_WHITELIST=$(az keyvault secret show --vault-name "${AZ_RESOURCE_KEYVAULT}" --name "${SECRET_NAME}" --query="value" -otsv | base64 --decode | jq '{clusters:.clusters | sort_by(.name | ascii_downcase)}' 2>/dev/null)

    echo "$MASTER_ACR_IP_WHITELIST"
}

function combineWhitelists() {
    if [[ -z "$RADIX_ZONE_ENV" ]]; then
        echo "ERROR: Please provide RADIX_ZONE_ENV" >&2
        exit 1
    else
        if [[ ! -f "$RADIX_ZONE_ENV" ]]; then
            echo "ERROR: RADIX_ZONE_ENV=$RADIX_ZONE_ENV is invalid, the file does not exist." >&2
            exit 1
        fi
        source "$RADIX_ZONE_ENV"
    fi

    WORKDIR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    RADIX_ZONE_PATH="${WORKDIR_PATH}/../radix-zone"
    combined_clusters=""

    if [[ -d "${RADIX_ZONE_PATH}" ]]; then
        for filename in "${RADIX_ZONE_PATH}"/*.env; do
            if [[ "${filename}" == *test* ]]; then continue; fi
            radix_zone_env_tmp="${filename}"

            combined_clusters+=$(RADIX_ZONE_ENV=${radix_zone_env_tmp} getWhitelist | jq -c '.[]')
            wait # wait for subshell to finish
        done
        unset radix_zone_env_tmp
    else
        printf "ERROR: The radix-zone path is not found\n" >&2
    fi

    echo -e "${combined_clusters}" | jq -s 'add | unique_by(.ip) | sort_by(.name | ascii_downcase)' | jq '{"clusters": .}'
}
