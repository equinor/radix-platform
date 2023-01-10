#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Clean up inactive RadixRegistrations in a cluster. Will stop all components in a RadixRegistration after a time period¸ 
# and will delete all components after a (greater) time period


#######################################################################################
### HOW TO USE
###

# First, set kubectl context to your desired cluster. Then run ./clean_inactive_rrs.sh


echo ""
printf "Check for neccesary executables... "
hash az 2>/dev/null || {
    echo -e "\nERROR: Azure-CLI not found in PATH. Exiting... " >&2
    exit 1
}

hash kubectl 2>/dev/null || {
    echo -e "\nERROR: kubectl not found in PATH. Exiting... " >&2
    exit 1
}

hash kubelogin 2>/dev/null || {
    echo -e "\nERROR: kubelogin not found in PATH. Exiting... " >&2
    exit 1
}

printf "Done.\n"


# Source util scripts
current_path=$(readlink -f $(dirname ${BASH_SOURCE[0]})/)
source $current_path/util.sh

function download_latest_rx_cleanup(){
    output_dir=$1
    mkdir -p $output_dir
    repo="equinor/radix-cluster-cleanup"
    release_ver=$(get_latest_release ${repo})
    ver=$(echo ${release_ver} | sed -e "s/^v//")
    arch=$(uname -m)
    ostype="${OSTYPE}"
    if [[ "$ostype" == "linux-gnu" ]]; then
      ostype="linux"
    fi
    printf "Downloading rx-cleanup ${release_ver} to ${output_dir}..."
    wget -c --quiet https://github.com/${repo}/releases/download/${release_ver}/radix-cluster-cleanup_${ver}_${ostype}_${arch}.tar.gz  -O - | tar -xz -C $output_dir/
}

function prompt_for_confirmation() {
    while true; do
    echo ""
    read -r -p "$1" yn
        case ${yn} in
        [Yy]*)
            break
            ;;
        [Nn]*)
            rm -r $bin_dir
            exit 1
            ;;
        *) printf "\nPlease answer yes or no.\n" ;;
    esac
    done
}

function list_and_stop_inactive_rrs() {
    dir=$1
    current_context=$(cat ~/.kube/config | grep "current-context:" | sed "s/current-context: //")
    $dir/rx-cleanup list-rrs-for-stop
    prompt_for_confirmation "Dry-run complete. Proceed with stopping these RadixRegistrations? Running in k8s context ${current_context} (Y/n) "
    $dir/rx-cleanup stop-inactive-rrs
}

function list_and_delete_inactive_rrs() {
    dir=$1
    current_context=$(cat ~/.kube/config | grep "current-context:" | sed "s/current-context: //")
    $dir/rx-cleanup list-rrs-for-deletion
    prompt_for_confirmation "Dry-run complete. Proceed with deleting these RadixRegistrations? Running in k8s context ${current_context} (Y/n) "
    $dir/rx-cleanup delete-inactive-rrs
}

function verify_current_cluster() {
    current_context=$(cat ~/.kube/config | grep "current-context:" | sed "s/current-context: //")
    prompt_for_confirmation "Current context is ${current_context}. Proceed with script?  (Y/n)"
    echo $current_context | grep playground || prompt_for_confirmation "Are you 100% sure? Current context, $current_context, is NOT playground! (Y/n)"
}

function clean-up-binary() {
  echo "cleaning up ${bin_dir}..." >&2
  bin_dir=$1
  rm -r $bin_dir
}


bin_dir="/tmp/$(uuidgen)"
# the trap function intercepts the SIGINT signal (CTRL+C) and cleans up downloaded binary before exiting
trap "clean-up-binary $bin_dir && exit 2" 2
download_latest_rx_cleanup $bin_dir
verify_current_cluster $bin_dir
list_and_stop_inactive_rrs $bin_dir
list_and_delete_inactive_rrs $bin_dir
