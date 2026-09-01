# `setup.sh` explained, line by line

This walks through every line of [`setup.sh`](../setup.sh) for someone who doesn't read Bash
regularly. Read the **"Bash basics"** section once, then use the rest as a reference while you
scroll through the actual script side by side.

---

## Bash basics used throughout this script

A handful of Bash idioms show up over and over. Knowing these once means you won't need them
re-explained at every line below.

| Syntax | Meaning |
|---|---|
| `#!/usr/bin/env bash` | The "shebang" — tells the OS which interpreter runs this file. |
| `# comment` | Everything after `#` on a line is a comment, ignored by Bash. |
| `VAR="value"` | Assigns a variable. **No spaces** around `=` in Bash. |
| `"$VAR"` or `"${VAR}"` | Reads a variable's value. Always quote variables (`"$VAR"`) so values with spaces don't get split into multiple words. |
| `${VAR:-default}` | "Use `$VAR`, or `default` if `VAR` is unset/empty." |
| `${VAR%.local}` | Strips the suffix `.local` off the end of `$VAR` if it's there. |
| `$(command)` | "Command substitution" — runs `command` and substitutes its output as text. E.g. `NOW=$(date)`. |
| `local x=1` | Declares `x` as a variable scoped only to the current function (doesn't leak out). |
| `func() { ...; }` | Defines a function named `func`. |
| `"$@"` | All arguments passed to the script/function, each preserved as a separate word. |
| `[ condition ]` | Bash's `test` command — evaluates a condition, used in `if`/`while`. |
| `command1 || command2` | Run `command2` **only if** `command1` fails (returns a non-zero exit code). |
| `command1 && command2` | Run `command2` **only if** `command1` succeeds. |
| `>&2` | Redirect output to "stderr" (the error stream) instead of normal stdout. |
| `>` / `>>` | Redirect output to a file, overwriting (`>`) or appending (`>>`). |
| `<<EOF ... EOF` | A "heredoc" — a multi-line block of text fed to a command, ending at the matching `EOF` marker. |
| Exit codes | Every command returns a number when it finishes: `0` = success, anything else = failure. `if command; then` checks this automatically. |
| Arrays: `arr=(a b c)`, `"${arr[@]}"` | Bash lists. `"${arr[@]}"` expands to each element as its own word. `arr+=(x)` appends. |
| `shift N` | Discards the first `N` positional arguments (`$1`, `$2`, …) inside a function, shifting the rest down. |

With that vocabulary, here's the script itself.

---

## Lines 1–9 — Header comment

```bash
#!/usr/bin/env bash
#
# Interactive setup for the MageOS Docker environment.
# ...
```

The shebang (line 1) tells the OS to run this file with `bash`. Lines 2–9 are just comments
(ignored by Bash) documenting what the script does and confirming it's safe to run more than
once — it reuses your existing `.env` instead of clobbering it, and skips re-downloading MageOS
if `./src` already has code in it.

---

## Line 11 — Safety flags

```bash
set -euo pipefail
```

This turns on three safety behaviors for the whole script:

- **`-e`** — exit immediately if *any* command fails (non-zero exit code), instead of plowing
  ahead with a broken state.
- **`-u`** — treat using an *unset* variable as an error, instead of silently substituting an
  empty string. Catches typos like `$BASE_DOMIAN`.
- **`-o pipefail`** — normally in a pipeline like `cmd1 | cmd2`, only `cmd2`'s exit code counts.
  This makes the whole pipeline fail if *any* stage of it fails.

Together these make the script "fail loud and fail fast" rather than continuing after something
breaks.

---

## Lines 13–14 — Always run from the script's own directory

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
```

`${BASH_SOURCE[0]}` is the path to this script file itself. `dirname` strips the filename,
leaving just the directory it lives in. `cd`-ing into that directory and running `pwd` prints
its absolute path, which gets saved into `SCRIPT_DIR`. The second line then `cd`s the shell
into that directory.

**Why:** this guarantees the script behaves the same whether you run it as `./setup.sh` from
inside the project folder or as `/some/path/setup.sh` from anywhere else — relative paths like
`.env` or `src/` always resolve to the project root, not wherever you happened to be standing.

---

## Lines 16–23 — Colored output helpers

```bash
c_reset='\033[0m'; c_bold='\033[1m'; c_green='\033[32m'; c_yellow='\033[33m'; c_red='\033[31m'
info()  { printf "%b\n" "${c_bold}==>${c_reset} $*"; }
ok()    { printf "%b\n" "${c_green}==>${c_reset} $*"; }
warn()  { printf "%b\n" "${c_yellow}==>${c_reset} $*"; }
die()   { printf "%b\n" "${c_red}==>${c_reset} $*" >&2; exit 1; }
```

Line 19 defines terminal escape codes as variables — these are the special byte sequences that
make text bold or colored in a terminal (`\033` is the "escape" character that starts them;
`[0m` resets, `[1m` bolds, `[32m`/`[33m`/`[31m` are green/yellow/red). Semicolons let you put
several statements on one line.

Lines 20–23 define four tiny functions used throughout the script to print status messages
consistently:

- `info "text"` — a bold `==>` prefix, for normal progress messages.
- `ok "text"` — a green `==>` prefix, for success messages.
- `warn "text"` — a yellow `==>` prefix, for warnings.
- `die "text"` — a red `==>` prefix, printed to **stderr** (`>&2`) instead of stdout, and then
  `exit 1` immediately stops the whole script with a failure code.

`$*` inside each function means "all the arguments passed to this function, joined by spaces" —
so `info "hello" "world"` prints `hello world`. `printf "%b\n"` (rather than `echo`) is used
because `%b` tells `printf` to actually interpret those `\033[...]` escape sequences instead of
printing them as literal text.

---

## Lines 25–34 — `prompt`: ask the user a question

```bash
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
```

This is a reusable helper for every interactive question in the script (used like
`prompt DB_USER "Database user" "mageos"`).

- `local __var="$1" ...` — captures the function's three arguments (the variable name to fill
  in, the question text, and a default value) into local variables. `${3:-}` means "use `$3` if
  given, otherwise an empty string" (needed because `set -u` would otherwise error on a missing
  third argument).
- `if [ -n "$__default" ]` — `-n` tests "is this string non-empty?". If a default was given, the
  prompt shows it in brackets, e.g. `Database user [mageos]:`; otherwise it prompts with no
  bracket.
- `read -r -p "..." __answer` — this is the actual "ask the user and wait for input" step.
  `-p "..."` prints the prompt text; `-r` stops backslashes in the typed input from being
  treated as escape characters; the typed line is stored into `__answer`.
- `printf -v "$__var" '%s' "${__answer:-$__default}"` — this is how the function "returns" a
  value into the *caller's* variable name. `-v NAME` tells `printf` to store its formatted
  output into the variable named `NAME` instead of printing it. `"${__answer:-$__default}"`
  means: if the user typed nothing (just hit Enter), fall back to the default.

The double-underscore variable names (`__var`, `__question`, …) are just a convention to avoid
accidentally colliding with the variable name the caller passed in (e.g. if you called
`prompt __answer ...`, using `answer` internally would clash).

---

## Lines 36–46 — `prompt_choice`: ask a multiple-choice question

```bash
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
```

Builds on `prompt` above, but restricts the answer to a fixed set of choices (used like
`prompt_choice PHP_VERSION "PHP version" "8.3" "8.1" "8.2" "8.3"`).

- `local __var=... ; shift 3` — grabs the first three arguments (variable name, question,
  default) by name, then `shift 3` discards those three from the argument list so that
  everything *remaining* is the list of valid choices.
- `__choices=("$@")` — collects all the remaining arguments into an array called `__choices`.
- `prompt __choice_answer "${__question} (${__choices[*]})" "$__default"` — reuses the `prompt`
  function to actually ask the question, appending the list of valid choices in parentheses so
  the user sees them (`${__choices[*]}` joins the array into one space-separated string).
- `for c in "${__choices[@]}"; do ... done` — loops over each valid choice. `"${__choices[@]}"`
  (with `@`) expands each array element as its own word, which is the correct way to iterate an
  array.
- `[ "$__choice_answer" = "$c" ] && { ...; return; }` — if the user's answer matches this
  choice exactly, store it into the caller's variable and exit the function early (`return`).
- If the loop finishes without finding a match, the last two lines warn the user and fall back
  to the default value instead of accepting an invalid answer.

---

## Line 48 — Random password generator

```bash
random_secret() { openssl rand -hex 16; }
```

A one-line function wrapping `openssl rand -hex 16`, which asks OpenSSL for 16 random bytes and
prints them as a 32-character hexadecimal string. Used later to generate database and RabbitMQ
passwords without ever hand-typing or hardcoding one.

---

## Lines 53–66 — `check_dependencies`: verify required tools are installed

```bash
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
```

`command -v <name>` checks whether `<name>` exists as a runnable command, printing its path (or
nothing, if absent) — but here that output is thrown away with `>/dev/null 2>&1` (redirect both
normal output *and* error output to the null device, i.e. discard it), because we only care
about its exit code, not its output.

- `command -v docker >/dev/null 2>&1 || die "..."` — reads as: "check for `docker`; if that
  check *fails* (`||`), stop the script with an error message." Same pattern for
  `docker compose version` (checks the Compose v2 plugin specifically, since older standalone
  `docker-compose` doesn't count) and `openssl`.
- The `mkcert` check is written differently, as an `if ! command -v mkcert ...; then` block,
  because a missing `mkcert` needs a multi-line explanation (three `warn` lines with install
  instructions) before finally calling `die`. `!` negates the check, so this block runs when
  mkcert is **not** found.
- If every check passes, `ok "All required tools found."` prints in green.

---

## Lines 71–118 — `gather_config`: collect all configuration values

### Reusing an existing `.env`

```bash
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
```

- `[ -f .env ]` — `-f` tests "does this path exist and is it a regular file?" If a `.env`
  already exists from a previous run, the script asks (via `prompt_choice`) whether to reuse it.
- If the user says yes: `set -a; source .env; set +a` loads every `KEY=value` line from `.env`
  into the shell as real variables. `source` runs the file's contents in the current shell
  (rather than a subprocess); wrapping it in `set -a` / `set +a` marks every variable it defines
  as "exported" so child processes (like `docker compose`) can see them too, then turns that
  auto-export behavior back off afterward. The `# shellcheck disable=SC1091` comment silences a
  linter warning about not being able to statically verify `.env`'s contents.
- `USING_EXISTING_ENV=1` records that we reused the file (checked later so `write_env` doesn't
  overwrite it), and `return` exits the `gather_config` function early — none of the prompts
  below run in this case.
- If `.env` doesn't exist, or the user declined to reuse it, `USING_EXISTING_ENV=0` is set and
  execution falls through to gather everything fresh.

### Domain name

```bash
    info "Local domain -- we will append .local to whatever you enter here."
    prompt DOMAIN_BASE "Base domain name (e.g. \"mystore\" -> mystore.local)" "mageos"
    BASE_DOMAIN="${DOMAIN_BASE%.local}.local"
    ok "Using https://${BASE_DOMAIN}"
```

Asks for a short name (default `mageos`). `${DOMAIN_BASE%.local}` strips a trailing `.local` if
the user already typed one (so typing either `mystore` or `mystore.local` both end up as
`mystore.local`, not `mystore.local.local`), then `.local` is appended back on.

### Simple choices and values

```bash
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
```

- `PHP_VERSION` is picked from a fixed list (`8.1`/`8.2`/`8.3`) via `prompt_choice`.
- Database name/user are asked interactively; both passwords are generated with `random_secret`
  (the hex-string function from line 48) rather than typed by hand.
- `MARIADB_VERSION="10.6"` is hardcoded (not prompted) — this is the exact line you had selected
  earlier. It pins the MariaDB Docker image tag used in `docker-compose.yml`
  (`mariadb:${MARIADB_VERSION}`) so the database version is fixed and reproducible rather than
  left to whatever `:latest` happens to be.
- RabbitMQ user is prompted; its password is generated.
- The Magento admin username/email are prompted; the admin password is generated as
  `$(openssl rand -base64 12)Aa1!` — 12 random base64 bytes with `Aa1!` appended to guarantee it
  contains an uppercase letter, lowercase letter, digit, and symbol (Magento's admin password
  policy requires a mix of character classes). First/last name are just hardcoded placeholders.

### Fixed infrastructure versions

```bash
    REDIS_VERSION="7.2-alpine"
    OPENSEARCH_VERSION="2.15.0"
    RABBITMQ_VERSION="3.13-management-alpine"
    MAILPIT_VERSION="v1.20.3"
    NODE_VERSION="20.11.0"
```

These aren't user-configurable — they're pinned versions for the remaining Docker images, kept
here as plain variables so they end up in `.env` alongside everything else, following this
project's "no unpinned `:latest` tags" rule (see `CLAUDE.md`).

### Host user/group IDs and project name

```bash
    HOST_UID_VAL="$(id -u)"
    HOST_GID_VAL="$(id -g)"

    COMPOSE_PROJECT_NAME="mageos"
}
```

`id -u` / `id -g` print your current Linux user ID and group ID. These get passed into the
`php-fpm`/`node` container builds (see `docker-compose.yml`'s `UID`/`GID` build args) so that
files created inside the container are owned by *you* on the host, not by `root` — avoiding the
permission headaches that show up otherwise on bind-mounted volumes.
`COMPOSE_PROJECT_NAME="mageos"` sets the prefix Docker Compose uses for container/network/volume
names (you saw this earlier as the `mageos_` prefix on every container, e.g. `mageos_nginx`).

---

## Lines 123–163 — `write_env`: save everything to `.env`

```bash
write_env() {
    [ "$USING_EXISTING_ENV" = "1" ] && return

    info "Writing .env..."
    cat > .env <<EOF
# Generated by setup.sh on $(date -u +%Y-%m-%dT%H:%M:%SZ). Do not commit this file.

COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME}
BASE_DOMAIN=${BASE_DOMAIN}
...
EOF
    chmod 600 .env
    ok ".env written (mode 600 -- contains generated passwords)."
}
```

- `[ "$USING_EXISTING_ENV" = "1" ] && return` — if `gather_config` already decided to reuse an
  existing `.env`, skip writing a new one entirely.
- `cat > .env <<EOF ... EOF` is a **heredoc**: everything between `<<EOF` and the closing `EOF`
  is treated as one block of text and written to `.env` (`>` overwrites the file). Because the
  heredoc isn't quoted (`<<EOF`, not `<<'EOF'`), every `${VARIABLE}` inside it gets substituted
  with its actual value before being written — that's how all the values gathered above end up
  as real `KEY=value` lines in the file. `$(date -u +%Y-%m-%dT%H:%M:%SZ)` stamps the file with
  the current UTC timestamp in ISO 8601 format.
- `chmod 600 .env` restricts the file's permissions so only your own user account can read or
  write it (not other users on the machine) — appropriate since it holds generated database and
  admin passwords in plain text.

---

## Lines 168–176 — `setup_tls`: generate a locally-trusted HTTPS certificate

```bash
setup_tls() {
    info "Provisioning local TLS certificate for ${BASE_DOMAIN}..."
    mkcert -install

    mkdir -p certs
    mkcert -cert-file "certs/local-cert.pem" -key-file "certs/local-key.pem" \
        "${BASE_DOMAIN}" "*.${BASE_DOMAIN}" "localhost" "127.0.0.1"
    ok "Certificate written to ./certs (trusted by mkcert's local CA)."
}
```

- `mkcert -install` creates (if needed) and installs mkcert's local Certificate Authority into
  your system/browser trust stores, so certificates it issues are trusted without browser
  warnings.
- `mkdir -p certs` creates the `certs/` directory if it doesn't already exist (`-p` also means
  "don't error if it already exists").
- `mkcert -cert-file ... -key-file ...` then issues an actual certificate covering your base
  domain, a wildcard for any subdomain (`*.${BASE_DOMAIN}`, needed for `mail.${BASE_DOMAIN}`),
  `localhost`, and `127.0.0.1`. The trailing `\` at the end of the first line is a **line
  continuation** — it tells Bash "this command isn't finished, keep reading the next line as
  part of the same command," purely for readability.

---

## Lines 181–219 — `bootstrap_app`: download MageOS into `./src`

```bash
    if [ -n "$(ls -A src 2>/dev/null | grep -v '^\.gitkeep$')" ]; then
        ok "./src is not empty -- skipping bootstrap, using existing code."
        return
    fi
```

`ls -A src` lists everything in `src/` including hidden files (but not `.` and `..`).
`2>/dev/null` discards any error message if `src` doesn't exist yet. That's piped into
`grep -v '^\.gitkeep$'`, which filters *out* (`-v` inverts the match) any line that's exactly
`.gitkeep` — a placeholder file used to make Git track the otherwise-empty `src/` directory.
`[ -n "$(...)" ]` then checks: after removing `.gitkeep` from the listing, is there anything
left? If yes, real code already exists in `src/`, so bootstrap is skipped entirely.

```bash
    prompt_choice BOOTSTRAP_MODE \
        "./src is empty. Run 'composer create-project' now, or did you already clone/copy MageOS in yourself?" \
        "create" "create" "manual"

    if [ "$BOOTSTRAP_MODE" = "manual" ]; then
        warn "Skipping bootstrap. Place your MageOS checkout in ./src, then re-run this"
        warn "script (or just 'docker compose up -d') to start the stack."
        return
    fi
```

If `src/` really is empty, asks whether to auto-install MageOS (`create`, the default) or
whether you're placing your own checkout there yourself (`manual`). Choosing `manual` just
prints instructions and returns without doing anything further.

```bash
    prompt MAGEOS_PACKAGE "Composer package to create-project from" "mage-os/project-community-edition"
    prompt MAGEOS_VERSION "Version constraint (leave blank for latest)" ""

    info "Building php-fpm image (needed to run composer)..."
    docker compose build php-fpm

    # composer create-project requires an empty target directory.
    rm -f src/.gitkeep
```

Asks which Composer package to install and an optional version constraint. `docker compose
build php-fpm` builds just the `php-fpm` image (defined in `docker-compose.yml`) since it's
needed to actually run the `composer` command in the next step. `rm -f src/.gitkeep` deletes the
placeholder file (`-f` = don't error if it's already gone) because Composer's
`create-project` refuses to install into a non-empty directory, and that leftover file would
count as "non-empty."

```bash
    local __create_args=(create-project --no-interaction --repository-url=https://repo.mage-os.org/)
    if [ -n "$MAGEOS_VERSION" ]; then
        __create_args+=("${MAGEOS_PACKAGE}" . "${MAGEOS_VERSION}")
    else
        __create_args+=("${MAGEOS_PACKAGE}" .)
    fi
```

Builds up the exact arguments to pass to `composer` as an array, piece by piece, rather than one
long string — this avoids quoting headaches when the arguments get used later. It starts with
the base flags, then appends (`+=`) either `<package> . <version>` or just `<package> .`
depending on whether a version was given. (`.` means "install into the current directory,"
which is `src/` since `docker compose run` below runs with that as its working directory.)
`https://repo.mage-os.org/` is used because MageOS packages aren't published on the default
Packagist registry.

```bash
    info "Running composer create-project (this can take a while)..."
    docker compose run --rm --no-deps -u "${HOST_UID_VAL}:${HOST_GID_VAL}" php-fpm \
        composer "${__create_args[@]}"

    touch src/.gitkeep
}
```

`docker compose run` starts a one-off container from the `php-fpm` image and runs `composer
<args>` inside it. `--rm` deletes the container once it exits (no leftover stopped containers
piling up), `--no-deps` skips starting `php-fpm`'s dependent services (database, Redis, etc. —
not needed just to download code), and `-u "${HOST_UID_VAL}:${HOST_GID_VAL}"` runs the process
as your host user/group IDs instead of the container's default user, so the downloaded files end
up owned by you, not `root`. `"${__create_args[@]}"` expands the array built above back into
separate arguments. Finally, `touch src/.gitkeep` recreates the placeholder file that was
removed earlier (harmless now that `src/` has real content, and keeps the file present for next
time).

---

## Lines 224–283 — `compose_up`: start the stack and install Magento

```bash
    info "Building remaining images..."
    docker compose build

    info "Starting the stack and waiting for backing services to become healthy..."
    docker compose up -d --wait --wait-timeout 180
```

`docker compose build` builds any images not already built (php-fpm was likely already built in
`bootstrap_app`, so this mainly covers `nginx` and `node`). `docker compose up -d` starts every
service in the background (`-d` = "detached," don't tie up the terminal). `--wait` makes the
command block until every service with a `healthcheck` (see `docker-compose.yml` — MariaDB,
Redis, OpenSearch, RabbitMQ) reports healthy, instead of returning as soon as containers merely
*start*; `--wait-timeout 180` caps that wait at 180 seconds before giving up.

```bash
    if [ -f src/app/etc/env.php ]; then
        ok "Magento already installed (src/app/etc/env.php exists) -- skipping setup:install."
        return
    fi
```

Magento writes `app/etc/env.php` as part of installation (it holds the resolved DB connection
info, cache config, etc.). If that file already exists, Magento's already installed, so the
expensive `setup:install` step below is skipped — this is what makes re-running `setup.sh` safe.

```bash
    info "Running bin/magento setup:install..."
    docker compose exec -T -u www-data php-fpm bin/magento setup:install \
        --base-url="https://${BASE_DOMAIN}/" \
        --db-host="mariadb" \
        ...
        --page-cache-redis-server=redis
```

`docker compose exec` runs a command *inside* an already-running container (unlike `run`, which
starts a brand-new one) — here, inside the already-started `php-fpm` service. `-T` disables
pseudo-TTY allocation (appropriate for a non-interactive script rather than an interactive
shell), and `-u www-data` runs the command as the `www-data` user (the standard low-privilege
web-server user) rather than root. The single long command is Magento's official installer,
`bin/magento setup:install`, with each `--flag=value` on its own line (again joined with `\`
line continuations purely for readability) wiring it up to talk to the `mariadb`, `redis`,
`opensearch`, and `rabbitmq` containers by their Compose service names, and pre-filling the
admin account from the values gathered earlier.

```bash
    docker compose exec -T -u www-data php-fpm bin/magento config:set system/smtp/transport smtp
    docker compose exec -T -u www-data php-fpm bin/magento config:set system/smtp/host mailpit
    docker compose exec -T -u www-data php-fpm bin/magento config:set system/smtp/port 1025
    docker compose exec -T -u www-data php-fpm bin/magento config:set system/smtp/auth none
    docker compose exec -T -u www-data php-fpm bin/magento config:set system/smtp/ssl "" --lock-env
    docker compose exec -T -u www-data php-fpm bin/magento cache:flush
```

Five more `bin/magento config:set` calls point Magento's outgoing mail at the `mailpit`
container (an SMTP-capturing tool with a web UI, so local dev never sends real email to real
addresses) instead of a real mail server. `--lock-env` on the last one writes that particular
setting into `env.php` directly rather than the database, so it can't accidentally be
overridden later via the admin UI. `cache:flush` clears Magento's cache afterward so the new
config takes effect immediately.

```bash
    docker compose exec -T -u www-data php-fpm bin/magento module:disable Magento_TwoFactorAuth

    ok "MageOS installed."
    JUST_INSTALLED=1
}
```

Disables Magento's built-in two-factor auth module — useful in production, but it would block
your very first admin login on a throwaway local dev box until you enroll an authenticator app,
so it's turned off here. `JUST_INSTALLED=1` is a flag variable read later by `print_summary`, so
the admin credentials are only echoed to the terminal on the run that actually created them (not
on every subsequent re-run of the script).

---

## Lines 288–304 — `print_summary`: final report to the user

```bash
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
```

Just a plain-text summary printed at the very end: the URLs for the storefront/admin and
Mailpit, how to check the Traefik dashboard and RabbitMQ status, and — only if this run actually
installed Magento fresh (`"${JUST_INSTALLED:-0}" = "1"`, defaulting to `0` if the variable was
never set) — the generated admin username and password, since that's the one time you actually
need to see them printed out.

---

## Lines 306–317 — `main`: the actual execution order

```bash
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
```

Every step above was just a function *definition* — none of it actually runs until called. This
`main` function calls each step in order, top to bottom, which is the real sequence of what
happens when you run the script: verify tools are installed → ask questions → save `.env` →
generate a TLS cert → download MageOS if needed → build/start Docker and install Magento if
needed → print the summary. The final line, `main "$@"`, is what actually kicks all of this off,
passing through any arguments the script itself was called with (`"$@"` — not used by this
script today, but a standard defensive habit).
