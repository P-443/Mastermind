#!/bin/bash

CONFIG_FILE="/usr/local/etc/haproxy/haproxy.cfg"
USER="Arsen1k"
PASS="Speed123"

echo "🚀 Launching Arsen1k Hard-Rotation Engine..."

# 1. تنظيف وإضافة البروكسيات
sed -i '/    server /d' $CONFIG_FILE
for var in $(env | grep '^PROXY_' | cut -d= -f1); do
    VAL=${!var}
    IP_PORT=$(echo $VAL | cut -d'@' -f2)
    if [ -n "$IP_PORT" ]; then
        echo "    server $var $IP_PORT check maxconn 1" >> $CONFIG_FILE
    fi
done

# 2. تشغيل HAProxy
haproxy -f $CONFIG_FILE &

# 3. إرسال تليجرام بتنسيق Blockquote
sleep 10
FINAL_IP=$(getent hosts $RAILWAY_TCP_PROXY_DOMAIN | awk '{ print $1 }' | head -n 1)
[ -z "$FINAL_IP" ] && FINAL_IP="0.0.0.0"
COUNTRY=$(curl -s https://ipinfo.io/country)
[ -z "$COUNTRY" ] && COUNTRY="US"

MSG="<blockquote>🚀 <b>High-Speed Proxy Online</b></blockquote>

🌍 <b>Country:</b> $COUNTRY
🌐 <b>IP:</b> <code>$FINAL_IP</code>
🔌 <b>Port:</b> <code>$RAILWAY_TCP_PROXY_PORT</code>
👤 <b>User:</b> <code>$USER</code>
🔑 <b>Pass:</b> <code>$PASS</code>

<blockquote><b>========== HTTP Custom ==========</b></blockquote>
<code>$USER:$PASS@$FINAL_IP:$RAILWAY_TCP_PROXY_PORT</code>"

if [ -n "$TELEGRAM_TOKEN" ] && [ -n "$OWNER_ID" ]; then
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage" \
        -d "chat_id=$OWNER_ID" \
        -d "text=$MSG" \
        -d "parse_mode=HTML" > /dev/null
fi

wait
