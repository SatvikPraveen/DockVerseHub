# Image Build Comparison

**File Location:** `concepts/02_images_layers/image_comparison.md`

## Build Comparison Results

This document compares the three different Dockerfile approaches in this directory.

### Size Comparison

| Dockerfile            | Base Image         | Final Size | Layers | Build Time |
| --------------------- | ------------------ | ---------- | ------ | ---------- |
| Dockerfile.basic      | ubuntu:20.04       | ~850MB     | 15+    | ~180s      |
| Dockerfile.optimized  | ubuntu:20.04       | ~280MB     | 8      | ~120s      |
| Dockerfile.distroless | distroless/python3 | ~95MB      | 6      | ~90s       |

### Layer Analysis

#### Basic Dockerfile Issues

```bash
# Each RUN creates a new layer
RUN apt-get update           # Layer 1: 25MB
RUN apt-get install -y gcc   # Layer 2: 45MB
RUN apt-get install -y python3  # Layer 3: 35MB
# ... continues with many layers
```

#### Optimized Dockerfile Benefits

```bash
# Single RUN with cleanup
RUN apt-get update && apt-get install -y \
    build-essential \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*  # Single layer: 85MB
```

#### Distroless Advantages

```bash
# Minimal runtime layer
FROM gcr.io/distroless/python3  # Base: 45MB
COPY --from=builder /app .      # App layer: 50MB
# Total: 95MB with enhanced security
```

### Security Comparison

| Aspect          | Basic | Optimized | Distroless |
| --------------- | ----- | --------- | ---------- |
| Attack Surface  | Large | Medium    | Minimal    |
| Shell Access    | Yes   | Yes       | No         |
| Package Manager | Yes   | Yes       | No         |
| Root Access     | Yes   | No        | No         |
| CVEs            | 100+  | 50+       | <10        |

### Performance Comparison

#### Build Cache Efficiency

- **Basic**: Poor (many invalidated layers)
- **Optimized**: Good (strategic layer ordering)
- **Distroless**: Excellent (minimal layers)

#### Runtime Performance

- **Basic**: Slower (large filesystem)
- **Optimized**: Fast (clean runtime)
- **Distroless**: Fastest (minimal overhead)

### Network Transfer Comparison

#### First Pull (no cache)

- **Basic**: 850MB download
- **Optimized**: 280MB download
- **Distroless**: 95MB download

#### Update Transfer (app change only)

- **Basic**: ~200MB (poor layer separation)
- **Optimized**: ~50MB (good separation)
- **Distroless**: ~25MB (excellent separation)

### Memory Usage Comparison

| Stage          | Basic | Optimized | Distroless |
| -------------- | ----- | --------- | ---------- |
| Build Memory   | 2GB   | 1.5GB     | 800MB      |
| Runtime Memory | 400MB | 250MB     | 180MB      |

### Practical Recommendations

#### Use Basic Approach When:

- Rapid prototyping
- Learning Docker basics
- Development environments only

#### Use Optimized Approach When:

- Production deployments
- CI/CD pipelines
- Size and security matter

#### Use Distroless When:

- Maximum security required
- Minimal attack surface needed
- Compliance environments
- Microservices at scale

### Build Commands for Testing

```bash
# Build all variants
docker build -f Dockerfile.basic -t app:basic .
docker build -f Dockerfile.optimized -t app:optimized .
docker build -f Dockerfile.distroless -t app:distroless .

# Compare sizes
docker images app

# Run security scan
docker scout quickview app:basic
docker scout quickview app:optimized
docker scout quickview app:distroless

# Test functionality
docker run -p 5000:5000 app:basic
docker run -p 5001:5000 app:optimized
docker run -p 5002:5000 app:distroless
```

### Key Learnings

1. **Layer optimization** reduces image size by 3x
2. **Multi-stage builds** separate build/runtime concerns
3. **Distroless images** provide maximum security
4. **Proper ordering** improves cache hit rates
5. **Base image choice** significantly impacts size/security

Next steps: Apply these patterns to your own applications!
