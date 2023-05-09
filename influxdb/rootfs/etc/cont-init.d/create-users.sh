#!/command/with-contenv bashio
# ==============================================================================
# Home Assistant Community Add-on: InfluxDB
# Ensure a user for Chronograf & Kapacitor exists within InfluxDB
# ==============================================================================
declare secret
declare token

# If secret file exists, skip this script
if bashio::fs.file_exists "/data/secret"; then
    exit 0
fi

# Generate secret based on the Hass.io token
secret="${SUPERVISOR_TOKEN:21:32}"

exec 3< <(influxd)

sleep 3

for i in {1800..0}; do
    if influx ping > /dev/null 2>&1; then
        break;
    fi
    bashio::log.info "InfluxDB init process in progress..."
    sleep 5
done

if [[ "$i" = 0 ]]; then
    bashio::exit.nok "InfluxDB init process failed."
fi

influx setup -u homeassistant -p $secret -o homeassistant -b homeassistant/autogen -r 0 -f \
        &> /dev/null || true

cp /root/.influxdbv2/configs /data/configs

influx user create -n chronograf -o homeassistant \
        &> /dev/null || true

influx user create -n kapacitor -o homeassistant \
        &> /dev/null || true

# Generate secret with token create by InfluxDB
token=$(jq --raw-output '.token' <<< "$(influx auth create --description homeassistant_token --all-access --org homeassistant --json)")

kill "$(pgrep influxd)" >/dev/null 2>&1

# Save secret and token for future use
echo "${secret}" > /data/secret
echo "${token}" > /data/token

echo -e "${secret}\n${secret}" | passwd root

curl -sS -X "POST" "http://supervisor/core/api/services/notify/persistent_notification" \
  -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"title\": \"Token InfluxDB2\", \"message\": \"${token} (${secret})\"}"
