# Multi-stage build for Counting Service
FROM golang:1.18-alpine AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o counting-service .

# Production runtime container
FROM alpine:3.18
RUN apk --no-cache add ca-certificates

WORKDIR /app
COPY --from=builder /app/counting-service /app/counting-service

ENV PORT=9001
EXPOSE 9001

CMD ["/app/counting-service"]
