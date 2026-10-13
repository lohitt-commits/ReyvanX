# syntax=docker/dockerfile:1
FROM --platform=$BUILDPLATFORM golang:1.26.7-bookworm@sha256:e8c859f5632dcfde7b32d2012b4351728f6437930887c2f6a91ea242459e5514 AS builder
WORKDIR /src
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod go mod download
COPY . .
ARG TARGETOS
ARG TARGETARCH
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH \
    go build -p 2 -trimpath -ldflags="-s -w" -o /out/netbird-signal ./signal
RUN mkdir -p /out/data && chown 65532:65532 /out/data

FROM gcr.io/distroless/static-debian12:nonroot@sha256:afa5c872c891853ca7fcf1f12c3edb23f7eeef36189728842dd51042ff57f7ab AS runtime
ARG VERSION=development
ARG REVISION=unknown
LABEL org.opencontainers.image.title="ReyvanX Signal" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${REVISION}"
COPY --from=builder /out/netbird-signal /go/bin/netbird-signal
COPY --from=builder --chown=65532:65532 /out/data /var/lib/netbird
USER 65532:65532
WORKDIR /var/lib/netbird
EXPOSE 8080 9090
ENTRYPOINT ["/go/bin/netbird-signal", "run"]
CMD ["--log-file", "console", "--port", "8080"]
