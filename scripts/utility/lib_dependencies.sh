#!/usr/bin/env bash


function assert_cli_tools() {
  printf "Check for neccesary executables... "

  hash az 2>/dev/null || {
      echo -e "ERROR: Azure-CLI not found in PATH. Exiting..." >&2
      return 1
  }
  hash kubectl 2>/dev/null || {
      echo -e "ERROR: kubectl not found in PATH. Exiting..." >&2
      return 1
  }
  hash flux 2>/dev/null || {
      echo -e "ERROR: flux not found in PATH. Exiting..." >&2
      return 1
  }
  hash jq 2>/dev/null || {
      echo -e "ERROR: jq not found in PATH. Exiting..." >&2
      return 1
  }
  hash sqlcmd 2>/dev/null || {
      echo -e "ERROR: sqlcmd not found in PATH. Exiting..." >&2
      return 1
  }
  # https://learn.microsoft.com/en-us/sql/tools/sqlcmd/sqlcmd-utility?view=sql-server-ver16&tabs=go%2Clinux&pivots=cs1-bash#find-out-which-version-you-have-installed
  if [[ "$(sqlcmd --version)" = *"SQL Server Command Line Tool"* ]]; then
      echo -e "ERROR: sqlcmd is old ODBC variant. Go variant is required." >&2
      echo -e "https://learn.microsoft.com/en-us/sql/tools/sqlcmd/sqlcmd-utility?view=sql-server-ver16&tabs=go%2Clinux&pivots=cs1-bash#download-and-install-sqlcmd" >&2
      echo -e "Exiting..." >&2
      return 1
  fi

  printf "Done.\n"
  return 0
}

function prepare_azure_session() {
  printf "Logging you in to Azure if not already logged in... "
  az account show >/dev/null || az login >/dev/null
  az account set --subscription "$AZ_SUBSCRIPTION_ID" >/dev/null
  printf "Done.\n"
}

function has_env_name() {
  if [[ -z $(printenv $1) ]]; then
      echo "ERROR: Please provide ${1}" >&2
      return 1
  fi

  return 0
}
