ARG NODE_VERSION=20.11.0
FROM node:${NODE_VERSION}-alpine

ARG UID=1000
ARG GID=1000

# The node:alpine image already ships a "node" user, but at a fixed uid/gid
# that won't generally match the host developer -- re-key it the same way
# the php-fpm image re-keys www-data, so Grunt's output files (compiled CSS,
# etc.) land on the bind-mounted ./src with the developer's own ownership.
RUN deluser node \
    && addgroup -g "${GID}" node \
    && adduser -D -u "${UID}" -G node -s /bin/sh node

RUN npm install -g grunt-cli

COPY --chown=node:node entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /var/www/html

USER node

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
