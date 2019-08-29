#!/usr/bin/env bash
set -e
source /dev/stdin <<< $(curl -s https://raw.githubusercontent.com/azohra/bash-lib/master/bash-lib.sh)
keychain_vault_prod="vault-config"
keychain_refresh_tokens="vault-refresh-token"

init_secrets_with_json () {
  security add-generic-password -a "$keychain_vault_prod" -s "client_id" -w $(echo "$1" | jq -r ".client_id")
  security add-generic-password -a "$keychain_vault_prod" -s "client_secret" -w $(echo "$1" | jq -r ".client_secret")
  security add-generic-password -a "$keychain_vault_prod" -s "target_id" -w $(echo "$1" | jq -r ".target_id")
  security add-generic-password -a "$keychain_vault_prod" -s "vault_url" -w $(echo "$1" | jq -r ".vault_url")

  local token=""
  while [ -z $token ]; do
      announce "Please paste your vault token below (find this by clicking on the top left button in the vault ui):" 1
      read -r token
      test -z $token && announce "Incoreect input!" 4
  done
  security add-generic-password -a "$keychain_vault_prod" -s "vault_token" -w "$token"
}

clear_secrets() {
  gcloud_account=$(gcloud config get-value account)
  keychain_del "$keychain_vault_prod" "client_id" &&\
  keychain_del "$keychain_vault_prod" "client_secret" &&\
  keychain_del "$keychain_vault_prod" "target_id" &&\
  keychain_del "$keychain_vault_prod" "vault_url" &&\
  keychain_del "$keychain_vault_prod" "vault_token" &&\
  keychain_del "$keychain_refresh_tokens" "$gcloud_account" &&\
  echo "You have been logged out!" || echo "Not logged in!"
}

ensure_secret () {
  if [[ "$(keychain_get "$keychain_vault_prod" "$1")" != "" ]]; then
    export $1=$(keychain_get "$keychain_vault_prod" "$1" != "")
  else
    announce "Secret $1 could not be found in the keychain. \nPlease run: \n\n\t security add-generic-password -a \"$keychain_vault_prod\" -s \"$1\" -w \"\${$1_value}\" \n\nIf you don't know the values, please ask your friendly neighbourhood devops engineer." 4
    exit 1
  fi
}

ensure_refresh_token () {
  gcloud_account=$(gcloud config get-value account)
  # keychain_get "$keychain_refresh_tokens" "$gcloud_account"
  # keychain_del "$keychain_refresh_tokens" "$gcloud_account" 
  if [[ "$(keychain_get "$keychain_refresh_tokens" "$gcloud_account")" != "" ]]; then
    export refresh_token=$(keychain_get "$keychain_refresh_tokens" "$gcloud_account" != "")
  else
    announce "Require an auth code for account $gcloud_account. Please sign in and paste the auth code here:" >> /dev/stderr
    open "https://accounts.google.com/o/oauth2/v2/auth?client_id=$client_id&response_type=code&scope=openid%20email&access_type=offline&redirect_uri=urn:ietf:wg:oauth:2.0:oob"
    auth=""
    read -r auth
    export refresh_token=$(curl --silent \
            --data client_id=$client_id\
            --data client_secret=$client_secret \
            --data code=$auth \
            --data redirect_uri=urn:ietf:wg:oauth:2.0:oob \
            --data grant_type=authorization_code \
            https://www.googleapis.com/oauth2/v4/token | jq -r ".refresh_token")
    keychain_set "$keychain_refresh_tokens" "$gcloud_account" "$refresh_token"
  fi
}

validate () {
  which -s sqlite3 || (announce "You don't have sqlite3 installed! That's weird..." 4; exit 1)
  ensure_secret "client_id"
  ensure_secret "client_secret"
  ensure_secret "target_id"
  ensure_secret "vault_token"
  ensure_secret "vault_url"
}


get_vault_kv() {
  curl --silent -H "Authorization: Bearer $(curl --silent \
          --data client_id=$client_id \
          --data client_secret=$client_secret \
          --data refresh_token=$refresh_token \
          --data grant_type=refresh_token \
          --data audience=$target_id \
          https://www.googleapis.com/oauth2/v4/token | jq -r ".id_token")" \
          -H "X-Vault-Token: $vault_token" "$vault_url/v1/$1/data/$2" | jq -r ".data.data"
}

if [[ -z "$1" ]]; then
  announce "Incorrect usage!" 4 >> /dev/stderr
  exit 1
fi


case "$1" in
  # Commands...
  login)
    init_json=""
    vault_token=""
    if [[ $2 ]]; then
      init_json=`cat $2`
    else
      read -r init_json
    fi
    init_secrets_with_json "$init_json"
    exit
  ;;
  logout)
    clear_secrets
    exit
  ;;
  get_kv)
    validate
    ensure_refresh_token
    get_vault_kv "$2" "$3"
    exit
  ;;
  *)
    announce "unknown command: $key" 4 >> /dev/stderr
    exit 1
  ;;
esac
