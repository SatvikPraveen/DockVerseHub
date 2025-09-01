// File Location: labs/lab_05_microservices_demo/testing/load-tests/api-gateway.test.js

const autocannon = require("autocannon");

async function runLoadTest() {
  console.log("Starting API Gateway load test...");

  const result = await autocannon({
    url: "http://localhost/health",
    connections: 50,
    duration: 60,
    pipelining: 1,
    headers: {
      "content-type": "application/json",
    },
  });

  console.log("Load test completed:");
  console.log(`Requests: ${result.requests.total}`);
  console.log(`Duration: ${result.duration}ms`);
  console.log(`Throughput: ${result.throughput.average} req/sec`);
  console.log(`Latency: ${result.latency.average}ms avg`);

  // Test user service endpoint
  const userServiceResult = await autocannon({
    url: "http://localhost/api/users/me",
    connections: 10,
    duration: 30,
    headers: {
      authorization: "Bearer test-token",
      "content-type": "application/json",
    },
  });

  console.log("\nUser Service Load Test:");
  console.log(`Requests: ${userServiceResult.requests.total}`);
  console.log(`Throughput: ${userServiceResult.throughput.average} req/sec`);
}

if (require.main === module) {
  runLoadTest().catch(console.error);
}

module.exports = { runLoadTest };
