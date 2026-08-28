# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project status

This repository is currently empty — the project has not been scaffolded yet. This file captures the intended
project scope as described by the user so future sessions have context before code exists. Update this file
with real commands and architecture notes as soon as the project structure is created.

## Project goal

Build a Dockerized environment for running **MageOS** (the community fork of Magento Open Source). The
environment should be:

- **Configurable via env files and/or an interactive setup script** — the script should prompt the user for
  the configuration values it needs (rather than requiring manual editing of files) and/or read them from
  `.env`-style files.
- **Built to containerization/Docker best practices** — this includes things like multi-stage builds, minimal
  image layers, non-root container users, proper use of volumes for persistent data (database, media, etc.),
  separation of services (web, PHP-FPM, database, cache, search, etc.) into distinct containers, and use of
  `docker-compose` (or equivalent) for orchestration.

  ### 1. Dockerfile Best Practices
  * **Base Images:** Use explicit, pinned, minimal base images (`-alpine` or `-slim`). Never use `:latest` or unpinned tags (e.g., use `node:20.11.0-alpine3.19`).
  * **Multi-Stage Builds:** Strictly separate build-time dependencies and compilation steps from the final production runtime image.
  * **Layer Cache Optimization:** Order Dockerfile instructions from least to most frequently changed. Copy package manifest files (`package.json`, `requirements.txt`, `go.mod`) and execute dependency installation before copying the application source code.
  * **Security & Non-Root Execution:** Never run applications as `root` in production. Always switch to an unprivileged user (e.g., `USER node` or `USER appuser`).
  * **Execution Syntax:** Always use array/JSON format (`CMD ["node", "dist/main.js"]`) for `ENTRYPOINT` and `CMD` to ensure OS signals (`SIGTERM`, `SIGINT`) trigger graceful shutdowns.
  * **Context Isolation:** Keep an updated `.dockerignore` file excluding `.git`, `.env`, `node_modules`, build logs, and test artifacts.
  * **Single Responsibility Principle**: every service (Application, Database, Cache, Reverse Proxy) must run in its own dedicated, isolated container.

  ### 2. Docker Compose Architecture
  * **Service Separation:** Define distinct services for API, Frontend, Database, and Cache. Do not package multiple runtimes into a single container.
  * **Data Persistence:** Use named Docker volumes for persistent storage (e.g., database storage directories).
  * **Service Discovery:** Communicate between services using Docker Compose internal network service names (e.g., `postgres:5432`, `redis:6379`) instead of `localhost` or hardcoded IP addresses.
  * **Configuration:** Externalize configuration through `.env` files; never commit secrets, API keys, or credentials into repository files.

## 🎯 AI Assistant Interaction Rules

* **Direct Answers:** Provide solutions immediately without conversational preamble or introductory fluff.
* **Complete Code Snippets:** Provide fully working code blocks or clear contextual snippets ready for direct replacement.
* **Technical Rationale:** Briefly explain the root cause or engineering trade-off when proposing refactors or bug fixes.
* **Dependency Discipline:** Do not introduce new third-party libraries or external packages unless explicitly requested or demonstrably necessary.