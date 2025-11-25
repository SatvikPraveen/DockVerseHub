# File Location: labs/lab_05_microservices_demo/order-service/Dockerfile

FROM golang:1.21-alpine AS builder

# Install git and ca-certificates
RUN apk add --no-cache git ca-certificates tzdata

WORKDIR /app

# Copy source code first
COPY . .

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main ./app.go

# Development stage
FROM alpine:3.18 AS development

RUN apk --no-cache add ca-certificates wget curl

WORKDIR /root/

# Copy the binary from builder
COPY --from=builder /app/main .
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost:8080/health || exit 1

EXPOSE 8080

CMD ["./main"]

# Production stage
FROM scratch AS production

# Copy ca-certificates and timezone data
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

# Copy the binary
COPY --from=builder /app/main /main

# Labels
LABEL maintainer="DockVerseHub" \
      version="1.0" \
      description="Order service for microservices demo"

EXPOSE 8080

ENTRYPOINT ["/main"]