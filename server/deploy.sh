#!/bin/bash
# GB Messenger Deployment Script (No domain needed)
# For closed messenger (family/relatives)

set -e

echo "GB Messenger Deployment"
echo "======================="

# Check if .env exists
if [ ! -f .env ]; then
    echo "Creating .env from template..."
    cp .env.example .env
    echo "Please edit .env and set SERVER_IP to your server IP"
    echo "Then run this script again"
    exit 0
fi

# Generate all secrets automatically
echo "Generating secrets..."

generate_secret() {
    openssl rand -hex 32
}

# Update secrets if they contain 'change_me'
if grep -q "change_me" .env; then
    sed -i "s/change_me_in_production/$(generate_secret)/g" .env
    sed -i "s/change_me_too/$(generate_secret)/g" .env
    sed -i "s/change_me_minio/$(openssl rand -hex 16)/g" .env
    sed -i "s/change_me_jwt_access/$(generate_secret)/g" .env
    sed -i "s/change_me_jwt_refresh/$(generate_secret)/g" .env
    sed -i "s/change_me_encryption/$(generate_secret)/g" .env
    echo "Secrets generated!"
fi

# Load environment variables
export $(grep -v '^#' .env | xargs)

# Check SERVER_IP is set
if [ -z "$SERVER_IP" ] || [ "$SERVER_IP" = "YOUR_SERVER_IP_HERE" ]; then
    echo "ERROR: Please set SERVER_IP in .env to your server IP address"
    echo "Example: SERVER_IP=123.45.67.89"
    exit 1
fi

# Build and start services
echo "Building and starting services..."
docker-compose build --no-cache
docker-compose up -d

# Wait for services to be healthy
echo "Waiting for services to start..."
sleep 15

# Check service status
echo ""
echo "Service Status:"
docker-compose ps

echo ""
echo "======================="
echo "Deployment complete!"
echo "======================="
echo ""
echo "Your messenger is available at:"
echo "  API:    http://${SERVER_IP}:3000/api"
echo "  MinIO:  http://${SERVER_IP}:9000"
echo ""
echo "Configure your mobile app:"
echo "  API_BASE=http://${SERVER_IP}:3000/api"
echo ""
echo "Useful commands:"
echo "  View logs:    docker-compose logs -f"
echo "  Stop:         docker-compose down"
echo "  Restart:      docker-compose restart"
echo "  Shell:        docker-compose exec app sh"
