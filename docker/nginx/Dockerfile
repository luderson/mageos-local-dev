# nginxinc/nginx-unprivileged runs the master process itself as a non-root
# user (uid 101) and listens on high ports by default -- unlike the stock
# nginx image, whose master process needs root to bind :80. We only need an
# unprivileged port here anyway since Traefik is the one binding 80/443 and
# proxies to this container over the internal Docker network.
FROM nginxinc/nginx-unprivileged:1.27-alpine

COPY conf.d/magento.conf /etc/nginx/conf.d/default.conf

EXPOSE 8080
