#!/bin/bash
red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
normal=$(tput sgr0)

# Set the directory you want to search
directory="./dev"
find "$directory" -mindepth 1 -maxdepth 1 -type d -exec bash -c '
    for dir; do
        printf "%s► Execute %s%s\n" "${grn}" "$dir" "${normal}"
        #echo "$dir"
        terraform -chdir=$dir plan -no-color
        # Perform actions here for each directory
        # For example, you can add commands to operate on each directory
    done
' bash {} +