// File Location: labs/lab_05_microservices_demo/testing/contract-tests/user-service.test.js

const axios = require("axios");

describe("User Service Contract Tests", () => {
  const baseURL = process.env.USER_SERVICE_URL || "http://localhost:5000";

  test("Health endpoint returns correct structure", async () => {
    const response = await axios.get(`${baseURL}/health`);

    expect(response.status).toBe(200);
    expect(response.data).toHaveProperty("status");
    expect(response.data).toHaveProperty("service", "user-service");
    expect(response.data).toHaveProperty("version");
    expect(response.data).toHaveProperty("dependencies");
  });

  test("User registration endpoint accepts correct format", async () => {
    const userData = {
      email: "test@example.com",
      username: "testuser",
      password: "password123",
    };

    try {
      const response = await axios.post(
        `${baseURL}/api/auth/register`,
        userData
      );
      expect(response.status).toBe(201);
      expect(response.data).toHaveProperty("message");
      expect(response.data).toHaveProperty("user_id");
    } catch (error) {
      // User might already exist
      expect(error.response.status).toBe(409);
    }
  });

  test("Login endpoint returns JWT token", async () => {
    const loginData = {
      email: "admin@dockversehub.com",
      password: "admin123",
    };

    const response = await axios.post(`${baseURL}/api/auth/login`, loginData);

    if (response.status === 200) {
      expect(response.data).toHaveProperty("token");
      expect(response.data).toHaveProperty("user");
      expect(response.data.user).toHaveProperty("email");
      expect(response.data.user).toHaveProperty("role");
    }
  });
});
