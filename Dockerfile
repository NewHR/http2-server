FROM nginx:stable-alpine

# Default values
ENV TIMEZONE=Europe/Moscow
ENV LETSENCRYPT=false
ENV LE_EMAIL=root@localhost
ENV LE_RT=1y

ADD script/*.sh /

RUN \
    chmod +x /entrypoint.sh && \
    apk add  --update certbot tzdata openssl && \
    rm -rf /var/cache/apk/*

EXPOSE 80
EXPOSE 443

CMD ["/entrypoint.sh"]

#EOF#
