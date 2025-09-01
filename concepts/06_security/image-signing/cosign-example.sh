#!/bin/bash
# File Location: concepts/06_security/image-signing/cosign-example.sh

set -e

echo "Cosign Image Signing Demo"
echo "========================="

# Generate key pair
echo "1. Generating cosign key pair..."
cosign generate-key-pair

echo -e "\n2. Building image to sign..."
docker build -t myrepo/cosign-demo:v1.0 .

echo -e "\n3. Signing image with cosign..."
cosign sign --key cosign.key myrepo/cosign-demo:v1.0

echo -e "\n4. Verifying signed image..."
cosign verify --key cosign.pub myrepo/cosign-demo:v1.0

echo -e "\n5. Adding attestation..."
cosign attest --key cosign.key --predicate attestation.json myrepo/cosign-demo:v1.0

echo -e "\nCosign signing completed!"