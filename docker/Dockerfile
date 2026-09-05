# Stagemgr application image — Passenger + Nginx + Ruby 3.2.2 (via RVM).
#
# Built for development and CI: the checkout is bind-mounted at
# /var/www/stagemgr by docker-compose, so edit-save-refresh works without a
# rebuild and no application code or configuration is copied into the image.
# It also runs with RAILS_ENV=production (the entrypoint precompiles assets and
# gates on `rake setup:doctor` there) — see
# docs/manual/developer/deployment.md before relying on that.
#
# Rebuild when this file, the nginx configs, the runit services or the
# entrypoint change — all four are baked in, not bind-mounted.

FROM phusion/passenger-full:2.6.2

# bin/docker-entrypoint installs the right site config at boot (standalone vs
# foundation mode), so the image ships neither.
RUN rm -f /etc/nginx/sites-enabled/default

# Activate Nginx as a my_init-managed service.
RUN rm -f /etc/service/nginx/down

# Passenger refuses to run as a user with a password set.
RUN passwd -d app

# Build deps for native gems (mysql2, ruby-vips, nokogiri) plus the shared
# libraries Firefox needs for @javascript Cucumber scenarios.
RUN rm -f /etc/apt/sources.list.d/passenger.list && \
    apt-get update && apt-get install -y \
      build-essential curl gnupg2 git \
      mysql-client libmysqlclient-dev \
      libreadline-dev zlib1g-dev libssl-dev libcrypto++-dev automake \
      libvips libvips-dev \
      bzip2 libdbus-glib-1-2 libgtk-3-0 libx11-xcb1 libasound2 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Real Firefox from Mozilla's APT repo (non-snap .deb, amd64 + arm64) so
# Selenium never tries to download a browser at test time — that fails whenever
# Mozilla's FTP lags behind a freshly released patch version.
#
# The base image ships a snap-transitional firefox package (1:1snap1-0ubuntu2)
# that needs snapd (absent in Docker); remove it first so the Mozilla build
# installs without an epoch conflict.
RUN apt-get remove -y --purge firefox || true
RUN install -d -m 0755 /etc/apt/keyrings && \
    curl -fsSL https://packages.mozilla.org/apt/repo-signing-key.gpg \
        -o /etc/apt/keyrings/packages.mozilla.org.asc && \
    echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" \
        > /etc/apt/sources.list.d/mozilla.list && \
    printf 'Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 1000\n' \
        > /etc/apt/preferences.d/mozilla && \
    apt-get update && apt-get install -y firefox && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN ARCH=$(uname -m) && \
    case "$ARCH" in \
      x86_64)  GD_ARCH="linux64" ;; \
      aarch64) GD_ARCH="linux-aarch64" ;; \
      *) echo "Unsupported arch: $ARCH" && exit 1 ;; \
    esac && \
    curl -fsSL "https://github.com/mozilla/geckodriver/releases/download/v0.35.0/geckodriver-v0.35.0-${GD_ARCH}.tar.gz" \
        -o /tmp/geckodriver.tar.gz && \
    tar -xzf /tmp/geckodriver.tar.gz -C /usr/local/bin && \
    rm /tmp/geckodriver.tar.gz

# Node 22 + Yarn for Webpacker asset compilation. Matches .nvmrc and the
# actions/setup-node version in .github/workflows/test.yml.
RUN curl -sL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g yarn \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Pin Ruby 3.2.2 in a named gemset so the Passenger site configs can point at a
# stable wrapper path.
RUN bash -lc "rvm gemset create stagemgr && \
              rvm gemset use stagemgr && \
              rvm --default use 3.2.2 && \
              rvm cleanup all"

# The nginx configs hard-code this wrapper; fail the build here rather than
# serving 502s at run time if a Ruby or gemset rename ever moves it.
RUN test -x /usr/local/rvm/wrappers/ruby-3.2.2@stagemgr/ruby

# Make RVM available in every shell (entrypoint, `docker compose exec`).
RUN echo 'source /etc/profile.d/rvm.sh' >> /etc/skel/.bashrc && \
    echo 'source /etc/profile.d/rvm.sh' >> /root/.bashrc && \
    echo 'source /etc/profile.d/rvm.sh' >> /home/app/.bashrc

RUN gem install bundler

ENV BUNDLE_BUILD__MYSQL2="--with-mysql-config=/usr/bin/mysql_config"

# Gems live in the RVM gemset, which docker-compose backs with the bundle-cache
# volume. Deliberately NOT a custom BUNDLE_PATH: `rvm use` unsets BUNDLE_PATH
# when it switches gemsets, so every consumer (the entrypoint, the runit
# services, and Passenger's own bundler activation) would have to re-export it,
# and any one that forgot would crash-loop on Bundler::GitError. The gemset is
# already outside the bind-mounted checkout, which is the point of the exercise.
RUN chown -R app:app /usr/local/rvm/gems/ruby-3.2.2@stagemgr && usermod -a -G rvm app

# Bind-mount target.
WORKDIR /var/www
RUN chown -R app:app /var/www
RUN usermod -a -G rvm www-data

# Candidate site configs; the entrypoint picks one and writes it into
# /etc/nginx/sites-enabled after substituting the app env.
COPY docker/nginx.conf docker/nginx.foundation.conf /etc/nginx/stagemgr/

# Supervised background workers. runit starts everything under /etc/service once
# my_init takes over as PID 1, which is after the entrypoint has finished
# installing gems — so the workers never race the bundle.
COPY docker/service/ /etc/service/
RUN chmod +x /etc/service/resque-worker/run /etc/service/resque-scheduler/run

WORKDIR /var/www/stagemgr

EXPOSE 80

COPY bin/docker-entrypoint /usr/bin/docker-entrypoint
RUN chmod +x /usr/bin/docker-entrypoint
ENTRYPOINT ["/usr/bin/docker-entrypoint"]

# my_init is Passenger's PID-1 supervisor; it brings up Nginx and /etc/service/*.
CMD ["/sbin/my_init"]
