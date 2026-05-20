# Stagemgr application image — Passenger + Nginx + Ruby 3.2.2 (via RVM).
#
# This is a development-friendly image: source is expected to be bind-mounted
# at /var/www/stagemgr by docker-compose so edit-save-refresh works without a
# rebuild. The same image runs in production with RAILS_ENV=production set.

FROM phusion/passenger-full:2.6.2

# Replace the default Nginx site with our Stagemgr config.
RUN rm /etc/nginx/sites-enabled/default
COPY docker/nginx.conf /etc/nginx/sites-enabled/stagemgr.conf

# Activate Nginx as a managed service.
RUN rm -f /etc/service/nginx/down

# Ensure the bundled app user has no password set (required by Passenger).
RUN passwd -d app

# Build deps for native gems (mysql2, ruby-vips, nokogiri) and dev tooling.
RUN rm -f /etc/apt/sources.list.d/passenger.list && \
    apt-get update && apt-get install -y \
      build-essential curl gnupg2 git \
      mysql-client libmysqlclient-dev \
      libreadline-dev zlib1g-dev libssl-dev libcrypto++-dev automake \
      libvips libvips-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Node 18 + Yarn for Webpacker asset compilation.
RUN curl -sL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g yarn \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Pin Ruby 3.2.2 in a named gemset so Passenger's nginx config can find it.
RUN bash -lc "rvm gemset create stagemgr && \
              rvm gemset use stagemgr && \
              rvm --default use 3.2.2 && \
              rvm cleanup all"

# Make RVM available in all interactive shells (entrypoint and `docker exec`).
RUN echo 'source /etc/profile.d/rvm.sh' >> /etc/skel/.bashrc && \
    echo 'source /etc/profile.d/rvm.sh' >> /root/.bashrc && \
    echo 'source /etc/profile.d/rvm.sh' >> /home/app/.bashrc

RUN gem install bundler

# Bind-mount target.
WORKDIR /var/www
RUN chown -R app:app /var/www
RUN usermod -a -G rvm www-data

USER app
ENV BUNDLE_BUILD__MYSQL2="--with-mysql-config=/usr/bin/mysql_config"
RUN su - app -c "mkdir -p /home/app/config"

USER root
WORKDIR /var/www/stagemgr

EXPOSE 80

COPY bin/docker-entrypoint /usr/bin/docker-entrypoint
RUN chmod +x /usr/bin/docker-entrypoint
ENTRYPOINT ["/usr/bin/docker-entrypoint"]

# my_init is Passenger's PID-1 supervisor; brings up Nginx + any /etc/service/*.
CMD ["/sbin/my_init"]
