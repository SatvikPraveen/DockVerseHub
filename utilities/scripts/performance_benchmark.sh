#!/bin/bash
# Location: utilities/scripts/performance_benchmark.sh
# Docker container performance benchmarking script

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

BENCHMARK_DURATION=60
RESULTS_DIR="benchmark_results"
TEST_IMAGE="alpine:latest"

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

mkdir -p "$RESULTS_DIR"

# Container startup time benchmark
benchmark_startup_time() {
    local image="$1"
    local iterations=10
    local total_time=0
    
    print_status "Benchmarking startup time for $image..."
    
    for i in $(seq 1 $iterations); do
        local start_time=$(date +%s%3N)
        local container_id=$(docker run -d "$image" sleep 1)
        docker wait "$container_id" > /dev/null
        local end_time=$(date +%s%3N)
        
        local startup_time=$((end_time - start_time))
        total_time=$((total_time + startup_time))
        
        docker rm "$container_id" > /dev/null
        echo "Iteration $i: ${startup_time}ms"
    done
    
    local avg_time=$((total_time / iterations))
    echo "Average startup time: ${avg_time}ms" | tee "$RESULTS_DIR/startup_${image//[\/:]/_}.txt"
}

# Memory usage benchmark
benchmark_memory_usage() {
    local image="$1"
    local duration=30
    
    print_status "Benchmarking memory usage for $image..."
    
    local container_id=$(docker run -d "$image" sleep "$duration")
    local results_file="$RESULTS_DIR/memory_${image//[\/:]/_}.csv"
    
    echo "timestamp,memory_usage_mb,memory_percent" > "$results_file"
    
    for i in $(seq 1 "$duration"); do
        local stats=$(docker stats --no-stream --format "{{.MemUsage}},{{.MemPerc}}" "$container_id")
        local memory_mb=$(echo "$stats" | cut -d',' -f1 | sed 's/MiB.*//' | sed 's/.* //')
        local memory_percent=$(echo "$stats" | cut -d',' -f2 | sed 's/%//')
        
        echo "$(date +%s),$memory_mb,$memory_percent" >> "$results_file"
        sleep 1
    done
    
    docker stop "$container_id" > /dev/null
    docker rm "$container_id" > /dev/null
    
    print_success "Memory benchmark completed: $results_file"
}

# CPU usage benchmark
benchmark_cpu_usage() {
    local image="$1"
    local duration=30
    
    print_status "Benchmarking CPU usage for $image..."
    
    local container_id=$(docker run -d "$image" sh -c "while true; do echo test > /dev/null; done")
    local results_file="$RESULTS_DIR/cpu_${image//[\/:]/_}.csv"
    
    echo "timestamp,cpu_percent" > "$results_file"
    
    for i in $(seq 1 "$duration"); do
        local cpu_percent=$(docker stats --no-stream --format "{{.CPUPerc}}" "$container_id" | sed 's/%//')
        echo "$(date +%s),$cpu_percent" >> "$results_file"
        sleep 1
    done
    
    docker stop "$container_id" > /dev/null
    docker rm "$container_id" > /dev/null
    
    print_success "CPU benchmark completed: $results_file"
}

# I/O performance benchmark
benchmark_io_performance() {
    local image="$1"
    
    print_status "Benchmarking I/O performance for $image..."
    
    local results_file="$RESULTS_DIR/io_${image//[\/:]/_}.txt"
    
    # Write performance test
    local write_time=$(docker run --rm "$image" sh -c "time dd if=/dev/zero of=/tmp/testfile bs=1M count=100 2>&1" | grep real | awk '{print $2}')
    echo "Write test (100MB): $write_time" > "$results_file"
    
    # Read performance test  
    local read_time=$(docker run --rm "$image" sh -c "dd if=/dev/zero of=/tmp/testfile bs=1M count=100 &>/dev/null; time dd if=/tmp/testfile of=/dev/null bs=1M 2>&1" | grep real | awk '{print $2}')
    echo "Read test (100MB): $read_time" >> "$results_file"
    
    print_success "I/O benchmark completed: $results_file"
}

