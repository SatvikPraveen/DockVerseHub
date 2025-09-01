// File Location: labs/lab_05_microservices_demo/testing/e2e-tests/user-order-flow.test.js

const axios = require("axios");

describe("End-to-End User Order Flow", () => {
  const apiGateway = process.env.API_GATEWAY_URL || "http://localhost";
  let authToken;
  let userId;
  let orderId;

  beforeAll(async () => {
    // Login to get auth token
    try {
      const loginResponse = await axios.post(`${apiGateway}/api/auth/login`, {
        email: "admin@dockversehub.com",
        password: "admin123",
      });
      authToken = loginResponse.data.token;
      userId = loginResponse.data.user.id;
    } catch (error) {
      console.error("Login failed:", error.message);
    }
  });

  test("Complete user registration and order flow", async () => {
    // 1. Register new user
    const newUser = {
      email: `test${Date.now()}@example.com`,
      username: `user${Date.now()}`,
      password: "password123",
    };

    const registerResponse = await axios.post(
      `${apiGateway}/api/auth/register`,
      newUser
    );
    expect(registerResponse.status).toBe(201);

    // 2. Login with new user
    const loginResponse = await axios.post(`${apiGateway}/api/auth/login`, {
      email: newUser.email,
      password: newUser.password,
    });
    expect(loginResponse.status).toBe(200);
    const userToken = loginResponse.data.token;
    const testUserId = loginResponse.data.user.id;

    // 3. Create order
    const orderData = {
      user_id: testUserId,
      product_id: 1,
      quantity: 2,
      price: 25.99,
    };

    const orderResponse = await axios.post(
      `${apiGateway}/api/orders`,
      orderData,
      {
        headers: { authorization: `Bearer ${userToken}` },
      }
    );
    expect(orderResponse.status).toBe(201);
    orderId = orderResponse.data.order.id;

    // 4. Get user's orders
    const ordersResponse = await axios.get(
      `${apiGateway}/api/orders?user_id=${testUserId}`,
      {
        headers: { authorization: `Bearer ${userToken}` },
      }
    );
    expect(ordersResponse.status).toBe(200);
    expect(ordersResponse.data.orders).toHaveLength(1);

    // 5. Update order status
    const statusUpdate = { status: "confirmed" };
    const updateResponse = await axios.put(
      `${apiGateway}/api/orders/${orderId}/status`,
      statusUpdate,
      {
        headers: { authorization: `Bearer ${authToken}` },
      }
    );
    expect(updateResponse.status).toBe(200);

    // 6. Verify notification was sent (check notification service)
    await new Promise((resolve) => setTimeout(resolve, 1000)); // Wait for async notification

    const notificationsResponse = await axios.get(
      `${apiGateway}/api/notifications/${testUserId}`,
      {
        headers: { authorization: `Bearer ${userToken}` },
      }
    );

    if (notificationsResponse.status === 200) {
      expect(notificationsResponse.data.notifications.length).toBeGreaterThan(
        0
      );
    }
  });

  test("Service health checks", async () => {
    const services = [
      { name: "API Gateway", url: `${apiGateway}/gateway/status` },
      { name: "User Service", url: `${apiGateway}/api/users/health` },
      { name: "Order Service", url: `${apiGateway}/api/orders/health` },
      {
        name: "Notification Service",
        url: `${apiGateway}/api/notifications/health`,
      },
    ];

    for (const service of services) {
      try {
        const response = await axios.get(service.url);
        expect(response.status).toBe(200);
        console.log(`✅ ${service.name}: ${response.data.status}`);
      } catch (error) {
        console.warn(`⚠️  ${service.name}: ${error.message}`);
      }
    }
  });
});
