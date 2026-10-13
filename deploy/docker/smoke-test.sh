#!/bin/sh
set -eu

if ! command -v docker >/dev/null 2>&1; then
    PATH="/Applications/Docker.app/Contents/Resources/bin:$PATH"
    export PATH
fi
docker info >/dev/null
command -v curl >/dev/null
command -v openssl >/dev/null
command -v jq >/dev/null

repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
tag=${IMAGE_TAG:-dev-$(git -C "$repo" rev-parse --short HEAD)}
work=$(mktemp -d)
prefix="reyvanx-image-test-$$"
containers=""
volume="$prefix-data"
cleanup() {
    for container in $containers; do
        docker rm -f "$container" >/dev/null || echo "Cannot remove $container" >&2
    done
    docker volume rm "$volume" >/dev/null || echo "Cannot remove $volume" >&2
    rm -f "$work/management.json"
    rmdir "$work"
}
docker volume create "$volume" >/dev/null
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

jq -n --arg key "$(openssl rand -base64 32)" '{
    Datadir: "/var/lib/netbird",
    DataStoreEncryptionKey: $key,
    StoreConfig: {Engine: "sqlite"},
    Signal: {Proto: "http", URI: "127.0.0.1:8080"},
    HttpConfig: {},
    EmbeddedIdP: {
        Enabled: true,
        Issuer: "http://127.0.0.1:8080/oauth2",
        LocalAddress: ":8080",
        Storage: {Type: "sqlite3", Config: {File: "/var/lib/netbird/idp.db"}},
        DashboardRedirectURIs: ["http://127.0.0.1/nb-auth"]
    }
}' > "$work/management.json"
chmod 644 "$work/management.json"

for service in management signal relay; do
    image="reyvanx/$service:$tag"
    user=$(docker image inspect "$image" --format '{{.Config.User}}')
    if [ "$user" != "65532:65532" ]; then
        echo "$image must run as UID/GID 65532, found: $user" >&2
        exit 1
    fi
    container="$prefix-$service"
    containers="$containers $container"
    case "$service" in
        management)
            docker run -d --name "$container" --read-only --cap-drop ALL \
                --security-opt no-new-privileges --tmpfs /tmp \
                -p 127.0.0.1::8080 \
                --mount "type=volume,source=$volume,target=/var/lib/netbird" \
                --mount "type=bind,source=$work/management.json,target=/etc/netbird/management.json,readonly" \
                "$image" --log-file console --log-level warn --port 8080 \
                --disable-legacy-port --disable-anonymous-metrics --disable-geolite-update \
                >/dev/null
            port=8080
            endpoint=/api/instance
            ;;
        signal)
            docker run -d --name "$container" --read-only --cap-drop ALL \
                --security-opt no-new-privileges --tmpfs /tmp \
                -p 127.0.0.1::9090 "$image" --log-file console \
                --log-level warn --port 8080 >/dev/null
            port=9090
            endpoint=/metrics
            ;;
        relay)
            NB_AUTH_SECRET=$(openssl rand -hex 32)
            export NB_AUTH_SECRET
            docker run -d --name "$container" --read-only --cap-drop ALL \
                --security-opt no-new-privileges --tmpfs /tmp \
                -e NB_AUTH_SECRET -p 127.0.0.1::9090 \
                "$image" --log-file console --log-level warn \
                --listen-address :8080 --exposed-address rel://127.0.0.1:8080 \
                >/dev/null
            unset NB_AUTH_SECRET
            port=9090
            endpoint=/metrics
            ;;
    esac
    address=$(docker port "$container" "$port/tcp")
    attempts=0
    until curl --fail --silent --output /dev/null "http://$address$endpoint"; do
        attempts=$((attempts + 1))
        if [ "$attempts" -ge 60 ] || \
            [ "$(docker inspect "$container" --format '{{.State.Running}}')" != true ]; then
            echo "$service failed its endpoint check: http://$address$endpoint" >&2
            docker logs "$container" >&2
            exit 1
        fi
        sleep 1
    done
    echo "$service: HTTP 200 at $endpoint; non-root, read-only, no capabilities"
done
