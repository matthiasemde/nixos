FROM nextcloud:31.0.8-apache

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        smbclient libsmbclient-dev supervisor && \
    pecl install smbclient; \
    docker-php-ext-enable smbclient; \
    rm -rf /var/lib/apt/lists/*

RUN mkdir /var/log/supervisord /var/run/supervisord

# Add cron job to scan files every five minutes
# The file www-data is already part of the image and registered with busybox crontab
RUN echo '*/5 * * * * php -f /var/www/html/occ files:scan --path="admin/files/NAS"' >> /var/spool/cron/crontabs/www-data

COPY supervisord.conf /

CMD ["/usr/bin/supervisord", "-c", "/supervisord.conf"]
