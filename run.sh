#!/bin/bash

# Configuration
CONFIG_FILE="/usr/local/etc/haproxy/haproxy.cfg"
USER="Arsen"
PASS="@Ar_s"
TEMP_MSG_FILE="/tmp/tg_msg_id.txt"

echo "🚀 Launching Arsen1k Hard-Rotation Engine (DB Mode)..."

# 1. Check for Database URL
if [ -z "$DATABASE_URL" ]; then
    echo "❌ ERROR: DATABASE_URL is not set!"
    exit 1
fi

# Function to get Country Flag Emoji
get_flag() {
    local code=$(echo "$1" | tr '[:lower:]' '[:upper:]')
    if [ -z "$code" ]; then echo "🏳️"; return; fi
    # Convert ISO code to Regional Indicator Symbols
    printf "\\U$(printf '%x' $((0x1F1E6 + $(printf '%d' "'${code:0:1}") - 65)))\\U$(printf '%x' $((0x1F1E6 + $(printf '%d' "'${code:1:1}") - 65)))"
}

# Function to Update HAProxy and TG Message
update_system() {
    local is_update=$1
    echo "📥 Fetching proxies from Database..."
    PROXIES=$(psql "$DATABASE_URL" -t -c "SELECT proxy_data FROM proxy_pool;" | xargs)
    
    # Clean old servers
    sed -i '/    server /d' $CONFIG_FILE
    
    COUNT=0
    for VAL in $PROXIES; do
        IP_PORT=$(echo $VAL | cut -d'@' -f2)
        if [ -n "$IP_PORT" ]; then
            ((COUNT++))
            echo "    server srv_$COUNT $IP_PORT check maxconn 1" >> $CONFIG_FILE
        fi
    done

    # Reload HAProxy
    if [ "$is_update" = "true" ]; then
        haproxy -f $CONFIG_FILE -p /tmp/haproxy.pid -sf $(cat /tmp/haproxy.pid) &
    else
        haproxy -f $CONFIG_FILE -p /tmp/haproxy.pid &
    fi

    # Network Info
    FINAL_IP=$(getent hosts $RAILWAY_TCP_PROXY_DOMAIN | awk '{ print $1 }' | head -n 1)
    [ -z "$FINAL_IP" ] && FINAL_IP="0.0.0.0"
    COUNTRY_CODE=$(curl -s https://ipinfo.io/country)
    FLAG=$(get_flag "$COUNTRY_CODE")

    # Prepare Telegram Message
    MSG="🚀 <b>High-Speed Proxy Online</b>

🌍 <b>Country:</b> $FLAG $COUNTRY_CODE
🌐 <b>IP:</b> <code>$FINAL_IP</code>
🔌 <b>Port:</b> <code>$RAILWAY_TCP_PROXY_PORT</code>
👤 <b>User:</b> <code>$USER</code>
🔑 <b>Pass:</b> <code>$PASS</code>
🔢 <b>Active Proxies:</b> $COUNT

<b>========== HTTP Custom ==========</b>
<code>Ars1k:$PASS@$FINAL_IP:$RAILWAY_TCP_PROXY_PORT</code>"

    if [ -n "$TELEGRAM_TOKEN" ] && [ -n "$OWNER_ID" ]; then
        if [ "$is_update" = "true" ] && [ -f "$TEMP_MSG_FILE" ]; then
            # Edit existing message
            MSG_ID=$(cat $TEMP_MSG_FILE)
            curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/editMessageText" \
                -d "chat_id=$OWNER_ID" \
                -d "message_id=$MSG_ID" \
                -d "text=$MSG" \
                -d "parse_mode=HTML" > /dev/null
            echo "🔄 Telegram message updated. Active: $COUNT"
        else
            # Send new message and save ID
            RESP=$(curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage" \
                -d "chat_id=$OWNER_ID" \
                -d "text=$MSG" \
                -d "parse_mode=HTML")
            echo "$RESP" | jq -r '.result.message_id' > $TEMP_MSG_FILE
            echo "📤 Initial Telegram message sent."
        fi
    fi
    LAST_KNOWN_COUNT=$COUNT
}

# Initial execution
update_system "false"

# 2. Monitoring Loop (Every 1 minute for 3 minutes)
echo "🛡️ Starting stability monitor for 3 minutes..."
for i in {1..3}; do
    sleep 60
    CURRENT_DB_COUNT=$(psql "$DATABASE_URL" -t -c "SELECT COUNT(*) FROM proxy_pool;" | xargs)
    
    if [ "$CURRENT_DB_COUNT" -ne "$LAST_KNOWN_COUNT" ]; then
        echo "🔔 Change detected! (New: $CURRENT_DB_COUNT, Old: $LAST_KNOWN_COUNT)"
        update_system "true"
    else
        echo "⏳ No changes detected in minute $i."
    fi
done

echo "✅ Monitoring period finished. System is stable."
wait
