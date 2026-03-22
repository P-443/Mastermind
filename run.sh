#!/bin/bash

# --- 1. Configuration & Env Check ---
CONFIG_FILE="/usr/local/etc/haproxy/haproxy.cfg"
TEMP_MSG_FILE="/tmp/tg_msg_id.txt"
USER_TEMP_MSG="/tmp/user_msg_id.txt"
PHOTO_URL="https://t.me/l_s_1_1/159"

[ -z "$USER" ] && USER="Arsen1k"
[ -z "$PASS" ] && PASS="Speed123"

echo "🚀 Starting Arsen1k Hard-Rotation Engine V3 (Production)..."

# --- 2. Function: Fetch Real Railway Data ---
get_railway_data() {
    COST="0.00"
    if [ -n "$RAILWAY_API_KEY" ] && [ -n "$RAILWAY_PROJECT_ID" ]; then
        # استعلام لجلب استهلاك المشروع الحالي بدقة
        QUERY="query { project(id: \"$RAILWAY_PROJECT_ID\") { usage { estimatedCost } } }"
        RESPONSE=$(curl -s -X POST https://backboard.railway.app/graphql \
            -H "Authorization: Bearer $RAILWAY_API_KEY" \
            -H "Content-Type: application/json" \
            -d "{\"query\": \"$QUERY\"}")

        # التحقق من صحة الرد قبل استخدام jq لمنع parse error
        if echo "$RESPONSE" | jq -e '.data.project.usage' >/dev/null 2>&1; then
            COST=$(echo "$RESPONSE" | jq -r '.data.project.usage.estimatedCost // 0')
        fi
    fi

    # تأمين الأرقام قبل الحساب
    [[ ! "$COST" =~ ^[0-9.]+$ ]] && COST="0.00"

    # الحسابات الفعلية (خطة الـ Hobby تشمل 5$ رصيد)
    REMAINING_CREDIT=$(echo "scale=2; 5.00 - $COST" | bc -l 2>/dev/null | sed 's/^\./0./')
    USED_GB=$(echo "scale=2; $COST / 0.05" | bc -l 2>/dev/null | sed 's/^\./0./')
    REMAINING_GB=$(echo "scale=2; $REMAINING_CREDIT / 0.05" | bc -l 2>/dev/null | sed 's/^\./0./')
    
    # ضمان عدم وجود قيم فارغة
    [ -z "$REMAINING_CREDIT" ] && REMAINING_CREDIT="5.00"
    [ -z "$USED_GB" ] && USED_GB="0.00"
    [ -z "$REMAINING_GB" ] && REMAINING_GB="100.00"
}

# --- 3. Function: Get Telegram Real Name ---
get_tg_name() {
    TG_NAME="User"
    if [ -n "$USER_ID" ] && [ -n "$TELEGRAM_TOKEN" ]; then
        NAME_RESP=$(curl -s "https://api.telegram.org/bot$TELEGRAM_TOKEN/getChat?chat_id=$USER_ID")
        if echo "$NAME_RESP" | jq -e '.result.first_name' >/dev/null 2>&1; then
            TG_NAME=$(echo "$NAME_RESP" | jq -r '.result.first_name')
        fi
    fi
}

# --- 4. Function: Send Multi-Target Notifications ---
send_notifications() {
    local is_update=$1
    get_railway_data
    get_tg_name

    # رسالة اليوزر (مع الصورة والترحيب بالاسم والزر الملون)
    if [ -n "$USER_ID" ]; then
        USER_MSG="<blockquote>Welcome, <b>$TG_NAME</b>! 🚀</blockquote>
👤 <b>User:</b> <code>$USER</code>
💰 <b>Credit:</b> <code>$REMAINING_CREDIT $</code>
📉 <b>Used Traffic:</b> <code>$USED_GB GB</code>
🚀 <b>Remaining Traffic:</b> <code>$REMAINING_GB GB</code>

<blockquote><b>Proxy Info:</b>
<code>$USER:$PASS@$FINAL_IP:$RAILWAY_TCP_PROXY_PORT</code></blockquote>"

        # الزر الملون (Inline Query) - يظهر باللون اللبني/الأزرق المميز
        KEYBOARD='{"inline_keyboard":[[{"text":"🌀 Change User:Pass","switch_inline_query_current_chat":"NewUser:NewPass"}]]}'

        if [ "$is_update" = "false" ]; then
            RESP=$(curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendPhoto" \
                -d "chat_id=$USER_ID" -d "photo=$PHOTO_URL" -d "caption=$USER_MSG" \
                -d "parse_mode=HTML" -d "reply_markup=$KEYBOARD")
            echo "$RESP" | jq -r '.result.message_id' > $USER_TEMP_MSG 2>/dev/null
        else
            MSG_ID=$(cat $USER_TEMP_MSG 2>/dev/null)
            [ -n "$MSG_ID" ] && curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/editMessageCaption" \
                -d "chat_id=$USER_ID" -d "message_id=$MSG_ID" \
                -d "caption=$USER_MSG" -d "parse_mode=HTML" -d "reply_markup=$KEYBOARD" > /dev/null
        fi
    fi

    # رسالة الأدمن (التنسيق الكامل المطلوب)
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
            echo "$RESP" | jq -r '.result.message_id' > $TEMP_MSG_FILE 2>/dev/null
        fi
    fi
}

# --- 5. Main Execution Logic ---
update_system() {
    local is_update=$1
    echo "📥 Processing Proxy Pool & Updating HAProxy..."
    
    # Fetch from DB
    PROXIES=$(psql "$DATABASE_URL" -t -c "SELECT proxy_data FROM proxy_pool;" | xargs 2>/dev/null)
    sed -i '/    server /d' $CONFIG_FILE
    COUNT=0
    for VAL in $PROXIES; do
        IP_PORT=$(echo $VAL | cut -d'@' -f2)
        [ -n "$IP_PORT" ] && ((COUNT++)) && echo "    server srv_$COUNT $IP_PORT check maxconn 1" >> $CONFIG_FILE
    done

    # Networking
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

# Initial Run
update_system "false"
LAST_KNOWN_COUNT=$COUNT

# --- 6. Monitoring Loop ---
while true; do
    sleep 60
    # جلب العدد من الداتا بيز مع التحقق من أنه رقم
    CURRENT_DB_COUNT=$(psql "$DATABASE_URL" -t -c "SELECT COUNT(*) FROM proxy_pool;" | xargs 2>/dev/null)
    
    if [[ "$CURRENT_DB_COUNT" =~ ^[0-9]+$ ]]; then
        if [ "$CURRENT_DB_COUNT" -ne "$LAST_KNOWN_COUNT" ]; then
            echo "🔔 Update Detected! (New: $CURRENT_DB_COUNT)"
            update_system "true"
            LAST_KNOWN_COUNT=$CURRENT_DB_COUNT
        fi
    fi
    
    echo "--- Heartbeat ---"
    echo "User: $USER | IP: $FINAL_IP | DB Count: $CURRENT_DB_COUNT | Credit: $REMAINING_CREDIT$"
done
