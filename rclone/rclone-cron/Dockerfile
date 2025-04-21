FROM alpine:latest

RUN apk add --no-cache rclone tzdata bash jq curl

RUN curl -o /usr/local/bin/send_logs_to_discord.sh https://raw.githubusercontent.com/tryweb/docker-compose/refs/heads/main/scripts/send_logs_to_discord.sh && \
    chmod a+x /usr/local/bin/send_logs_to_discord.sh

CMD ["sh", "-c", "mkdir -p /etc/crontabs && chmod 0600 /etc/crontabs/root && mkdir -p /var/log/cron && crond -f -d 8"]