ARG NODE_VERSION=20.11.0
FROM node:${NODE_VERSION}-alpine

ARG UID=1000
ARG GID=1000

# The node:alpine image already ships a "node" user, but at a fixed uid/gid
# that won't generally match the host developer -- re-key it the same way
# the php-fpm image re-keys www-data, so Grunt's output files (compiled CSS,
# etc.) land on the bind-mounted ./src with the developer's own ownership.
# GID/UID may already belong to another entry in the base image (e.g. on
# macOS the default primary group "staff" is GID 20, which collides with
# Alpine's built-in "dialout" group) -- reuse/rename that existing entry
# instead of failing, since the numeric ID is what matters for permissions.
RUN set -eux; \
    deluser node 2>/dev/null || true; \
    delgroup node 2>/dev/null || true; \
    if getent group "${GID}" > /dev/null 2>&1; then \
      existing_group="$(getent group "${GID}" | cut -d: -f1)"; \
      sed -i "s/^${existing_group}:/node:/" /etc/group; \
    else \
      addgroup -g "${GID}" node; \
    fi; \
    if getent passwd "${UID}" > /dev/null 2>&1; then \
      existing_user="$(getent passwd "${UID}" | cut -d: -f1)"; \
      deluser "${existing_user}" 2>/dev/null || true; \
    fi; \
    adduser -D -u "${UID}" -G node -s /bin/sh node

RUN npm install -g grunt-cli

COPY --chown=node:node entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /var/www/html

USER node

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
