# Start from Ubuntu 22.04
FROM ubuntu:22.04

# Set environment variable to indicate running inside Docker
ENV IN_DOCKER=1

# Install necessary packages
RUN apt-get update && \
    apt-get install -y \
    git \
    curl \
    openjdk-11-jdk \
    maven \
    nodejs \
    npm \
    yarn \
    unzip \
    ca-certificates \
    gnupg \
    lsb-release \
    supervisor && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /opt/appsmith

# Copy the entire Appsmith source code into the container
COPY . .

# Install backend dependencies and build the server
RUN cd app/server && \
    ./build.sh -DskipTests=true

# Install frontend dependencies and build the client
RUN cd app/client && \
    yarn install && \
    yarn build

# Build the Real-Time Server (RTS)
RUN cd app/client/packages/rts && \
    yarn install && \
    yarn build

# Copy built frontend and RTS into appropriate directories
RUN mkdir -p /opt/appsmith/editor /opt/appsmith/rts && \
    cp -r app/client/build/* /opt/appsmith/editor/ && \
    cp -r app/client/packages/rts/dist/* /opt/appsmith/rts/

# Copy Docker-specific files
COPY deploy/docker/fs/ /

# Set PATH environment variable
ENV PATH="/opt/bin:/opt/java/bin:/opt/node/bin:$PATH"

# Make shell scripts executable
RUN find . -type f -name "*.sh" -exec chmod +x {} \; && \
    chmod +x /opt/bin/* /watchtower-hooks/*.sh

# Create necessary directories and set permissions
RUN mkdir -p /.mongodb/mongosh /appsmith-stacks && \
    chmod ugo+w /etc /appsmith-stacks && \
    chmod -R ugo+w /var/run /.mongodb /etc/ssl /usr/local/share

# Expose necessary ports
EXPOSE 80
EXPOSE 443

# Define healthcheck
HEALTHCHECK --interval=15s --timeout=15s --start-period=45s CMD ["/opt/appsmith/healthcheck.sh"]

# Set entrypoint and default command
ENTRYPOINT ["/opt/appsmith/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-n"]
