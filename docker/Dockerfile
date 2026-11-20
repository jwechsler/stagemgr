# Stagemgr application image — Passenger + Nginx + Ruby 3.3 (via RVM).
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

# passenger-full ships several RVM Rubies (3.3, 3.4, 4.0 in this tag; the RVM
# default is the newest). 3.1.11 is the last tag on Ubuntu 24.04 (Noble); the
# 3.2.x line moves to 26.04. When bumping the tag, set RUBY_VERSION below to the
# 3.3.x it ships: `docker run --rm --entrypoint ls <image> /usr/local/rvm/rubies`.
FROM phusion/passenger-full:3.1.11

# The one place the image's Ruby is named. Everything else -- GEM_HOME and PATH
# below, the entrypoint, the runit services and the nginx site configs -- reads
# STAGEMGR_RUBY. docker-compose.yml's bundle-cache mount path and
# docs/manual/developer/installation.md name it literally; keep them in step.
ARG RUBY_VERSION=3.3.12
ENV STAGEMGR_RUBY=ruby-${RUBY_VERSION}@stagemgr

# bin/docker-entrypoint installs the right site config at boot (standalone vs
# foundation mode), so the image ships neither.
RUN rm -f /etc/nginx/sites-enabled/default

# Activate Nginx as a my_init-managed service.
RUN rm -f /etc/service/nginx/down

# Passenger refuses to run as a user with a password set.
RUN passwd -d app

# Build deps for native gems (mysql2, ruby-vips, nokogiri) plus the shared
# libraries Firefox needs for @javascript Cucumber scenarios.
#
# Earlier (Jammy) base images enabled deb-src for every pocket, so each
# `apt-get update` dragged down ~25 MB of source-package indexes we never use.
# Noble's base keeps its sources in deb822 form (sources.list.d/ubuntu.sources)
# with `Types: deb` only, so the sed is a no-op today; it stays as a guard.
#
# libasound2 is libasound2t64 on Noble (the 64-bit time_t transition).
#
# --no-install-recommends throughout: every library these packages actually need
# is named explicitly, here or in the Firefox block below.
RUN rm -f /etc/apt/sources.list.d/passenger.list && \
    sed -i '/^deb-src/d' /etc/apt/sources.list && \
    apt-get update && apt-get install -y --no-install-recommends \
      build-essential curl gnupg2 git \
      mysql-client libmysqlclient-dev \
      libreadline-dev zlib1g-dev libssl-dev libcrypto++-dev automake \
      libvips libvips-dev fonts-urw-base35 \
      bzip2 libdbus-glib-1-2 libgtk-3-0 libx11-xcb1 libasound2t64 \
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
    apt-get update && apt-get install -y --no-install-recommends firefox && \
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

# Node 22 + Yarn for the esbuild JavaScript build (`yarn build`). Matches .nvmrc and the
# actions/setup-node version in .github/workflows/test.yml. The base image ships
# NodeSource's Node 24, and apt will not downgrade an installed package, so
# purge it before switching the NodeSource repo to 22.x. The purge leaves the
# base image's corepack yarn/yarnpkg symlinks dangling; they would block
# `npm install -g yarn`.
RUN apt-get purge -y nodejs \
    && rm -f /usr/bin/yarn /usr/bin/yarnpkg \
    && curl -sL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && npm install -g yarn \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Pin the base image's Ruby 3.3 in a named gemset so the Passenger site configs
# can point at a stable wrapper path. The gemset -- not the bare ruby -- is the
# RVM default (replacing the base image's newest Ruby), so a login shell lands
# in it without an explicit `rvm use`.
# The patch level is whatever the base image ships and is deliberately not tied
# to .ruby-version (see docs/manual/developer/installation.md).
RUN bash -lc "rvm use ruby-${RUBY_VERSION} && \
              rvm gemset create stagemgr && \
              rvm --default use ${STAGEMGR_RUBY} && \
              rvm cleanup all"

# The entrypoint writes this wrapper into the nginx site config; fail the build
# here rather than serving 502s at run time if a Ruby or gemset rename moves it.
RUN test -x /usr/local/rvm/wrappers/${STAGEMGR_RUBY}/ruby

# Make RVM available in every shell (entrypoint, `docker compose exec`).
RUN echo 'source /etc/profile.d/rvm.sh' >> /etc/skel/.bashrc && \
    echo 'source /etc/profile.d/rvm.sh' >> /root/.bashrc && \
    echo 'source /etc/profile.d/rvm.sh' >> /home/app/.bashrc

# ...and in every NON-login shell too, which is the shape `docker compose exec`
# and `docker compose run` use: they exec the command directly, so nothing
# sources /etc/profile.d/rvm.sh and `bundle` would otherwise resolve to the
# base image's /usr/bin/bundle with none of the app's gems on its path. These
# are the exact values `rvm use $STAGEMGR_RUBY` exports (verified with
# `gem env` inside the image), pinned here so that
# `docker compose exec -u app stagemgr bundle exec rake ...` just works.
ENV GEM_HOME=/usr/local/rvm/gems/ruby-${RUBY_VERSION}@stagemgr
ENV GEM_PATH=/usr/local/rvm/gems/ruby-${RUBY_VERSION}@stagemgr:/usr/local/rvm/gems/ruby-${RUBY_VERSION}@global
ENV PATH=/usr/local/rvm/gems/ruby-${RUBY_VERSION}@stagemgr/bin:/usr/local/rvm/gems/ruby-${RUBY_VERSION}@global/bin:/usr/local/rvm/rubies/ruby-${RUBY_VERSION}/bin:/usr/local/rvm/bin:$PATH

# Pinned to the version in Gemfile.lock's BUNDLED WITH. Unpinned, this now
# installs a Bundler 4.x into the gemset (whose bin directory the ENV above puts
# first on PATH), which would shadow the 2.5.x that generated the lockfile.
RUN gem install bundler -v 2.5.22

ENV BUNDLE_BUILD__MYSQL2="--with-mysql-config=/usr/bin/mysql_config"

# The checkout is bind-mounted, and a developer's own .bundle/config in it
# (typically `BUNDLE_PATH: vendor/bundle` for native runs) would otherwise be
# honoured inside the container: Linux gems land in the host's vendor/bundle
# and clobber macOS native extensions built in place (scrypt, sassc). Reading
# app config from a container-local directory makes the host's file invisible.
ENV BUNDLE_APP_CONFIG=/home/app/.bundle
RUN mkdir -p /home/app/.bundle && chown app:app /home/app/.bundle

# Gems live in the RVM gemset, which docker-compose backs with the bundle-cache
# volume. Deliberately NOT a custom BUNDLE_PATH: `rvm use` unsets BUNDLE_PATH
# when it switches gemsets, so every consumer (the entrypoint, the runit
# services, and Passenger's own bundler activation) would have to re-export it,
# and any one that forgot would crash-loop on Bundler::GitError. The gemset is
# already outside the bind-mounted checkout, which is the point of the exercise.
RUN chown -R app:app "$GEM_HOME" && usermod -a -G rvm app

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
