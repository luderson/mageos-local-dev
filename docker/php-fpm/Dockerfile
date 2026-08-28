ARG PHP_VERSION=8.3

FROM php:${PHP_VERSION}-fpm-alpine

# Host UID/GID to map onto the container's www-data user, so files written
# through the bind-mounted ./src volume are owned by the developer, not root
# or an arbitrary container UID. Passed from .env by setup.sh.
ARG UID=1000
ARG GID=1000

# Composer binary, copied straight from the official Composer image rather
# than installed via curl|sh -- pins the exact version and avoids a network
# fetch of an installer script at build time.
COPY --from=composer:2.7.7 /usr/bin/composer /usr/bin/composer

# Build-time-only packages (compilers, headers) are installed into a virtual
# apk package and removed again after the PHP extensions are compiled, so
# they never ship in the final image layer.
RUN apk add --no-cache \
      icu-libs \
      libzip \
      libpng \
      libjpeg-turbo \
      freetype \
      libxslt \
      libxml2 \
      openldap \
      rabbitmq-c \
      git \
      unzip \
    && apk add --no-cache --virtual .build-deps \
      $PHPIZE_DEPS \
      linux-headers \
      icu-dev \
      libzip-dev \
      libpng-dev \
      libjpeg-turbo-dev \
      freetype-dev \
      libxslt-dev \
      libxml2-dev \
      openldap-dev \
      rabbitmq-c-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j"$(nproc)" \
      bcmath \
      gd \
      intl \
      pdo_mysql \
      mysqli \
      soap \
      sockets \
      xsl \
      zip \
      opcache \
      pcntl \
    && pecl install redis amqp \
    && docker-php-ext-enable redis amqp \
    && apk del .build-deps

# Re-key the image's built-in www-data user/group to match the host, so the
# non-root user this container runs as (see USER below) can read and write
# the bind-mounted application code with the developer's own permissions.
RUN deluser www-data \
    && addgroup -g "${GID}" www-data \
    && adduser -D -u "${UID}" -G www-data -s /bin/sh www-data

COPY conf.d/zz-magento.ini /usr/local/etc/php/conf.d/zz-magento.ini

WORKDIR /var/www/html

USER www-data

EXPOSE 9000

CMD ["php-fpm"]
