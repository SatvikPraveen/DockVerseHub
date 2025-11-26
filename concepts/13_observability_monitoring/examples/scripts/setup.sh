#!/bin/bash
# Setup script - Initialize observability stack

set -e

echo "🔧 Setting up observability stack..."

# Check prerequisites
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is required but not installed"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is required but not installed"
    exit 1
fi

# Create directories
echo "📁 Creating directories..."
mkdir -p prometheus grafana jaeger

# Start services
echo "🚀 Starting services..."
docker-compose up -d

echo ""
echo "✅ Observability stack is up!"
echo ""
echo "📊 Access Points:"
echo "   - Application: http://localhost:5000"
echo "   - Prometheus: http://localhost:9090"
echo "   - Grafana: http://localhost:3000 (admin/admin)"
echo "   - Jaeger: http://localhost:16686"
echo ""
echo "⏳ Waiting for services to be ready (10s)..."
sleep 10

# Test connectivity
echo ""
echo "🧪 Testing connectivity..."

if curl -s http://localhost:5000/health > /dev/null; then
    echo "✅ Application is ready"
else
    echo "⚠️  Application not ready yet"
fi

if curl -s http://localhost:9090/-/healthy > /dev/null; then
    echo "✅ Prometheus is ready"
else
    echo "⚠️  Prometheus not ready yet"
fi

if curl -s http://localhost:3000/api/health > /dev/null; then
    echo "✅ Grafana is ready"
else
    echo "⚠️  Grafana not ready yet"
fi

if curl -s http://localhost:16686/api/services > /dev/null; then
    echo "✅ Jaeger is ready"
else
    echo "⚠️  Jaeger not ready yet"
fi

echo ""
echo "🎯 Next steps:"
echo "   1. Run demo: bash scripts/demo.sh"
echo "   2. View traces: http://localhost:16686"
echo "   3. Check metrics: http://localhost:9090"
echo "   4. View dashboards: http://localhost:3000"
