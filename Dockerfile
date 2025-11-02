# ==================================
# Pipster Identity Server - Multi-Configuration Dockerfile
# Supports both Debug (for VS debugging) and Release (for production)
# ==================================

# Stage 1: Build & Publish
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
ARG BUILD_CONFIGURATION=Release

WORKDIR /src

# Copy project file and restore (cached layer for faster rebuilds)
COPY ["pipster.identity.csproj", "./"]
RUN dotnet restore "pipster.identity.csproj"

# Copy source code
COPY . .

# Build and publish
RUN dotnet publish "pipster.identity.csproj" \
    -c $BUILD_CONFIGURATION \
    -o /app/publish \
    --no-restore \
    /p:UseAppHost=false

# Stage 2: Runtime
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS runtime

# Install wget for healthcheck
RUN apt-get update && \
    apt-get install -y wget && \
    rm -rf /var/lib/apt/lists/*

# Install debugger for Visual Studio remote debugging (only adds ~10MB)
# This allows VS to attach to the container
RUN apt-get update && \
    apt-get install -y curl unzip && \
    curl -sSL https://aka.ms/getvsdbgsh | bash /dev/stdin -v latest -l /vsdbg && \
    rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy published application from build stage
COPY --from=build /app/publish .

# Expose HTTP port (HTTPS handled by reverse proxy)
EXPOSE 80

# Environment variables
ENV ASPNETCORE_URLS=http://+:80 \
    DOTNET_RUNNING_IN_CONTAINER=true \
    ASPNETCORE_HTTP_PORTS=80

# Entry point
ENTRYPOINT ["dotnet", "pipster.identity.dll"]