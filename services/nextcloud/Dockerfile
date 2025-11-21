FROM nextcloud:32.0.2-apache@sha256:ac08482d73ffd85d94069ba291bbd5fb39a70ff21502030a2e3e2d89a7246a48

# Fix a bug in the dockerfile where a deprecated functioni is called. Can be removed if the bug is fixed
RUN sed -i 's/maintenance:install/app:install/g' /entrypoint.sh

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        smbclient libsmbclient-dev supervisor && \
    pecl install smbclient; \
    docker-php-ext-enable smbclient; \
    rm -rf /var/lib/apt/lists/*

RUN mkdir /var/log/supervisord /var/run/supervisord

# Add cron job to scan files every five minutes
# The file www-data is already part of the image and registered with busybox crontab
RUN echo '*/5 * * * * php -f /var/www/html/occ files:scan --path="admin/files/NAS (Files)"' >> /var/spool/cron/crontabs/www-data
RUN echo '*/5 * * * * php -f /var/www/html/occ files:scan --path="matthiasemde/files/NAS (Home)"' >> /var/spool/cron/crontabs/www-data
RUN echo '*/5 * * * * php -f /var/www/html/occ files:scan --path="theresaemde/files/NAS (Home)"' >> /var/spool/cron/crontabs/www-data

COPY supervisord.conf /

# Is this necessary? If the next update runs without, remove.
# ENV NEXTCLOUD_UPDATE=1

CMD ["/usr/bin/supervisord", "-c", "/supervisord.conf"]
