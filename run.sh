#!/bin/bash

# Configuration
CONFIG_FILE="/usr/local/etc/haproxy/haproxy.cfg"
TEMP_MSG_FILE="/tmp/tg_msg_id.txt"
USER_TEMP_MSG="/tmp/user_msg_id.txt"
PHOTO_URL="https://t.me/l_s_1_1/159"

# Default Credentials
[ -z "$USER" ] && USER="Arsen1k"
[ -z "$PASS" ] && PASS="Speed123"

echo "🚀 Launching Arsen1k Hard-Rotation Engine (Final Fixed)..."

# --- Function: Get Railway Billing Data (Safe Version) ---
get_railway_data() {
    COST="0.00"
    if [ -n "$RAILWAY_API_KEY" ]; then
        # Fetching data with a fallback to 0 if null
        RAW_COST=$(curl -s -X POST https://backboard.railway.app/graphql \
            -H "Authorization: Bearer $RAILWAY_API_KEY" \
            -H "Content-Type: application/json" \
            -d '{"query": "{ me { consumption { estimatedCost } } }" }' | jq -r '.data.me.consumption.estimatedCost // 0')
        
        # Check if RAW_COST is a valid number
        if [[ "$RAW_COST" =~ ^[0-9.]+$ ]]; then COST=$RAW_COST; fi
    fi
    REMAINING_CREDIT=$(echo "5.00 - $COST" | bc -l | sed 's/^\./0./')
}

# --- Function: Get Telegram User First Name ---
get_tg_name() {
    if [ -n "$USER_ID" ]; then
        TG_NAME=$(curl -s "https://api.telegram.org/bot$TELEGRAM_TOKEN/getChat?chat_id=$USER_ID" | jq -r '.result.first_name // "User"')
    else
        TG_NAME="User"
    fi
}

