# ── Stage 1: build ──────────────────────────────────────────────────────────
FROM golang:1.24-alpine AS builder

# ca-certificates needed so the final scratch image can make TLS calls
RUN apk add --no-cache ca-certificates git

WORKDIR /build

COPY go.mod ./
RUN go mod download

COPY . .

ARG VERSION=dev
ARG BUILD_TIME=unknown

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-X main.version=${VERSION} -X main.buildTime=${BUILD_TIME} -w -s" \
    -trimpath \
    -o charis-api .

# ── Stage 2: final image ─────────────────────────────────────────────────────
# scratch = zero OS, ~6 MB total image. No shell = smaller attack surface.
FROM scratch

COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /build/charis-api /charis-api

EXPOSE 8080

# Run as non-root UID 65534 (nobody) — no shell needed with scratch base
USER 65534

ENTRYPOINT ["/charis-api"]
