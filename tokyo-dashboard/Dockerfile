# Multi-stage build for Tokyo Dashboard Service
FROM golang:1.18-alpine AS builder

WORKDIR /app
RUN apk add --no-cache git
RUN go install github.com/GeertJohan/go.rice/rice@latest

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN rice embed-go
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o dashboard-service .

# Production runtime container
FROM alpine:3.18
RUN apk --no-cache add ca-certificates tzdata

WORKDIR /app
COPY --from=builder /app/dashboard-service /app/dashboard-service
COPY --from=builder /app/assets /app/assets

ENV PORT=80
ENV COUNTING_SERVICE_URL="http://localhost:9001"
EXPOSE 80

CMD ["/app/dashboard-service"]
