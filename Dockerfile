# detailed messages: docker compose build --progress=plain --no-cache

# Stage 1: Install ignite CLI and rollkit
FROM golang:1.22 AS base

ARG ROLLKIT_VERSION="v0.13.7"
ARG IGNITE_VERSION="v28.4.0"

# Install dependencies
RUN apt update && \
	apt-get install -y \
	build-essential \
	ca-certificates \
	curl

# enable faster module downloading.
ENV GOPROXY https://proxy.golang.org

# Set the working directory
WORKDIR /app

# cache dependencies.
COPY ./go.mod . 
COPY ./go.sum . 
RUN go mod download

# Copy all files from the current directory to the container
COPY . .

# Build the chain
RUN go build -x -v -o /go/bin/artrolld ./cmd/artrolld/main.go
RUN chmod +x /go/bin/artrolld

# Stage 2: Set up the runtime environment
FROM debian:bookworm-slim

LABEL org.opencontainers.image.source=https://github.com/Lazychain/artela-rollkit
LABEL org.opencontainers.image.description="Lazy Chain rollkit with artela"

# Install dependencies
RUN apt update && \
	apt-get install -y \
	jq

# Set the working directory
WORKDIR /root

# Copy over the rollkit binary from the build stage
COPY --from=base /go/bin/artrolld /usr/bin

# Copy the entrypoint and rollkit.toml files from the build stage
COPY ./entrypoint.sh /opt/entrypoint.sh
# COPY ./genesis-contract /go/bin/genesis-contract

# Ensure the entrypoint script is executable
RUN chmod +x /opt/entrypoint.sh

ENTRYPOINT [ "/bin/bash", "/opt/entrypoint.sh" ]
