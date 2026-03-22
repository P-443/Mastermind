FROM haproxy:2.8-alpine

USER root
# إضافة postgresql-client لقراءة البيانات من القاعدة
#RUN apk add --no-cache bash grep curl postgresql-client

RUN apk add --no-cache bash grep curl  bind-tools  jq postgresql-client

COPY haproxy.cfg /usr/local/etc/haproxy/haproxy.cfg
COPY run.sh /run.sh

RUN chmod +x /run.sh

EXPOSE 8080
ENTRYPOINT ["/run.sh"]
