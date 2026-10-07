# Running ReyvanX Locally

## Current validation

The repository quickstart was verified locally on Docker Desktop for Mac. The
Dashboard and Management setup APIs load through a localhost-only Caddy proxy.
When the stack is running, the Dashboard opens at `http://127.0.0.1/` and shows
the first-admin setup form. No administrator account has been created.
The stack was stopped after validation; use the start command below to run it again.

The combined server's `/health` endpoint responds with HTTP 503 and reports
`unhealthy` in this HTTP-only quickstart configuration. This result is recorded
as-is below; it is not represented as a healthy status. Management's instance
status and the metrics endpoint both return HTTP 200.

## Everyday commands: start, stop, and status

These commands are for the **already configured stack on this Mac**. Open Docker
Desktop first and wait until its engine is running. Then copy the entire command
block you need into a terminal. You can run these commands from any directory;
they do not depend on `REPO_ROOT`, a previous terminal session, or Docker being
on your `PATH`.

### Start the containers

```sh
REYVANX_REPO=/Users/maheshmure/ReyvanX \
/Applications/Docker.app/Contents/Resources/bin/docker compose \
  -f /Users/maheshmure/reyvanx-local-task2/docker-compose.yml \
  -f /Users/maheshmure/ReyvanX/deploy/local/docker-compose.override.yml \
  up -d
```

Wait for the containers to start, then open **http://127.0.0.1/**.
The `-d` option runs the containers in the background.

### Stop the containers, keeping the database

```sh
REYVANX_REPO=/Users/maheshmure/ReyvanX \
/Applications/Docker.app/Contents/Resources/bin/docker compose \
  -f /Users/maheshmure/reyvanx-local-task2/docker-compose.yml \
  -f /Users/maheshmure/ReyvanX/deploy/local/docker-compose.override.yml \
  down
```

Expect messages saying the containers were stopped and removed. This is normal:
the database volume remains, and the start command recreates the containers.
The Dashboard is unavailable while the stack is stopped.
**Do not add `--volumes` unless you intend to delete the database.**

### Check container status

```sh
REYVANX_REPO=/Users/maheshmure/ReyvanX \
/Applications/Docker.app/Contents/Resources/bin/docker compose \
  -f /Users/maheshmure/reyvanx-local-task2/docker-compose.yml \
  -f /Users/maheshmure/ReyvanX/deploy/local/docker-compose.override.yml \
  ps --all
```

After starting, expect `dashboard`, `netbird-server`, and `local-proxy` to show
`Up`. After stopping, expect an empty container table. `Up` means the container
is running, not that the server's `/health` check is healthy.

These absolute paths are specific to this checkout and its existing generated
stack. On a different computer, adjust both paths. If you see a path starting
with `/deploy/local/`, an unset `REPO_ROOT` variable was used instead of the
commands above.

## Prerequisites

- Docker Desktop for Mac installed and running.
- The Docker CLI must be available. On this machine it is bundled with Docker
  Desktop but is not on the default `PATH`, so add it for the current shell:

  ```sh
  export PATH="/Applications/Docker.app/Contents/Resources/bin:$PATH"
  docker --version
  docker compose version
  docker info
  ```

- Docker Compose 2.24.4 or newer is required for the `!override` port syntax
  used by the local-only override file.
- `jq` and `openssl`, both used by the repository quickstart.

No public domain, Let's Encrypt certificate, AWS account, or AWS resource is
needed for this local test. The quickstart uses its `use-ip` mode, then the
local proxy/configuration below restricts service ports to loopback.

## One-time setup for a new stack

**Skip this section when restarting the existing stack.** Use the everyday
commands above instead. The remaining setup sections are for generating and
configuring a fresh deployment. Keep the same terminal open throughout those
steps because they use `REPO_ROOT` and `STACK_DIR`.

From the repository root, create a fresh working directory outside the
checkout. The quickstart writes generated configuration and a persistent
SQLite volume there.

```sh
export PATH="/Applications/Docker.app/Contents/Resources/bin:$PATH"
REPO_ROOT="$(git rev-parse --show-toplevel)"
STACK_DIR="$HOME/reyvanx-local"
mkdir -p "$STACK_DIR"
cd "$STACK_DIR"

NETBIRD_DOMAIN=use-ip \
NETBIRD_REVERSE_PROXY_TYPE=5 \
NETBIRD_BIND_LOCALHOST_ONLY=true \
NETBIRD_NON_INTERACTIVE=true \
bash "$REPO_ROOT/infrastructure_files/getting-started.sh"
```

Use a new empty `STACK_DIR` for a fresh deployment. The script's manual-proxy
mode generates `docker-compose.yml`, `config.yaml`, and `dashboard.env`, then
starts the quickstart services. Its generated Compose file publishes UDP 3478
on all host interfaces until the local-only override below is applied. Run
this only on a trusted machine/network and apply the override immediately.

The quickstart detects the host's private IP for peer endpoints. For this
single-machine HTTP test, change the generated Dashboard/IdP URLs to loopback:

```sh
perl -0pi -e \
  's|exposedAddress: "http://[^"]+"|exposedAddress: "http://127.0.0.1:80"|; s|issuer: "http://[^"]+/oauth2"|issuer: "http://127.0.0.1/oauth2"|; s|http://[^"]+/nb-auth|http://127.0.0.1/nb-auth|g' \
  config.yaml
```

