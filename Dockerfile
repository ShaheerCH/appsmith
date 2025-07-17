# Start from Ubuntu 22.04
FROM ubuntu:22.04

# Set environment variable to indicate running inside Docker
ENV IN_DOCKER=1

# Install OS and build dependencies (Java 17, Maven, etc.)
RUN apt-get update && \
    apt-get install -y \
    git \
    curl \
    openjdk-17-jdk \
    maven \
    docker.io \
    unzip \
    supervisor \
    ca-certificates \
    gnupg \
    lsb-release && \
    curl -fsSL https://deb.nodesource.com/setup_16.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g yarn@1.22.19 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Node.js 16.x (required)
RUN curl -fsSL https://deb.nodesource.com/setup_16.x | bash - && \
    apt-get install -y nodejs

# Install Yarn v1 (not v3+)
RUN npm install -g yarn@1.22.19

# Set working directory
WORKDIR /opt/appsmith

# Copy Appsmith source code
COPY . .

# Build backend with Maven (skip tests for faster build)
RUN cd app/server && ./build.sh -DskipTests=true

# Build frontend (React)
RUN cd app/client && yarn install && yarn build

# Build RTS (Real-Time Server)
RUN cd app/client/packages/rts && yarn install && yarn build

# Copy built frontend and RTS into proper locations
RUN mkdir -p /opt/appsmith/editor /opt/appsmith/rts && \
    cp -r app/client/build/* /opt/appsmith/editor/ && \
    cp -r app/client/packages/rts/dist/* /opt/appsmith/rts/

# Copy Docker-specific files (startup scripts, configs, etc.)
COPY deploy/docker/fs/ /

# Fix PATH for supervisor and runtime
ENV PATH="/opt/bin:/opt/java/bin:/opt/node/bin:$PATH"

# Make all .sh scripts executable
RUN find . -type f -name "*.sh" -exec chmod +x {} \; && \
    chmod +x /opt/bin/* /watchtower-hooks/*.sh

# Create necessary directories and fix permissions
RUN mkdir -p /.mongodb/mongosh /appsmith-stacks && \
    chmod ugo+w /etc /appsmith-stacks && \
    chmod -R ugo+w /var/run /.mongodb /etc/ssl /usr/local/share

# Expose required ports
EXPOSE 80
EXPOSE 443

# Define health check
HEALTHCHECK --interval=15s --timeout=15s --start-period=45s CMD ["/opt/appsmith/healthcheck.sh"]

# Set entrypoint and command
ENTRYPOINT ["/opt/appsmith/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-n"]
