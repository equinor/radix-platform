#!/bin/bash
red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
normal=$(tput sgr0)

if [[ -z "$ENVIRONMENT" ]]; then
    echo "ERROR: Please provide ENVIRONMENT" >&2
    exit 1
fi

if [[ -z "$SUBSCRIPTION" ]]; then
    echo "ERROR: Please provide SUBSCRIPTION" >&2
    exit 1
fi

# Set the directory you want to search
# directory="../${SUBSCRIPTION}/${ENVIRONMENT}"
# directory="../s940/dev/"
directory="../${SUBSCRIPTION}/${ENVIRONMENT}"

for dir in "$directory"/*; do
    if [ ! -d "$dir" ]; then continue; fi

    echo ""
    printf "%s► Execute %s%s\n" "${grn}" "$dir" "${normal}"
    terraform -chdir="$dir" init
    terraform -chdir="$dir" plan -no-color -out=plan.out

    # Add some vertical space incase the previus steps failed
    echo ""

    if [ ! -f "$dir/plan.out" ]; then
        echo "plan.out was not created in $dir"
        continue
    fi

    cd "$dir" || exit
    plan=$(terraform show -no-color "plan.out")
    cd - >/dev/null || exit

    create=$(echo "$plan" | grep "will be created" | sed 's|# |+|g' | sed 's/^ *//g')
    destroy=$(echo "$plan" | grep "will be destroyed" | sed 's|# |-|g' | sed 's/^ *//g')
    update=$(echo "$plan" | grep "will be updated in-place" | sed 's|# |~|g' | sed 's/^ *//g')
    replace=$(echo "$plan" | grep "must be replaced" | sed 's|# |-/+|g' | sed 's/^ *//g')

    if [ -n "$create" ]; then echo -e "The following resources will be created:\n ${grn}${create}${normal}\n"; fi
    if [ -n "$destroy" ]; then echo -e "The following resources will be destroyed:\n ${red}${destroy}${normal}\n"; fi
    if [ -n "$update" ]; then echo -e "The following resources will be updated:\n ${yel}${update}${normal}\n"; fi
    if [ -n "$replace" ]; then echo -e "The following resources will be replaced:\n ${red}${replace}${normal}\n"; fi
    if [ -z "$create$destroy$update$replace" ]; then echo -e "No changes. Your infrastructure matches the configuration.\n"; fi
    rm "$dir/plan.out"
done
