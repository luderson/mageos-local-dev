#!/usr/bin/env bash
#
# Interactive setup for the MageOS Docker environment.
# Prompts for configuration, writes .env, provisions a local TLS cert with
# mkcert, optionally bootstraps a fresh MageOS install into ./src, then
# brings the stack up.
#
# Safe to re-run: it will offer to reuse an existing .env instead of
# overwriting it, and skips the app bootstrap step if ./src is non-empty.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------
c_reset='\033[0m'; c_bold='\033[1m'; c_green='\033[32m'; c_yellow='\033[33m'; c_red='\033[31m'
info()  { printf "%b\n" "${c_bold}==>${c_reset} $*"; }
ok()    { printf "%b\n" "${c_green}==>${c_reset} $*"; }
warn()  { printf "%b\n" "${c_yellow}==>${c_reset} $*"; }
die()   { printf "%b\n" "${c_red}==>${c_reset} $*" >&2; exit 1; }

# prompt NAME "Question text" "default"
prompt() {
    local __var="$1" __question="$2" __default="${3:-}" __answer
    if [ -n "$__default" ]; then
        read -r -p "$(printf "%b" "${c_bold}${__question}${c_reset} [${__default}]: ")" __answer
    else
        read -r -p "$(printf "%b" "${c_bold}${__question}${c_reset}: ")" __answer
    fi
    printf -v "$__var" '%s' "${__answer:-$__default}"
}

# prompt_choice NAME "Question text" default choice1 choice2 ...
prompt_choice() {
    local __var="$1" __question="$2" __default="$3"; shift 3
    local __choices=("$@") __choice_answer
    prompt __choice_answer "${__question} (${__choices[*]})" "$__default"
    for c in "${__choices[@]}"; do
        [ "$__choice_answer" = "$c" ] && { printf -v "$__var" '%s' "$__choice_answer"; return; }
    done
    warn "\"$__choice_answer\" is not one of (${__choices[*]}), using default \"$__default\""
    printf -v "$__var" '%s' "$__default"
}

random_secret() { openssl rand -hex 16; }

# ---------------------------------------------------------------------------
# 1. Dependency checks
# ---------------------------------------------------------------------------
check_dependencies() {
    info "Checking host dependencies..."
    command -v docker >/dev/null 2>&1 || die "docker is required: https://docs.docker.com/get-docker/"
    docker compose version >/dev/null 2>&1 || die "docker compose (v2 plugin) is required."
    command -v openssl >/dev/null 2>&1 || die "openssl is required to generate passwords."

    if ! command -v mkcert >/dev/null 2>&1; then
        warn "mkcert not found on PATH. It's needed to issue a browser-trusted local TLS cert."
        warn "Install it (e.g. 'brew install mkcert', 'apt install mkcert', or see"
        warn "https://github.com/FiloSottile/mkcert#installation), then re-run this script."
        die "mkcert missing."
    fi
    ok "All required tools found."
}

# ---------------------------------------------------------------------------
# 2. Gather configuration
# ---------------------------------------------------------------------------
gather_config() {
    if [ -f .env ]; then
        prompt_choice REUSE_ENV "An .env file already exists. Reuse it as-is?" "yes" yes no
        if [ "$REUSE_ENV" = "yes" ]; then
            # shellcheck disable=SC1091
            set -a; source .env; set +a
            USING_EXISTING_ENV=1
            HOST_UID_VAL="$HOST_UID"
            HOST_GID_VAL="$HOST_GID"
            ok "Reusing existing .env."
            return
        fi
    fi
    USING_EXISTING_ENV=0

    info "Local domain -- we will append .local to whatever you enter here."
    prompt DOMAIN_BASE "Base domain name (e.g. \"mystore\" -> mystore.local)" "mageos"
    BASE_DOMAIN="${DOMAIN_BASE%.local}.local"
    ok "Using https://${BASE_DOMAIN}"

    prompt_choice PHP_VERSION "PHP version (MageOS 3.x+ target)" "8.3" "8.1" "8.2" "8.3"

    prompt DB_DATABASE "Database name" "mageos"
    prompt DB_USER "Database user" "mageos"
    DB_PASSWORD="$(random_secret)"
    DB_ROOT_PASSWORD="$(random_secret)"
    MARIADB_VERSION="10.6"

    prompt RABBITMQ_USER "RabbitMQ user" "mageos"
    RABBITMQ_PASSWORD="$(random_secret)"

    prompt MAGENTO_ADMIN_USER "Magento admin username" "admin"
    MAGENTO_ADMIN_PASSWORD="$(openssl rand -base64 12)Aa1!"
    prompt MAGENTO_ADMIN_EMAIL "Magento admin email" "admin@${BASE_DOMAIN}"
    MAGENTO_ADMIN_FIRSTNAME="Admin"
    MAGENTO_ADMIN_LASTNAME="User"

    REDIS_VERSION="7.2-alpine"
    OPENSEARCH_VERSION="2.15.0"
    RABBITMQ_VERSION="3.13-management-alpine"
    MAILPIT_VERSION="v1.20.3"
    NODE_VERSION="20.11.0"

    HOST_UID_VAL="$(id -u)"
    HOST_GID_VAL="$(id -g)"

    COMPOSE_PROJECT_NAME="mageos"
}

