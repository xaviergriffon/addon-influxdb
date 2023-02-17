#!/command/with-contenv bashio
# ==============================================================================
# Home Assistant Community Add-on: InfluxDB
# Ensure a user for Chronograf & Kapacitor exists within InfluxDB
# ==============================================================================
declare secret
declare influx_ping

# If secret file exists, skip this script
if bashio::fs.file_exists "/data/secret"; then
    exit 0
fi

# Generate secret based on the Hass.io token
secret="${SUPERVISOR_TOKEN:21:32}"

exec 3< <(influxd)

sleep 3

for i in {1800..0}; do
    influx_ping=$(influx ping)
    if [ $influx_ping = "OK" ]; then
        break;
    fi
    bashio::log.info "InfluxDB init process in progress..."
    sleep 5
done

if [[ "$i" = 0 ]]; then
    bashio::exit.nok "InfluxDB init process failed."
fi
influx setup -u homeassistant -p ${secret} -o homeassistant -b homeassistant -r 0 -f \
        &> /dev/null || true

influx user create -n chronograf -p ${secret} -o homeassistant \
        &> /dev/null || true

influx user create -n kapacitor -p ${secret} -o homeassistant \
        &> /dev/null || true

kill "$(pgrep influxd)" >/dev/null 2>&1

# Save secret for future use
echo "${secret}" > /data/secret
