FROM nextcloud:32.0.5-apache@sha256:78ae30695b550aee857d8714d395fcb0e8005fc2bfde8cd88ec7dee102660e69

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        smbclient libsmbclient-dev supervisor && \
    pecl install smbclient; \
    docker-php-ext-enable smbclient; \
    rm -rf /var/lib/apt/lists/*

RUN mkdir /var/log/supervisord /var/run/supervisord

# Add cron job to scan files every five minutes
# The file www-data is already part of the image and registered with busybox crontab
RUN echo '*/5 * * * * php -f /var/www/html/occ files:scan --path="matthiasemde/files/NAS (Files)"' >> /var/spool/cron/crontabs/www-data
RUN echo '*/5 * * * * php -f /var/www/html/occ files:scan --path="matthiasemde/files/NAS (Navidrome)"' >> /var/spool/cron/crontabs/www-data
RUN echo '*/5 * * * * php -f /var/www/html/occ files:scan --path="matthiasemde/files/NAS (Home)"' >> /var/spool/cron/crontabs/www-data
RUN echo '*/5 * * * * php -f /var/www/html/occ files:scan --path="theresaemde/files/NAS (Home)"' >> /var/spool/cron/crontabs/www-data

COPY supervisord.conf /

# Is this necessary? If the next update runs without, remove.
# ENV NEXTCLOUD_UPDATE=1

CMD ["/usr/bin/supervisord", "-c", "/supervisord.conf"]
