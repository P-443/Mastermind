#!/bin/bash

CONFIG_FILE="/usr/local/etc/haproxy/haproxy.cfg"
USER="Arsen1k"
PASS="Speed123"

echo "🚀 Launching Arsen1k Hard-Rotation Engine (DB Mode)..."

# 1. التأكد من وجود رابط قاعدة البيانات
if [ -z "$DATABASE_URL" ]; then
    echo "❌ ERROR: DATABASE_URL is not set!"
    exit 1
fi

# 2. تنظيف ملف الإعدادات القديم من السيرفرات
sed -i '/    server /d' $CONFIG_FILE

# 3. جلب البروكسيات من قاعدة البيانات وتنسيقها
# الاستعلام يجلب فقط الجزء بعد الـ @ (الآي بي والبورت)
echo "📥 Fetching proxies from Database..."
PROXIES=$(psql "$DATABASE_URL" -t -c "SELECT proxy_data FROM proxy_pool;")

COUNT=1
for VAL in $PROXIES; do
    # استخراج الـ IP:PORT فقط (حذف اليوزر والباسورد من السلسلة)
    IP_PORT=$(echo $VAL | cut -d'@' -f2)
    
    if [ -n "$IP_PORT" ]; then
        echo "    server srv_$COUNT $IP_PORT check maxconn 1" >> $CONFIG_FILE
        echo "✅ Added: srv_$COUNT -> $IP_PORT"
        ((COUNT++))
    fi
done

# 4. تشغيل HAProxy
haproxy -f $CONFIG_FILE &

# 5. إرسال تليجرام للإخطار (اختياري كما في كودك الأصلي)
sleep 10
FINAL_IP=$(getent hosts $RAILWAY_TCP_PROXY_DOMAIN | awk '{ print $1 }' | head -n 1)
[ -z "$FINAL_IP" ] && FINAL_IP="0.0.0.0"
COUNTRY=$(curl -s https://ipinfo.io/country)

MSG="<blockquote>🚀 <b>Load Balancer Active</b></blockquote>
🌍 <b>Country:</b> ${COUNTRY:-US}
🌐 <b>Public IP:</b> <code>$FINAL_IP</code>
🔢 <b>Active Proxies:</b> $((COUNT-1))
🔗 <b>Connection:</b> <code>$USER:$PASS@$FINAL_IP:$RAILWAY_TCP_PROXY_PORT</code>"

if [ -n "$TELEGRAM_TOKEN" ] && [ -n "$OWNER_ID" ]; then
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage" \
        -d "chat_id=$OWNER_ID" \
        -d "text=$MSG" \
        -d "parse_mode=HTML" > /dev/null
fi

wait
