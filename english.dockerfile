# Initial stage
FROM python:3.11 as translator
WORKDIR /app
COPY . .
RUN python ./i18n/translate.py --repository_path . --json_file_path ./i18n/en.json

# Node build stage
FROM node:18 as builder
WORKDIR /build
COPY ./web/package*.json ./
RUN npm ci
COPY --from=translator /app .
RUN REACT_APP_VERSION=$(cat VERSION) npm run build

# Go build stage
FROM golang AS builder2
ENV GO111MODULE=on \
    CGO_ENABLED=1 \
    GOOS=linux
WORKDIR /build
COPY go.mod .
COPY go.sum .
RUN go mod download
COPY --from=translator /app .
COPY --from=builder /build/build ./web/build
RUN go build -ldflags "-s -w -X 'one-api/common.Version=$(cat VERSION)' -extldflags '-static'" -o one-api

# Final stage
FROM alpine
RUN apk update && apk upgrade && apk add --no-cache ca-certificates tzdata && update-ca-certificates 2>/dev/null || true
WORKDIR /data
COPY --from=builder2 /build/one-api /
EXPOSE 3000
ENTRYPOINT ["/one-api"]