# ---------------------------------------------------------------------------
# 3. Write .env
# ---------------------------------------------------------------------------
write_env() {
    [ "$USING_EXISTING_ENV" = "1" ] && return

    info "Writing .env..."
    cat > .env <<EOF
# Generated by setup.sh on $(date -u +%Y-%m-%dT%H:%M:%SZ). Do not commit this file.

COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME}
BASE_DOMAIN=${BASE_DOMAIN}

HOST_UID=${HOST_UID_VAL}
HOST_GID=${HOST_GID_VAL}

PHP_VERSION=${PHP_VERSION}

DB_DATABASE=${DB_DATABASE}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
DB_ROOT_PASSWORD=${DB_ROOT_PASSWORD}
MARIADB_VERSION=${MARIADB_VERSION}

REDIS_VERSION=${REDIS_VERSION}
OPENSEARCH_VERSION=${OPENSEARCH_VERSION}

RABBITMQ_VERSION=${RABBITMQ_VERSION}
RABBITMQ_USER=${RABBITMQ_USER}
RABBITMQ_PASSWORD=${RABBITMQ_PASSWORD}

MAILPIT_VERSION=${MAILPIT_VERSION}

NODE_VERSION=${NODE_VERSION}

MAGENTO_ADMIN_USER=${MAGENTO_ADMIN_USER}
MAGENTO_ADMIN_PASSWORD=${MAGENTO_ADMIN_PASSWORD}
MAGENTO_ADMIN_EMAIL=${MAGENTO_ADMIN_EMAIL}
MAGENTO_ADMIN_FIRSTNAME=${MAGENTO_ADMIN_FIRSTNAME}
MAGENTO_ADMIN_LASTNAME=${MAGENTO_ADMIN_LASTNAME}
EOF
    chmod 600 .env
    ok ".env written (mode 600 -- contains generated passwords)."
}

# ---------------------------------------------------------------------------
# 4. Local TLS via mkcert
# ---------------------------------------------------------------------------
setup_tls() {
    info "Provisioning local TLS certificate for ${BASE_DOMAIN}..."
    mkcert -install

    mkdir -p certs
    mkcert -cert-file "certs/local-cert.pem" -key-file "certs/local-key.pem" \
        "${BASE_DOMAIN}" "*.${BASE_DOMAIN}" "localhost" "127.0.0.1"
    ok "Certificate written to ./certs (trusted by mkcert's local CA)."
}

