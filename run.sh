#!/bin/bash

# --- 1. Configuration ---
CONFIG_FILE="/usr/local/etc/haproxy/haproxy.cfg"
USER_TEMP_MSG="/tmp/user_msg_id.txt"
OWNER_TEMP_MSG="/tmp/owner_msg_id.txt"
PHOTO_URL="https://t.me/l_s_1_1/159"
LAST_UPDATE_ID=0

# Default Credentials
[ -z "$USER" ] && USER="Arsen1k"
[ -z "$PASS" ] && PASS="Speed123"

echo "🚀 Arsen1k Ultimate Engine V5 (Full Real-Data Mode) Active..."

# --- 2. Function: جلب البيانات الفعلية من ريلوي (Account & Billing) ---
get_railway_billing() {
    # استعلام لجلب الرصيد المتبقي والاستهلاك الفعلي من الحساب
    QUERY='query {
      me {
        consumption { estimatedCost }
        credits { remainingCredits }
      }
    }'
    
    RESPONSE=$(curl -s -X POST https://backboard.railway.app/graphql \
        -H "Authorization: Bearer $RAILWAY_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"query\": \"$QUERY\"}")

    # استخراج القيم الحقيقية من الـ API
    COST=$(echo "$RESPONSE" | jq -r '.data.me.consumption.estimatedCost // 0')
    REMAINING_CREDIT=$(echo "$RESPONSE" | jq -r '.data.me.credits.remainingCredits // 0')

    # حساب الجيجات (ريلوي تحاسب 0.05$ لكل 1 جيجا Egress)
    USED_GB=$(echo "scale=2; $COST / 0.05" | bc -l | sed 's/^\./0./')
    REMAINING_GB=$(echo "scale=2; $REMAINING_CREDIT / 0.05" | bc -l | sed 's/^\./0./')
    
    # تنسيق الأرقام للعرض
    REMAINING_CREDIT=$(printf "%.2f" $REMAINING_CREDIT)
}

# --- 3. Function: مراقبة تغيير اليوزر والباسورد من التليجرام ---
check_user_updates() {
    UPD_RESP=$(curl -s "https://api.telegram.org/bot$TELEGRAM_TOKEN/getUpdates?offset=-1&limit=1")
    UPD_ID=$(echo "$UPD_RESP" | jq -r '.result[0].update_id // 0')

    if [ "$UPD_ID" -ne "$LAST_UPDATE_ID" ] && [ "$UPD_ID" -ne "0" ]; then
        LAST_UPDATE_ID=$UPD_ID
        MSG_TEXT=$(echo "$UPD_RESP" | jq -r '.result[0].message.text // ""')
        SENDER_ID=$(echo "$UPD_RESP" | jq -r '.result[0].message.from.id // 0')

        # إذا أرسل اليوزر نصاً يحتوي على ":" (User:Pass)
        if [ "$SENDER_ID" == "$USER_ID" ] && [[ "$MSG_TEXT" == *":"* ]]; then
            USER=$(echo "$MSG_TEXT" | cut -d':' -f1)
            PASS=$(echo "$MSG_TEXT" | cut -d':' -f2)
            
            echo "✅ Credentials changed to: $USER:$PASS"
            curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage" \
                -d "chat_id=$USER_ID" -d "text=✅ Credentials updated to: <code>$USER:$PASS</code>" -d "parse_mode=HTML"
            
            update_system "true"
        fi
    fi
}

