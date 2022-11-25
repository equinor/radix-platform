function listandindex() {
    local ip_whitelist="$1"
    local location
    local ip
    j=0

    printf "${fmt}" "    #" "Location" "IP"
    while read -r i; do
        location=$(jq -n "${i}" | jq -r .location)
        ip=$(jq -n "${i}" | jq -r .ip)
        current_ip_whitelist+=("{\"id\":\"${j}\",\"location\":\"${location}\",\"ip\":\"${ip}\"},")
        printf "${fmt}" "   (${j})" "${location}" "${ip}"
        ((j=j+1))
    done < <(printf "%s" "${ip_whitelist}" | jq -c '.whitelist[]')
}


function addwhitelist() {
    local ip_whitelist="$1"
    local location
    local ip
    while read -r i; do
        location=$(jq -n "${i}" | jq -r .location)
        ip=$(jq -n "${i}" | jq -r .ip)
        current_ip_whitelist+=("{\"location\":\"${location}\",\"ip\":\"${ip}\"},")
    done < <(printf "%s" "${ip_whitelist}" | jq -c '.whitelist[]')
}

function add-single-ip-to-whitelist(){
    local master_ip_whitelist=$1
    local temp_file_path=$2
    local new_ip=$3
    local new_location=$4
    current_ip_whitelist=("{ \"whitelist\": [ ")
    addwhitelist "${master_ip_whitelist}"
    current_ip_whitelist+=("{\"location\":\"${new_location}\",\"ip\":\"${new_ip}\"}")
    current_ip_whitelist+=(" ] }")
    master_ip_whitelist=$(jq <<<"${current_ip_whitelist[@]}" | jq '.' | jq 'del(.whitelist [] | select(.id == "99"))')
    master_ip_whitelist_base64=$(jq <<<"${master_ip_whitelist[@]}" | jq '{whitelist:[.whitelist[] | {location,ip}]}' | base64)
    echo $master_ip_whitelist_base64 | sed -E 's#\s+##g' > $temp_file_path
}

function delete-single-ip-from-whitelist(){
    local master_ip_whitelist=$1
    local temp_file_path=$2
    local ip_to_delete=$3
    local current_ip_whitelist=("{ \"whitelist\": [ ")
    addwhitelist "${master_ip_whitelist}"
    current_ip_whitelist+=("{\"id\":\"99\",\"location\":\"dummy\",\"ip\":\"0.0.0.0/32\"} ] }")
    master_ip_whitelist=$(jq <<<"${current_ip_whitelist[@]}" | jq '.' | jq "del(.whitelist [] | select(.ip == \"${ip_to_delete}\"))" | jq 'del(.whitelist [] | select(.id == "99"))')
    master_ip_whitelist_base64=$(jq <<<"${master_ip_whitelist[@]}" | jq '{whitelist:[.whitelist[] | {location,ip}]}' | base64)
    echo $master_ip_whitelist_base64 | sed -E 's#\s+##g' > $temp_file_path
}

function run-interactive-ip-whitelist-wizard(){
    local master_ip_whitelist=$1
    local temp_file_path=$2
    local i=0
    local fmt="%-8s%-33s%-12s\n"
    local fmt2="%-41s%-45s\n"
    local current_ip_whitelist=("{ \"whitelist\": [ ")
    while true; do
        printf "\nCurrent whitelist configuration:"
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
        
        listandindex "${master_ip_whitelist}"
        current_ip_whitelist+=("{\"id\":\"99\",\"location\":\"dummy\",\"ip\":\"0.0.0.0/32\"} ] }")
        while true; do
            printf "\n"
            read -r -p "Is above list correct? (Y/n) " yn
            case ${yn} in
            [Yy]*)
                whitelist_ok=true
                break
                ;;
            [Nn]*)
                whitelist_ok=false
                break
                ;;
            *) printf "\nPlease answer yes or no.\n" ;;
            esac
        done

        if [[ ${whitelist_ok} == false ]]; then
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
                printf "\nEnter location: "
                read -r new_location
            done

            while [ -z "${new_ip}" ]; do
                printf "\nEnter ip address in x.x.x.x/y format: "
                read -r new_ip
            done

            printf "\nAdding location %s at %s... " "${new_location}" "${new_ip}"
            current_ip_whitelist=("{ \"whitelist\": [ ")
            addwhitelist "${master_ip_whitelist}"
            update_keyvault=true
            current_ip_whitelist+=("{\"location\":\"${new_location}\",\"ip\":\"${new_ip}\"}")
            current_ip_whitelist+=(" ] }")
            master_ip_whitelist=$(jq <<<"${current_ip_whitelist[@]}" | jq '.' | jq 'del(.whitelist [] | select(.id == "99"))')
            printf "Done.\n"
            unset addip
        fi

        if [[ ${removeip} == true ]]; then
            printf "\nEnter location number of which you want to remove: "

            while [ -z "${delete_ip}" ]; do
                read -r delete_ip
            done

            master_ip_whitelist=$(jq <<<"${current_ip_whitelist[@]}" | jq '.' | jq "del(.whitelist [] | select(.id == \"${delete_ip}\"))" | jq 'del(.whitelist [] | select(.id == "99"))')
            update_keyvault=true
            unset removeip
        fi

        if [[ ${whitelist_ok} == true ]]; then
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
                    whitelist_ok=false
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

    master_ip_whitelist_base64=$(jq <<<"${master_ip_whitelist[@]}" | jq '{whitelist:[.whitelist[] | {location,ip}]}' | base64)
    echo $master_ip_whitelist_base64 | sed -E 's#\s+##g' > $temp_file_path
}