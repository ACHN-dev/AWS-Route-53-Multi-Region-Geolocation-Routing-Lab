#!/usr/bin/env bash
set -e

# ==============================================================================
# Script to Build and Push Tokyo, London & Counting Images to DockerHub
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "========================================================"
echo "  Consul Multi-Region (Dashboard & Counting) Builder   "
echo "========================================================"

# Check if Docker is installed
if ! command -v docker >/dev/null 2>&1; then
    echo "❌ Error: docker is not installed or not in PATH."
    exit 1
fi

# Get DockerHub Username
DOCKER_USER="${1}"
if [ -z "$DOCKER_USER" ]; then
    read -r -p "👉 Enter your DockerHub username: " DOCKER_USER
fi

if [ -z "$DOCKER_USER" ]; then
    echo "❌ Error: DockerHub username cannot be empty."
    exit 1
fi

echo ""
echo "ℹ️ Using DockerHub username: $DOCKER_USER"
echo ""

# Check Docker login
echo "🔍 Checking DockerHub login status..."
if ! docker login; then
    echo "❌ Docker login failed. Please check your credentials."
    exit 1
fi

echo ""
echo "--------------------------------------------------------"
echo "1️⃣  Building Tokyo Dashboard Image (Green / Asia)..."
echo "--------------------------------------------------------"
docker build --platform linux/amd64 \
    -t "${DOCKER_USER}/dashboard:tokyo" \
    ./tokyo-dashboard

echo ""
echo "--------------------------------------------------------"
echo "2️⃣  Building London Dashboard Image (Blue / Europe)..."
echo "--------------------------------------------------------"
docker build --platform linux/amd64 \
    -t "${DOCKER_USER}/dashboard:london" \
    ./london-dashboard

echo ""
echo "--------------------------------------------------------"
echo "3️⃣  Building Backend Counting Service Image..."
echo "--------------------------------------------------------"
docker build --platform linux/amd64 \
    -t "${DOCKER_USER}/counting-service:latest" \
    ./counting-service

echo ""
echo "--------------------------------------------------------"
echo "4️⃣  Pushing All Images to DockerHub..."
echo "--------------------------------------------------------"
echo "⬆️ Pushing ${DOCKER_USER}/dashboard:tokyo..."
docker push "${DOCKER_USER}/dashboard:tokyo"

echo "⬆️ Pushing ${DOCKER_USER}/dashboard:london..."
docker push "${DOCKER_USER}/dashboard:london"

echo "⬆️ Pushing ${DOCKER_USER}/counting-service:latest..."
docker push "${DOCKER_USER}/counting-service:latest"

echo ""
echo "========================================================"
echo "🎉 SUCCESS! All images pushed to DockerHub successfully:"
echo "   - ${DOCKER_USER}/dashboard:tokyo"
echo "   - ${DOCKER_USER}/dashboard:london"
echo "   - ${DOCKER_USER}/counting-service:latest"
echo "========================================================"
echo ""
echo "👉 EC2 User Data commands to use in AWS:"
echo ""
echo "For Tokyo EC2 (ap-northeast-1):"
echo "----------------------------------------"
echo "docker run -d --restart always --name counting -p 9001:9001 -e PORT=9001 ${DOCKER_USER}/counting-service:latest"
echo "docker run -d --restart always --name dashboard -p 80:80 -e PORT=80 -e COUNTING_SERVICE_URL=http://localhost:9001 ${DOCKER_USER}/dashboard:tokyo"
echo ""
echo "For London EC2 (eu-west-2):"
echo "----------------------------------------"
echo "docker run -d --restart always --name counting -p 9001:9001 -e PORT=9001 ${DOCKER_USER}/counting-service:latest"
echo "docker run -d --restart always --name dashboard -p 80:80 -e PORT=80 -e COUNTING_SERVICE_URL=http://localhost:9001 ${DOCKER_USER}/dashboard:london"
echo "========================================================"
