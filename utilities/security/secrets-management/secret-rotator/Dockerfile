FROM alpine:3.24

RUN apk add --no-cache \
    bash \
    curl \
    jq \
    docker-cli \
    openssl

COPY rotate-secrets.py /usr/local/bin/
COPY rotation-schedule.json /etc/rotation/

RUN chmod +x /usr/local/bin/rotate-secrets.py

CMD ["/usr/local/bin/rotate-secrets.py"]