# ---------------------------------------------------------------------------
# 5. Bootstrap MageOS into ./src
# ---------------------------------------------------------------------------
bootstrap_app() {
    if [ -n "$(ls -A src 2>/dev/null | grep -v '^\.gitkeep$')" ]; then
        ok "./src is not empty -- skipping bootstrap, using existing code."
        return
    fi

    prompt_choice BOOTSTRAP_MODE \
        "./src is empty. Run 'composer create-project' now, or did you already clone/copy MageOS in yourself?" \
        "create" "create" "manual"

    if [ "$BOOTSTRAP_MODE" = "manual" ]; then
        warn "Skipping bootstrap. Place your MageOS checkout in ./src, then re-run this"
        warn "script (or just 'docker compose up -d') to start the stack."
        return
    fi

    prompt MAGEOS_PACKAGE "Composer package to create-project from" "mage-os/project-community-edition"
    prompt MAGEOS_VERSION "Version constraint (leave blank for latest)" ""

    info "Building php-fpm image (needed to run composer)..."
    docker compose build php-fpm

    # composer create-project requires an empty target directory.
    rm -f src/.gitkeep

    # Mage-OS isn't published on Packagist -- it has its own composer repository.
    local __create_args=(create-project --no-interaction --repository-url=https://repo.mage-os.org/)
    if [ -n "$MAGEOS_VERSION" ]; then
        __create_args+=("${MAGEOS_PACKAGE}" . "${MAGEOS_VERSION}")
    else
        __create_args+=("${MAGEOS_PACKAGE}" .)
    fi

    info "Running composer create-project (this can take a while)..."
    docker compose run --rm --no-deps -u "${HOST_UID_VAL}:${HOST_GID_VAL}" php-fpm \
        composer "${__create_args[@]}"

    touch src/.gitkeep
}

# ---------------------------------------------------------------------------
# 6. Bring the stack up and run setup:install
# ---------------------------------------------------------------------------
compose_up() {
    info "Building remaining images..."
    docker compose build

    info "Starting the stack and waiting for backing services to become healthy..."
    docker compose up -d --wait --wait-timeout 180

    if [ -f src/app/etc/env.php ]; then
        ok "Magento already installed (src/app/etc/env.php exists) -- skipping setup:install."
        return
    fi

    info "Running bin/magento setup:install..."
    docker compose exec -T -u www-data php-fpm bin/magento setup:install \
        --base-url="https://${BASE_DOMAIN}/" \
        --db-host="mariadb" \
        --db-name="${DB_DATABASE}" \
        --db-user="${DB_USER}" \
        --db-password="${DB_PASSWORD}" \
        --backend-frontname=admin \
        --admin-firstname="${MAGENTO_ADMIN_FIRSTNAME}" \
        --admin-lastname="${MAGENTO_ADMIN_LASTNAME}" \
        --admin-email="${MAGENTO_ADMIN_EMAIL}" \
        --admin-user="${MAGENTO_ADMIN_USER}" \
        --admin-password="${MAGENTO_ADMIN_PASSWORD}" \
        --language=en_US \
        --currency=USD \
        --timezone=America/Sao_Paulo \
        --use-rewrites=1 \
        --search-engine=opensearch \
        --opensearch-host=opensearch \
        --opensearch-port=9200 \
        --amqp-host=rabbitmq \
        --amqp-port=5672 \
        --amqp-user="${RABBITMQ_USER}" \
        --amqp-password="${RABBITMQ_PASSWORD}" \
        --session-save=redis \
        --session-save-redis-host=redis \
        --cache-backend=redis \
        --cache-backend-redis-server=redis \
        --page-cache=redis \
        --page-cache-redis-server=redis

    # Route Magento's outbound mail (order confirmations, password resets,
    # admin notifications) through Mailpit instead of a real SMTP server, so
    # local development never sends real email.
    docker compose exec -T -u www-data php-fpm bin/magento config:set system/smtp/transport smtp
    docker compose exec -T -u www-data php-fpm bin/magento config:set system/smtp/host mailpit
    docker compose exec -T -u www-data php-fpm bin/magento config:set system/smtp/port 1025
    docker compose exec -T -u www-data php-fpm bin/magento config:set system/smtp/auth none
    docker compose exec -T -u www-data php-fpm bin/magento config:set system/smtp/ssl "" --lock-env
    docker compose exec -T -u www-data php-fpm bin/magento cache:flush

    ok "MageOS installed."
    JUST_INSTALLED=1
}

# ---------------------------------------------------------------------------
# 7. Summary
# ---------------------------------------------------------------------------
print_summary() {
    echo
    ok "Stack is up."
    echo "  Storefront / admin:  https://${BASE_DOMAIN}"
    echo "  Mail (Mailpit):      https://mail.${BASE_DOMAIN}"
    echo "  Traefik dashboard:   http://127.0.0.1:8080"
    echo "  RabbitMQ mgmt:       docker compose exec rabbitmq rabbitmqctl status"
    if [ "${JUST_INSTALLED:-0}" = "1" ]; then
        echo
        echo "  Admin user:     ${MAGENTO_ADMIN_USER}"
        echo "  Admin password: ${MAGENTO_ADMIN_PASSWORD}"
        echo "  (also saved in .env)"
    fi
    echo
    echo "  Theme build watcher: docker compose exec node npx grunt watch"
    echo
}

main() {
    check_dependencies
    gather_config
    write_env
    setup_tls
    bootstrap_app
    compose_up
    print_summary
}

main "$@"