This intentionally makes advertised peer connectivity local to this host; it
is for local validation, not a production or multi-device configuration.

## Apply the local-only proxy and diagnostic ports

The quickstart's manual-proxy mode publishes the Dashboard on localhost port
8080 and the combined server on port 8081. The local Compose override adds a
Caddy reverse proxy at localhost port 80 so API, OIDC, gRPC, WebSocket, and
Dashboard routes share the expected origin. It also binds STUN, health, and
metrics ports to loopback only.

```sh
REYVANX_REPO="$REPO_ROOT" docker compose \
  -f docker-compose.yml \
  -f "$REPO_ROOT/deploy/local/docker-compose.override.yml" \
  config --quiet

REYVANX_REPO="$REPO_ROOT" docker compose \
  -f docker-compose.yml \
  -f "$REPO_ROOT/deploy/local/docker-compose.override.yml" \
  up -d --force-recreate netbird-server dashboard local-proxy
```

Restrict trusted forwarded-header sources to the local Caddy container. Repeat
this after recreating the Compose network, since Docker can assign Caddy a new
container IP:

```sh
CADDY_ID=$(REYVANX_REPO="$REPO_ROOT" docker compose \
  -f docker-compose.yml \
  -f "$REPO_ROOT/deploy/local/docker-compose.override.yml" \
  ps -q local-proxy)
CADDY_IP=$(docker inspect "$CADDY_ID" --format \
  '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')

perl -0pi -e \
  "s|    trustedHTTPProxies:\\n      - \\\"[^\\\"]+\\\"|    trustedHTTPProxies:\\n      - \\\"$CADDY_IP/32\\\"\\n    trustedPeers:\\n      - \\\"$CADDY_IP/32\\\"|" \
  config.yaml

REYVANX_REPO="$REPO_ROOT" docker compose \
  -f docker-compose.yml \
  -f "$REPO_ROOT/deploy/local/docker-compose.override.yml" \
  up -d --force-recreate netbird-server
```

The override configuration lives in
[`deploy/local/`](./local/). It binds published ports to `127.0.0.1`; do not
remove the override while the local test is running.

## Verify the stack

Check container state:

For the existing stack, use the status command in **Everyday commands** above.
For a fresh deployment, use its generated Compose path and the same override.

Check the browser-facing Dashboard, Management instance status, embedded IdP,
and metrics:

```sh
curl --fail --show-error --output /dev/null --write-out 'Dashboard HTTP %{http_code}\n' \
  http://127.0.0.1/

curl --fail --show-error http://127.0.0.1/api/instance | jq

curl --fail --show-error \
  http://127.0.0.1/oauth2/.well-known/openid-configuration | jq -r '.issuer'

curl --fail --show-error --output /dev/null \
  --write-out 'Metrics HTTP %{http_code}\n' \
  http://127.0.0.1:9090/metrics
```

Open `http://127.0.0.1/` in a browser. On the initial setup, the expected page
is **“Welcome to NetBird”** with the form to create the first administrator.
Creating an account is deliberately not part of this validation.

Check the combined server health endpoint separately:

```sh
curl --include http://127.0.0.1:9000/health
```

In the verified HTTP-only quickstart, this returned HTTP 503 with
`"status":"unhealthy"`, an empty `listeners` value, and
`"certificate_valid":false`. The server log says the Relay WebSocket is
multiplexed on the Management port with no separate Relay listener, while the
health checker expects a Relay listener. The HTTPS/TLS health path has not been
tested. Do not treat the HTTP health result as healthy or change Go code as
part of this setup task.

## Optional: delete the local database

For normal shutdown, use the everyday stop command above. The following command
is **destructive**: it stops the existing stack and deletes its persisted state.
Run it only when intentionally resetting this disposable local test:

```sh
REYVANX_REPO=/Users/maheshmure/ReyvanX \
/Applications/Docker.app/Contents/Resources/bin/docker compose \
  -f /Users/maheshmure/reyvanx-local-task2/docker-compose.yml \
  -f /Users/maheshmure/ReyvanX/deploy/local/docker-compose.override.yml \
  down --volumes
```

The `--volumes` form deletes the SQLite database and must only be used when
resetting this disposable local test.

## Results recorded for this workspace

- Docker Desktop 4.94.0, Docker CLI 29.8.2, Docker Compose 5.5.1; Engine
  reports Linux `x86_64`.
- Quickstart started `netbirdio/dashboard:latest` and
  `netbirdio/netbird-server:latest`; Management startup log reports version
  `0.80.0`. Image tags are floating and are not pinned.
- The local Caddy proxy is running from `caddy:2-alpine`.
- Browser verification at `http://127.0.0.1/` showed the first-admin setup
  form, page title **Instance Setup - NetBird Dashboard**.
- `GET /` returned HTTP 200; `GET /api/instance` returned HTTP 200 with
  `setup_required: true`; OIDC discovery returned HTTP 200 with issuer
  `http://127.0.0.1/oauth2`; metrics returned HTTP 200.
- `GET /health` returned HTTP 503 and reported unhealthy as described above.
- The final Compose port mappings are bound to `127.0.0.1`, including UDP
  3478. No AWS resources were created.
