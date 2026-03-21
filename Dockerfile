FROM haproxy:2.8-alpine

USER root
# إضافة postgresql-client لقراءة البيانات من القاعدة
RUN apk add --no-cache bash grep curl bind-tools postgresql-client

COPY haproxy.cfg /usr/local/etc/haproxy/haproxy.cfg
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

EXPOSE 8080
ENTRYPOINT ["/entrypoint.sh"]
