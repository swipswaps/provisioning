#!/bin/sh
set -e

eval "$(jq -r '@sh "TOKEN=\(.token) SUBID=\(.id)"')"

status=
while [ "$status" != "active" ]; do
  response=$(curl --silent -H "API-Key: $TOKEN" \
    https://api.vultr.com/v1/server/list?SUBID=$SUBID)


  status=$(jq -r ".status" <<<"$response")
  sleep 5
done

public_ip=$(jq -r ".main_ip" <<<"$response")
private_ip=$(jq -r ".internal_ip" <<<"$response")
name=$(jq -r ".label" <<<"$response")

jq -n \
  --arg public_ip "$public_ip" \
  --arg private_ip "$private_ip" \
  --arg name "$name" \
  '{"public_ip":$public_ip,"private_ip":$private_ip,"name":$name}'

exit 0
