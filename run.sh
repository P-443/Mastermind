#!/bin/bash

# Configuration & Env Variables
CONFIG_FILE="/usr/local/etc/haproxy/haproxy.cfg"
TEMP_MSG_FILE="/tmp/tg_msg_id.txt"
USER_TEMP_MSG="/tmp/user_msg_id.txt"
PHOTO_URL="https://t.me/l_s_1_1/159"

# Default Credentials (if not set in Env)
[ -z "$USER" ] && USER="Arsen1k"
[ -z "$PASS" ] && PASS="Speed123"

echo "🚀 Starting Arsen1k Logic with Railway API integration..."

# --- Function to fetch Railway Billing Data ---
get_railway_data() {
    if [ -n "$RAILWAY_API_KEY" ]; then
        # Query Railway GraphQL for consumption (Simplified)
        # ملاحظة: جلب الرصيد الفعلي يتطلب API محدد، هنا سنحسب التقديري بناءً على استهلاك الـ Egress
        CONSUMPTION_DATA=$(curl -s -X POST https://backboard.railway.app/graphql \
            -H "Authorization: Bearer $RAILWAY_API_KEY" \
            -H "Content-Type: application/json" \
            -d '{"query": "{ me { consumption { estimatedCost } } }" }')
        
        COST=$(echo "$CONSUMPTION_DATA" | jq -r '.data.me.consumption.estimatedCost // 0')
        REMAINING_CREDIT=$(echo "5.00 - $COST" | bc -l) # Hobby plan starts with $5
    else
        COST="0.00"
        REMAINING_CREDIT="N/A"
    fi
}

# --- Function to Send/Update Message to User & Owner ---
send_notifications() {
    local is_update=$1
    get_railway_data
    
    # Calculate Traffic (Mockup based on Railway egress logic)
    # Railway egress cost is $0.05 per GB
    USED_GB=$(echo "$COST / 0.05" | bc -l | sed 's/^\./0./' | cut -c1-4)
    REMAINING_GB=$(echo "(5.00 - $COST) / 0.05" | bc -l | sed 's/^\./0./' | cut -c1-5)

    # 1. Message for USER_ID
    if [ -n "$USER_ID" ]; then
        USER_MSG="<blockquote>Welcome to <b>Arsen1k Proxy Service</b></blockquote>
👤 <b>User:</b> <code>$USER</code>
💰 <b>Credit:</b> <code>$REMAINING_CREDIT $</code>
📉 <b>Used Traffic:</b> <code>$USED_GB GB</code>
🚀 <b>Remaining Traffic:</b> <code>$REMAINING_GB GB</code>

<blockquote><b>Proxy Info:</b>
<code>$USER:$PASS@$FINAL_IP:$RAILWAY_TCP_PROXY_PORT</code></blockquote>

⚠️ <i>To change credentials, send message as: <b>User:Pass</b></i>"

        # Using Inline Keyboard for styling
        KEYBOARD='{"inline_keyboard":[[{"text":"🔄 Change User:Pass","callback_data":"change_cred"}]]}'

        if [ "$is_update" = "false" ]; then
            curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendPhoto" \
                -d "chat_id=$USER_ID" -d "photo=$PHOTO_URL" -d "caption=$USER_MSG" \
                -d "parse_mode=HTML" -d "reply_markup=$KEYBOARD" > /dev/null
        else
            # Edit Caption if update
            curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/editMessageCaption" \
                -d "chat_id=$USER_ID" -d "message_id=$(cat $USER_TEMP_MSG)" \
                -d "caption=$USER_MSG" -d "parse_mode=HTML" > /dev/null
        fi
    fi

    # 2. Message for OWNER_ID (Full details)
    if [ -n "$OWNER_ID" ]; then
        OWNER_MSG="<blockquote>🛡️ <b>Admin Dashboard (Arsen1k)</b></blockquote>
🖥️ <b>Server Status:</b> Online
🌍 <b>IP:</b> <code>$FINAL_IP</code>
📊 <b>Active Proxies in DB:</b> $COUNT
💸 <b>Total Est. Cost:</b> <code>$COST $</code>"

        curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage" \
            -d "chat_id=$OWNER_ID" -d "text=$OWNER_MSG" -d "parse_mode=HTML" > /dev/null
    fi
}

# --- Main Logic (HAProxy Update) ---
update_system() {
    local is_update=$1
    echo "📥 Processing Proxy Pool..."
    
    # Check Database and Update HAProxy (Your original logic)
    PROXIES=$(psql "$DATABASE_URL" -t -c "SELECT proxy_data FROM proxy_pool;" | xargs)
    sed -i '/    server /d' $CONFIG_FILE
    COUNT=0
    for VAL in $PROXIES; do
        IP_PORT=$(echo $VAL | cut -d'@' -f2)
        [ -n "$IP_PORT" ] && ((COUNT++)) && echo "    server srv_$COUNT $IP_PORT check maxconn 1" >> $CONFIG_FILE
    done

    # Get Network Info
    FINAL_IP=$(getent hosts $RAILWAY_TCP_PROXY_DOMAIN | awk '{ print $1 }' | head -n 1)
    [ -z "$FINAL_IP" ] && FINAL_IP="0.0.0.0"

    # Reload HAProxy
    if [ "$is_update" = "true" ] && [ -f "/tmp/haproxy.pid" ]; then
        haproxy -f $CONFIG_FILE -p /tmp/haproxy.pid -sf $(cat /tmp/haproxy.pid) &
    else
        haproxy -f $CONFIG_FILE -p /tmp/haproxy.pid &
    fi

    send_notifications "$is_update"
}

# Initial Startup
update_system "false"

# --- Listening for Credential Changes (Simple Poll) ---
# ملاحظة: في Bash، نحتاج لـ Loop لجلب آخر رسالة من المستخدم لتغيير الباسورد
echo "🔄 Monitoring DB and Telegram for changes..."
while true; do
    # 1. Check DB Changes (Every 60s)
    sleep 60
    CURRENT_DB_COUNT=$(psql "$DATABASE_URL" -t -c "SELECT COUNT(*) FROM proxy_pool;" | xargs)
    
    # 2. Check for Telegram Messages to change Pass (Optional Logic)
    # يمكن تطوير هذا الجزء بـ webhook أو جلب آخر رسالة بـ getUpdates
    
    if [ "$CURRENT_DB_COUNT" -ne "$LAST_KNOWN_COUNT" ]; then
        update_system "true"
        LAST_KNOWN_COUNT=$CURRENT_DB_COUNT
    fi
    
    # Print to Terminal for debugging
    echo "--- System Heartbeat ---"
    echo "User: $USER | IP: $FINAL_IP | DB Count: $CURRENT_DB_COUNT"
done
