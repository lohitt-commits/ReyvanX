# Service container images (Task 3)

Task 3 is **not complete** until a Dashboard source/build is available and all
four service images pass the required checks. These assets build the three
backend services from this checkout; they do not replace Task 2's combined-server
quickstart or implement Task 4's full-stack Compose deployment.

## Build

Start Docker Desktop, then run from the repository root:

```sh
sh deploy/docker/build-images.sh
```

This builds and loads `reyvanx/management`, `reyvanx/signal`, and `reyvanx/relay`
for `linux/amd64` and `linux/arm64`, tagged `dev-<short Git commit>`. Use an
explicit tag to identify a release candidate:

```sh
IMAGE_TAG=my-release-candidate sh deploy/docker/build-images.sh
```

For a faster build targeting only an Intel Linux host:

```sh
PLATFORMS=linux/amd64 sh deploy/docker/build-images.sh
```

Multi-platform loading requires a Docker image store that supports image
indexes, such as the containerd image store in the tested Docker Desktop.
Management builds natively for each target because SQLite requires CGO;
cross-architecture builds use emulation when a native builder is unavailable.
Signal and Relay cross-compile using Go on the builder's native platform.

All images use:

- Multi-stage builds with no compiler or source tree in the final image.
- Digest-pinned Go 1.26.7 and runtime image indexes.
- A numeric, unprivileged UID/GID (`65532:65532`).
- Unprivileged default listening ports (`8080`).
- OCI version and source-revision labels and commit-based image tags.
- BuildKit module/compiler caches and stripped binaries.

Management uses the distroless base runtime for its libc dependency; Signal and
Relay use the smaller static runtime. TLS CA certificates are included. The
application's wire version remains `development`, as intended for source
snapshots; image labels/tags do not pretend this checkout is an upstream release.
Never pass tokens, private keys, or database credentials as build arguments.

## Test startup and endpoints

```sh
sh deploy/docker/smoke-test.sh
```

If you selected a custom tag, pass the same `IMAGE_TAG` to the test. The test:

- Checks each image's configured UID/GID.
- Runs all three services with a read-only root filesystem, no capabilities,
  and `no-new-privileges`.
- Uses ephemeral, loopback-only host ports.
- Starts Management with a fresh SQLite volume and embedded IdP.
- Checks Management `/api/instance`, Signal `/metrics`, and Relay `/metrics`.
- Removes only its own test containers, test volume, and temporary configuration
  on exit. It does not use or remove the Task 2 database.

These checks prove service startup and HTTP endpoint responsiveness, not peer
registration, authentication flows, or a complete deployment's health.
Those integration checks belong to Task 4.

For an emulated architecture entrypoint check on an Intel host:

```sh
docker run --rm --platform linux/arm64 reyvanx/signal:YOUR_TAG --help
docker run --rm --platform linux/arm64 reyvanx/relay:YOUR_TAG --help
```

Distroless images have no shell or `curl`. Future Compose/Kubernetes probes
must use supported external HTTP/TCP checks or an explicitly designed probe
executable, not shell commands that are absent from the image.

## Vulnerability scanning

Use local Trivy scanning without uploading application images or mounting the
Docker socket. Example for one image, after Docker is available on `PATH`:

```sh
SCAN_DIR="$(mktemp -d)"
docker image save --platform linux/amd64 \
  -o "$SCAN_DIR/management.tar" reyvanx/management:YOUR_TAG
docker run --rm \
  -v "$SCAN_DIR:/reports" \
  -v reyvanx-task3-trivy-cache:/root/.cache/trivy \
  aquasec/trivy:0.69.3@sha256:bcc376de8d77cfe086a917230e818dc9f8528e3c852f7b1aff648949b6258d1c \
  image --scanners vuln --input /reports/management.tar
rm "$SCAN_DIR/management.tar"
rmdir "$SCAN_DIR"
```

Repeat for Signal and Relay. Trivy downloads its public vulnerability database;
image analysis runs locally. Scanner findings are not a proof of exploitability,
and a successful scan command is not a clean security result. Do not suppress
findings or bump application dependencies without reviewing and approving the
changes. Results and outstanding findings are recorded in
[IMPLEMENTATION_NOTES.md](../IMPLEMENTATION_NOTES.md).

## Dashboard blocker

The browser Dashboard is external to this repository. `client/ui/frontend` is
the desktop client UI, not the web Dashboard; `proxy/web` is not the Dashboard
either. Repackaging `netbirdio/dashboard:latest` would not demonstrate a
source-built, non-root, multi-stage Dashboard image.

Lohit must supply the intended Dashboard repository and compatible commit/tag,
or approve a specific upstream Dashboard release. No Dashboard Dockerfile is
invented here, and the published image used in Task 2 is not counted as a Task 3
build.
