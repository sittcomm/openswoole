ARG OPENSWOOLE_TAG="4.7.2-php8.0-alpine"
ARG COMPOSER_TAG="latest"

FROM openswoole/swoole:${OPENSWOOLE_TAG} as php-base
RUN apk --no-cache --update add \
    libxml2-dev \
    sqlite-dev \
    curl-dev \
    libpng-dev \
    openssl \
    ca-certificates \
    libjpeg-turbo-dev \
    freetype-dev && \
    rm -rf /tmp/* && \
    rm -rf /var/cache/apk/*


FROM php-base as ext-builder
RUN docker-php-source extract && \
    apk add --no-cache --virtual .phpize-deps $PHPIZE_DEPS

FROM ext-builder as ext-bcmath
RUN docker-php-ext-install bcmath

FROM ext-builder as ext-redis
RUN pecl install redis
RUN docker-php-ext-enable redis

FROM ext-builder as ext-inotify
RUN pecl install inotify && \
    docker-php-ext-enable inotify

FROM ext-builder as ext-mysqli
RUN docker-php-ext-install mysqli

FROM ext-builder as ext-pdo
RUN docker-php-ext-install pdo pdo_mysql \
    && docker-php-ext-enable pdo_mysql

FROM ext-builder as ext-opcache
RUN docker-php-ext-install opcache

FROM php-base as app-base

COPY ./docker/conf.d/symfony-prod.ini $PHP_INI_DIR/conf.d/

WORKDIR /app

RUN set -exu; \
  ln -sf $PHP_INI_DIR/php.ini-production $PHP_INI_DIR/php.ini; \
  ln -sf $PHP_INI_DIR/conf.d/symfony-prod.ini $PHP_INI_DIR/conf.d/symfony.ini; \

RUN apk add --update libzip-dev curl-dev &&\
    docker-php-ext-install curl && \
    apk del gcc g++ &&\
    rm -rf /var/cache/apk/* \

ARG PHP_API_VERSION="20200930"
COPY --from=ext-inotify /usr/local/lib/php/extensions/no-debug-non-zts-${PHP_API_VERSION}/inotify.so /usr/local/lib/php/extensions/no-debug-non-zts-${PHP_API_VERSION}/inotify.so
COPY --from=ext-inotify /usr/local/etc/php/conf.d/docker-php-ext-inotify.ini /usr/local/etc/php/conf.d/docker-php-ext-inotify.ini
COPY --from=ext-redis /usr/local/lib/php/extensions/no-debug-non-zts-${PHP_API_VERSION}/redis.so /usr/local/lib/php/extensions/no-debug-non-zts-${PHP_API_VERSION}/redis.so
COPY --from=ext-redis /usr/local/etc/php/conf.d/docker-php-ext-redis.ini /usr/local/etc/php/conf.d/docker-php-ext-redis.ini
COPY --from=ext-bcmath /usr/local/lib/php/extensions/no-debug-non-zts-${PHP_API_VERSION}/bcmath.so /usr/local/lib/php/extensions/no-debug-non-zts-${PHP_API_VERSION}/bcmath.so
COPY --from=ext-bcmath /usr/local/etc/php/conf.d/docker-php-ext-bcmath.ini /usr/local/etc/php/conf.d/docker-php-ext-bcmath.ini
COPY --from=ext-mysqli /usr/local/lib/php/extensions/no-debug-non-zts-${PHP_API_VERSION}/mysqli.so /usr/local/lib/php/extensions/no-debug-non-zts-${PHP_API_VERSION}/mysqli.so
COPY --from=ext-mysqli /usr/local/etc/php/conf.d/docker-php-ext-mysqli.ini /usr/local/etc/php/conf.d/docker-php-ext-mysqli.ini
COPY --from=ext-pdo /usr/local/lib/php/extensions/no-debug-non-zts-${PHP_API_VERSION}/pdo.so /usr/local/lib/php/extensions/no-debug-non-zts-${PHP_API_VERSION}/pdo.so
COPY --from=ext-pdo /usr/local/lib/php/extensions/no-debug-non-zts-${PHP_API_VERSION}/pdo_mysql.so /usr/local/lib/php/extensions/no-debug-non-zts-${PHP_API_VERSION}/pdo_mysql.so
COPY --from=ext-pdo /usr/local/etc/php/conf.d/docker-php-ext-pdo_mysql.ini /usr/local/etc/php/conf.d/docker-php-ext-pdo_mysql.ini
COPY --from=ext-opcache /usr/local/lib/php/extensions/no-debug-non-zts-${PHP_API_VERSION}/opcache.so /usr/local/lib/php/extensions/no-debug-non-zts-${PHP_API_VERSION}/opcache.so
COPY --from=ext-opcache /usr/local/etc/php/conf.d/docker-php-ext-opcache.ini /usr/local/etc/php/conf.d/docker-php-ext-opcache.ini

COPY ./docker/docker-entrypoint.sh /usr/local/bin/docker-entrypoint
COPY ./docker/docker-healthcheck.sh /usr/local/bin/docker-healthcheck
RUN chmod +x /usr/local/bin/docker-entrypoint /usr/local/bin/docker-healthcheck

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer
# https://getcomposer.org/doc/03-cli.md#composer-allow-superuser
ENV COMPOSER_ALLOW_SUPERUSER=1
ENV PATH="${PATH}:/root/.composer/vendor/bin"

ENTRYPOINT ["docker-entrypoint"]


FROM app-base as app-base-dev

COPY ./docker/conf.d/symfony-dev.ini $PHP_INI_DIR/conf.d/

RUN set -exu; \
  ln -sf $PHP_INI_DIR/php.ini-development $PHP_INI_DIR/php.ini; \
  ln -sf $PHP_INI_DIR/conf.d/symfony-dev.ini $PHP_INI_DIR/conf.d/symfony.ini;

ARG PHP_API_VERSION="20200930"
COPY --from=ext-inotify /usr/local/lib/php/extensions/no-debug-non-zts-${PHP_API_VERSION}/inotify.so /usr/local/lib/php/extensions/no-debug-non-zts-${PHP_API_VERSION}/inotify.so
COPY --from=ext-inotify /usr/local/etc/php/conf.d/docker-php-ext-inotify.ini /usr/local/etc/php/conf.d/docker-php-ext-inotify.ini