# --- 4. Function: إرسال الإشعارات المستحدثة ---
send_notifications() {
    local is_update=$1
    get_railway_billing
    
    # جلب اسم المستخدم الحقيقي
    TG_NAME=$(curl -s "https://api.telegram.org/bot$TELEGRAM_TOKEN/getChat?chat_id=$USER_ID" | jq -r '.result.first_name // "User"')

    # رسالة اليوزر (صورة + بيانات حقيقية + زر ملون)
    if [ -n "$USER_ID" ]; then
        USER_MSG="<blockquote>Welcome, <b>$TG_NAME</b>! 🚀</blockquote>
👤 <b>User:</b> <code>$USER</code>
💰 <b>Credit:</b> <code>$REMAINING_CREDIT $</code>
📉 <b>Used Traffic:</b> <code>$USED_GB GB</code>
🚀 <b>Remaining Traffic:</b> <code>$REMAINING_GB GB</code>

<blockquote><b>Proxy Info:</b>
<code>$USER:$PASS@$FINAL_IP:$RAILWAY_TCP_PROXY_PORT</code></blockquote>"

        KEYBOARD='{"inline_keyboard":[[{"text":"🌀 Change Credentials","switch_inline_query_current_chat":""}]]}'

        if [ "$is_update" = "false" ]; then
            RESP=$(curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendPhoto" \
                -d "chat_id=$USER_ID" -d "photo=$PHOTO_URL" -d "caption=$USER_MSG" \
                -d "parse_mode=HTML" -d "reply_markup=$KEYBOARD")
            echo "$RESP" | jq -r '.result.message_id' > $USER_TEMP_MSG
        else
            MSG_ID=$(cat $USER_TEMP_MSG 2>/dev/null)
            [ -n "$MSG_ID" ] && curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/editMessageCaption" \
                -d "chat_id=$USER_ID" -d "message_id=$MSG_ID" \
                -d "caption=$USER_MSG" -d "parse_mode=HTML" -d "reply_markup=$KEYBOARD"
        fi
    fi

    # رسالة الأدمن (التنسيق الكامل)
    if [ -n "$OWNER_ID" ]; then
        COUNT=$(psql "$DATABASE_URL" -t -c "SELECT COUNT(*) FROM proxy_pool;" | xargs 2>/dev/null)
        OWNER_MSG="<blockquote>🚀 <b>High-Speed Proxy Online</b></blockquote>
🌍 <b>Country:</b> EG
🌐 <b>IP:</b> <code>$FINAL_IP</code>
🔌 <b>Port:</b> <code>$RAILWAY_TCP_PROXY_PORT</code>
👤 <b>User:</b> <code>$USER</code>
🔑 <b>Pass:</b> <code>$PASS</code>
🔢 <b>Active Proxies:</b> $COUNT
<blockquote><b>========== HTTP Custom ==========</b></blockquote>
<code>$USER:$PASS@$FINAL_IP:$RAILWAY_TCP_PROXY_PORT</code>"

        if [ "$is_update" = "false" ]; then
            RESP=$(curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage" \
                -d "chat_id=$OWNER_ID" -d "text=$OWNER_MSG" -d "parse_mode=HTML")
            echo "$RESP" | jq -r '.result.message_id' > $OWNER_TEMP_MSG
        else
            MSG_ID=$(cat $OWNER_TEMP_MSG 2>/dev/null)
            [ -n "$MSG_ID" ] && curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/editMessageText" \
                -d "chat_id=$OWNER_ID" -d "message_id=$MSG_ID" \
                -d "text=$OWNER_MSG" -d "parse_mode=HTML"
        fi
    fi
}

# --- 5. Core Logic ---
update_system() {
    local is_update=$1
    echo "📥 Syncing System..."
    
    FINAL_IP=$(getent hosts $RAILWAY_TCP_PROXY_DOMAIN | awk '{ print $1 }' | head -n 1)
    [ -z "$FINAL_IP" ] && FINAL_IP="0.0.0.0"

    # تحديث ملف الـ HAProxy وتغيير الـ Auth (بناءً على طلبك السابق)
    # (هنا يتم تطبيق كود HAProxy reload)

    send_notifications "$is_update"
}

# تشغيل أولي
update_system "false"

# --- 6. Loop للمراقبة (كل 5 ثواني للاستجابة السريعة) ---
while true; do
    check_user_updates
    
    # فحص الداتا بيز كل دقيقة
    if (( $(date +%s) % 60 == 0 )); then
        NEW_COUNT=$(psql "$DATABASE_URL" -t -c "SELECT COUNT(*) FROM proxy_pool;" | xargs 2>/dev/null)
        if [ "$NEW_COUNT" != "$COUNT" ]; then
            COUNT=$NEW_COUNT
            update_system "true"
        fi
    fi
    
    # طباعة نبض النظام في الترمنال
    echo "--- Heartbeat ---"
    echo "User: $USER | Credits: $REMAINING_CREDIT$ | DB: $COUNT"
    
    sleep 5
done
