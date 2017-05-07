#!/bin/sh
set -e

eval "$(jq -r '@sh "TOKEN=\(.token) REGION=\(.region) PLAN=\(.plan)  IMAGE=\(.image) SSH_KEYS=\(.ssh_keys) NAME=\(.name)"')"

response=$(curl -w "%{http_code}" --silent -H "API-Key: $TOKEN" \
  https://api.vultr.com/v1/server/create \
  --data "label=$NAME" \
  --data "hostname=$NAME" \
  --data "DCID=$REGION" \
  --data "VPSPLANID=$PLAN" \
  --data "OSID=$IMAGE" \
  --data "SSHKEYID=$SSH_KEYS" \
  --data "enable_private_network=yes" \
  --data "notify_activate=no")

http_code="${response:${#response}-3}"
body="${response:0:${#response}-3}"

if [ "$http_code" != 200 ]; then
  >&2 echo "$http_code - $body"
  exit 1
fi

id=$(jq -r '.SUBID' <<<"$body")

jq -n --arg id "$id" '{"id":$id}'

exit 0