# --- Function: Send Notifications ---
send_notifications() {
    local is_update=$1
    get_railway_data
    get_tg_name
    
    # Calculate Traffic (Egress $0.05/GB)
    USED_GB=$(echo "$COST / 0.05" | bc -l | sed 's/^\./0./' | cut -c1-4)
    REMAINING_GB=$(echo "(5.00 - $COST) / 0.05" | bc -l | sed 's/^\./0./' | cut -c1-5)

    # 1. User Message (Welcome + Consumption)
    if [ -n "$USER_ID" ]; then
        USER_MSG="<blockquote>Welcome, <b>$TG_NAME</b>! 🚀</blockquote>
👤 <b>User:</b> <code>$USER</code>
💰 <b>Credit:</b> <code>$REMAINING_CREDIT $</code>
📉 <b>Used Traffic:</b> <code>$USED_GB GB</code>
🚀 <b>Remaining Traffic:</b> <code>$REMAINING_GB GB</code>

<blockquote><b>Proxy Info:</b>
<code>$USER:$PASS@$FINAL_IP:$RAILWAY_TCP_PROXY_PORT</code></blockquote>"

        # الميزة الجديدة: زر شفاف ملون باستخدام alert URL لإظهار التعليمات
        ALERT_TEXT="To change credentials, send message as: User:Pass"
        KEYBOARD='{"inline_keyboard":[[{"text":"🔄 Change User:Pass","url":"https://t.me/share/url?url=Instructions:&text=Send%20new%20creds%20in%20format%20User:Pass"}]]}'

        if [ "$is_update" = "false" ]; then
            RESP=$(curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendPhoto" \
                -d "chat_id=$USER_ID" -d "photo=$PHOTO_URL" -d "caption=$USER_MSG" \
                -d "parse_mode=HTML" -d "reply_markup=$KEYBOARD")
            echo "$RESP" | jq -r '.result.message_id' > $USER_TEMP_MSG
        else
            MSG_ID=$(cat $USER_TEMP_MSG 2>/dev/null)
            [ -n "$MSG_ID" ] && curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/editMessageCaption" \
                -d "chat_id=$USER_ID" -d "message_id=$MSG_ID" \
                -d "caption=$USER_MSG" -d "parse_mode=HTML" -d "reply_markup=$KEYBOARD" > /dev/null
        fi
    fi

    # 2. Owner Message (Admin Dashboard)
    if [ -n "$OWNER_ID" ]; then
        COUNTRY_CODE=$(curl -s https://ipinfo.io/country)
        [ -z "$COUNTRY_CODE" ] && COUNTRY_CODE="EG"
        
        OWNER_MSG="<blockquote>🚀 <b>High-Speed Proxy Online</b></blockquote>
🌍 <b>Country:</b> $COUNTRY_CODE
🌐 <b>IP:</b> <code>$FINAL_IP</code>
🔌 <b>Port:</b> <code>$RAILWAY_TCP_PROXY_PORT</code>
👤 <b>User:</b> <code>$USER</code>
🔑 <b>Pass:</b> <code>$PASS</code>
🔢 <b>Active Proxies:</b> $COUNT
<blockquote><b>========== HTTP Custom ==========</b></blockquote>
<code>$USER:$PASS@$FINAL_IP:$RAILWAY_TCP_PROXY_PORT</code>"

        if [ "$is_update" = "true" ] && [ -f "$TEMP_MSG_FILE" ]; then
            MSG_ID=$(cat $TEMP_MSG_FILE)
            curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/editMessageText" \
                -d "chat_id=$OWNER_ID" -d "message_id=$MSG_ID" \
                -d "text=$OWNER_MSG" -d "parse_mode=HTML" > /dev/null
        else
            RESP=$(curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage" \
                -d "chat_id=$OWNER_ID" -d "text=$OWNER_MSG" -d "parse_mode=HTML")
            echo "$RESP" | jq -r '.result.message_id' > $TEMP_MSG_FILE
        fi
    fi
}

# --- Core Logic ---
update_system() {
    local is_update=$1
    echo "📥 Updating HAProxy configuration..."
    
    PROXIES=$(psql "$DATABASE_URL" -t -c "SELECT proxy_data FROM proxy_pool;" | xargs)
    sed -i '/    server /d' $CONFIG_FILE
    COUNT=0
    for VAL in $PROXIES; do
        IP_PORT=$(echo $VAL | cut -d'@' -f2)
        [ -n "$IP_PORT" ] && ((COUNT++)) && echo "    server srv_$COUNT $IP_PORT check maxconn 1" >> $CONFIG_FILE
    done

    FINAL_IP=$(getent hosts $RAILWAY_TCP_PROXY_DOMAIN | awk '{ print $1 }' | head -n 1)
    [ -z "$FINAL_IP" ] && FINAL_IP="0.0.0.0"

    # HAProxy Management
    if [ "$is_update" = "true" ] && [ -f "/tmp/haproxy.pid" ]; then
        haproxy -f $CONFIG_FILE -p /tmp/haproxy.pid -sf $(cat /tmp/haproxy.pid) &
    else
        haproxy -f $CONFIG_FILE -p /tmp/haproxy.pid &
    fi

    send_notifications "$is_update"
}

# Initial Run
update_system "false"
LAST_KNOWN_COUNT=$COUNT

# --- Monitoring Loop ---
while true; do
    sleep 60
    CURRENT_DB_COUNT=$(psql "$DATABASE_URL" -t -c "SELECT COUNT(*) FROM proxy_pool;" | xargs 2>/dev/null)
    
    # Validation for integer comparison
    if [[ "$CURRENT_DB_COUNT" =~ ^[0-9]+$ ]]; then
        if [ "$CURRENT_DB_COUNT" -ne "$LAST_KNOWN_COUNT" ]; then
            echo "🔔 Change detected in DB!"
            update_system "true"
            LAST_KNOWN_COUNT=$CURRENT_DB_COUNT
        fi
    fi
    
    echo "--- System Heartbeat ---"
    echo "User: $USER | IP: $FINAL_IP | DB Count: $CURRENT_DB_COUNT"
done
