FROM haproxy:2.8-alpine

USER root
# تثبيت الأدوات اللازمة للـ Shell
RUN apk add --no-cache bash grep curl bind-tools

COPY haproxy.cfg /usr/local/etc/haproxy/haproxy.cfg
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

EXPOSE 8080
ENTRYPOINT ["/entrypoint.sh"]
