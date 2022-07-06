#!/bin/bash

source util.sh

#get_credentials "clusters" "weekly-28"
get_credentials "clusters" "weekly-27" || { echo -e "ERROR: Source cluster \"source_cluster\" not found." >&2; exit 1; }

#get_credentials "clusters" "weekly-27" >/dev/null

verify_cluster_access