# Network performance benchmark
benchmark_network_performance() {
    local image="$1"
    
    print_status "Benchmarking network performance for $image..."
    
    # Create a simple HTTP server container
    local server_id=$(docker run -d -p 8080:8080 "$image" sh -c "while true; do echo 'HTTP/1.1 200 OK\r\n\r\nHello World' | nc -l -p 8080; done")
    
    sleep 2  # Wait for server to start
    
    # Test with wget
    local results_file="$RESULTS_DIR/network_${image//[\/:]/_}.txt"
    
    for i in {1..10}; do
        local response_time=$(curl -o /dev/null -s -w '%{time_total}' http://localhost:8080)
        echo "Request $i: ${response_time}s" >> "$results_file"
    done
    
    docker stop "$server_id" > /dev/null
    docker rm "$server_id" > /dev/null
    
    print_success "Network benchmark completed: $results_file"
}

# Image size comparison
compare_image_sizes() {
    local images=("$@")
    local results_file="$RESULTS_DIR/image_sizes.csv"
    
    print_status "Comparing image sizes..."
    
    echo "image,size_mb" > "$results_file"
    
    for image in "${images[@]}"; do
        local size=$(docker images --format "{{.Size}}" "$image" | head -1)
        local size_mb=$(echo "$size" | sed 's/MB//' | sed 's/GB/*1024/' | bc 2>/dev/null || echo "$size")
        echo "$image,$size_mb" >> "$results_file"
        echo "$image: $size"
    done
    
    print_success "Size comparison completed: $results_file"
}

# Generate HTML report
generate_html_report() {
    local report_file="$RESULTS_DIR/performance_report.html"
    
    print_status "Generating performance report..."
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Docker Performance Benchmark Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .header { background: #f4f4f4; padding: 20px; border-radius: 5px; }
        .metric { background: #e3f2fd; margin: 10px 0; padding: 15px; border-radius: 5px; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .chart { margin: 20px 0; }
    </style>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
</head>
<body>
    <div class="header">
        <h1>Docker Performance Benchmark Report</h1>
        <p>Generated: $(date)</p>
        <p>Test Duration: ${BENCHMARK_DURATION}s</p>
    </div>

    <div class="metric">
        <h2>Test Summary</h2>
        <ul>
            <li>Startup Time Tests: $(ls "$RESULTS_DIR"/startup_* 2>/dev/null | wc -l) images</li>
            <li>Memory Usage Tests: $(ls "$RESULTS_DIR"/memory_* 2>/dev/null | wc -l) images</li>
            <li>CPU Usage Tests: $(ls "$RESULTS_DIR"/cpu_* 2>/dev/null | wc -l) images</li>
            <li>I/O Performance Tests: $(ls "$RESULTS_DIR"/io_* 2>/dev/null | wc -l) images</li>
            <li>Network Tests: $(ls "$RESULTS_DIR"/network_* 2>/dev/null | wc -l) images</li>
        </ul>
    </div>

    <div class="metric">
        <h2>Individual Test Results</h2>
        <p>Detailed results are available in the following files:</p>
        <ul>
EOF

    for result_file in "$RESULTS_DIR"/*.txt "$RESULTS_DIR"/*.csv; do
        if [ -f "$result_file" ]; then
            echo "            <li><a href=\"$(basename "$result_file")\">$(basename "$result_file")</a></li>" >> "$report_file"
        fi
    done

    cat >> "$report_file" << EOF
        </ul>
    </div>

    <div class="metric">
        <h2>Performance Recommendations</h2>
        <ul>
            <li>Use multi-stage builds to reduce image sizes</li>
            <li>Choose appropriate base images (Alpine for size, Ubuntu for compatibility)</li>
            <li>Implement proper resource limits</li>
            <li>Monitor container performance in production</li>
            <li>Consider using init systems for proper signal handling</li>
        </ul>
    </div>
</body>
</html>
EOF

    print_success "HTML report generated: $report_file"
}

show_help() {
    echo "Docker Performance Benchmark Script"
    echo "Usage: $0 [OPTIONS] [IMAGES...]"
    echo ""
    echo "OPTIONS:"
    echo "  -i, --image IMAGE       Benchmark specific image"
    echo "  -a, --all              Benchmark all local images"
    echo "  -d, --duration SEC     Set benchmark duration (default: 60s)"
    echo "  --startup-only         Run only startup time benchmarks"
    echo "  --memory-only          Run only memory benchmarks"
    echo "  --cpu-only             Run only CPU benchmarks"
    echo "  --io-only              Run only I/O benchmarks"
    echo "  --network-only         Run only network benchmarks"
    echo "  --compare-sizes        Compare image sizes only"
    echo "  -h, --help             Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 -i nginx:latest                   # Benchmark nginx"
    echo "  $0 -a --startup-only                # Startup benchmark for all images"
    echo "  $0 nginx:latest alpine:latest       # Compare two images"
}

# Parse arguments
BENCHMARK_ALL=false
STARTUP_ONLY=false
MEMORY_ONLY=false
CPU_ONLY=false
IO_ONLY=false
NETWORK_ONLY=false
COMPARE_SIZES_ONLY=false
TARGET_IMAGES=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--image)
            TARGET_IMAGES+=("$2")
            shift 2
            ;;
        -a|--all)
            BENCHMARK_ALL=true
            shift
            ;;
        -d|--duration)
            BENCHMARK_DURATION="$2"
            shift 2
            ;;
        --startup-only)
            STARTUP_ONLY=true
            shift
            ;;
        --memory-only)
            MEMORY_ONLY=true
            shift
            ;;
        --cpu-only)
            CPU_ONLY=true
            shift
            ;;
        --io-only)
            IO_ONLY=true
            shift
            ;;
        --network-only)
            NETWORK_ONLY=true
            shift
            ;;
        --compare-sizes)
            COMPARE_SIZES_ONLY=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
        *)
            TARGET_IMAGES+=("$1")
            shift
            ;;
    esac
done

# Get all images if benchmarking all
if [ "$BENCHMARK_ALL" = true ]; then
    while IFS= read -r image; do
        TARGET_IMAGES+=("$image")
    done < <(docker images --format "{{.Repository}}:{{.Tag}}" | grep -v "<none>" | head -5)  # Limit to 5 for demo
fi

# Use default image if none specified
if [ ${#TARGET_IMAGES[@]} -eq 0 ]; then
    TARGET_IMAGES=("$TEST_IMAGE")
    print_warning "No images specified, using default: $TEST_IMAGE"
fi

# Check Docker
if ! docker info &> /dev/null; then
    print_error "Docker is not running"
    exit 1
fi

print_status "Starting Docker performance benchmarks..."

# Run benchmarks based on options
for image in "${TARGET_IMAGES[@]}"; do
    print_status "Benchmarking image: $image"
    
    if [ "$COMPARE_SIZES_ONLY" = true ]; then
        continue  # Skip to size comparison
    elif [ "$STARTUP_ONLY" = true ]; then
        benchmark_startup_time "$image"
    elif [ "$MEMORY_ONLY" = true ]; then
        benchmark_memory_usage "$image"
    elif [ "$CPU_ONLY" = true ]; then
        benchmark_cpu_usage "$image"
    elif [ "$IO_ONLY" = true ]; then
        benchmark_io_performance "$image"
    elif [ "$NETWORK_ONLY" = true ]; then
        benchmark_network_performance "$image"
    else
        # Run all benchmarks
        benchmark_startup_time "$image"
        benchmark_memory_usage "$image"
        benchmark_cpu_usage "$image"
        benchmark_io_performance "$image"
        benchmark_network_performance "$image"
    fi
    echo ""
done

# Compare sizes if requested or if it's the only test
if [ "$COMPARE_SIZES_ONLY" = true ] || [ ${#TARGET_IMAGES[@]} -gt 1 ]; then
    compare_image_sizes "${TARGET_IMAGES[@]}"
fi

# Generate report
generate_html_report

print_success "Benchmarking completed! Results saved to: $RESULTS_DIR/"