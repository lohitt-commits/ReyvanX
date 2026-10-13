#!/bin/sh
set -eu

if ! command -v docker >/dev/null 2>&1; then
    PATH="/Applications/Docker.app/Contents/Resources/bin:$PATH"
    export PATH
fi
repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
revision=$(git -C "$repo" rev-parse HEAD)
tag=${IMAGE_TAG:-dev-$(git -C "$repo" rev-parse --short HEAD)}
platforms=${PLATFORMS:-linux/amd64,linux/arm64}

docker info >/dev/null
for service in management signal relay; do
    docker buildx build --platform "$platforms" --load \
        --build-arg "VERSION=$tag" --build-arg "REVISION=$revision" \
        -f "$repo/deploy/docker/$service.Dockerfile" \
        -t "reyvanx/$service:$tag" "$repo"
done
echo "Built Management, Signal, and Relay with tag $tag."
echo "Dashboard is not built: its source is not present in this repository."
