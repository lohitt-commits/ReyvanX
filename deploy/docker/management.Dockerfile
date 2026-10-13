# syntax=docker/dockerfile:1
FROM golang:1.26.7-bookworm@sha256:e8c859f5632dcfde7b32d2012b4351728f6437930887c2f6a91ea242459e5514 AS builder
WORKDIR /src
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod go mod download
COPY . .
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=1 go build -p 2 -trimpath -ldflags="-s -w" -o /out/netbird-mgmt ./management
RUN mkdir -p /out/data /out/config && chown -R 65532:65532 /out/data /out/config

FROM gcr.io/distroless/base-debian12:nonroot@sha256:7f0c72cd138b442ae0deeb69c08b1acf5525439ba251a49ad93c320a061567e5 AS runtime
ARG VERSION=development
ARG REVISION=unknown
LABEL org.opencontainers.image.title="ReyvanX Management" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${REVISION}"
COPY --from=builder /out/netbird-mgmt /go/bin/netbird-mgmt
COPY --from=builder --chown=65532:65532 /out/data /var/lib/netbird
COPY --from=builder --chown=65532:65532 /out/config /etc/netbird
USER 65532:65532
WORKDIR /var/lib/netbird
EXPOSE 8080 9090
ENTRYPOINT ["/go/bin/netbird-mgmt", "management"]
CMD ["--log-file", "console", "--port", "8080"]
