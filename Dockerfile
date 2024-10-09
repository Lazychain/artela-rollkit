# detailed messages: docker compose build --progress=plain --no-cache
LABEL org.opencontainers.image.source=https://github.com/Lazychain/artela-rollkit
LABEL org.opencontainers.image.description="Lazy Chain rollkit with artela"

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

# Install Rollkit
RUN (curl -sSL https://rollkit.dev/install.sh | sh -s ${ROLLKIT_VERSION})

# Install ignite
RUN (curl https://get.ignite.com/cli@${IGNITE_VERSION}! | bash)

# Set the working directory
WORKDIR /app

# cache dependencies.
COPY ./go.mod . 
COPY ./go.sum . 
RUN go mod download

# Copy all files from the current directory to the container
COPY . .

# Build the chain
RUN ignite chain build 

# This is broken but we expect to be fix it soon.
# instead we use lazy_init.sh before to generate the blockchain configuration.
# RUN ignite rollkit init

# Initialize the Rollkit configuration
RUN rollkit toml init

# Copy chain configuration 
COPY ./.lazy /root/.artroll

# Edit rollkit.toml config_dir
RUN sed -i 's/config_dir = "artroll"/config_dir = "\/root\/\.artroll"/g' rollkit.toml

# Run rollkit command to initialize the entrypoint executable
RUN rollkit

RUN ls -l /app/entrypoint

# Stage 2: Set up the runtime environment
FROM debian:bookworm-slim

# Set the working directory
WORKDIR /root

# Copy over the rollkit binary from the build stage
COPY --from=base /go/bin/rollkit /usr/bin

# Copy the entrypoint and rollkit.toml files from the build stage
COPY --from=base /app/entrypoint ./entrypoint
COPY --from=base /app/rollkit.toml ./rollkit.toml

# Copy the $HOME/.artroll directory from the build stage.
# This directory contains all your chain config.
COPY --from=base /app/.lazy /root/.artroll

# Ensure the entrypoint script is executable
RUN chmod +x ./entrypoint

# Keep the container running after it has been started
CMD tail -f /dev/null
