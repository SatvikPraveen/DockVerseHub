// File Location: labs/lab_05_microservices_demo/api-gateway/auth-middleware.js

const jwt = require("jsonwebtoken");
const redis = require("redis");

// Configuration
const JWT_SECRET = process.env.JWT_SECRET || "your-secret-key";
const REDIS_URL = process.env.REDIS_URL || "redis://redis:6379";

// Redis client for token blacklist and rate limiting
const redisClient = redis.createClient({
  url: REDIS_URL,
  retry_strategy: (options) => {
    if (options.error && options.error.code === "ECONNREFUSED") {
      console.error("Redis connection refused");
      return new Error("Redis connection refused");
    }
    if (options.total_retry_time > 1000 * 60 * 60) {
      return new Error("Redis retry time exhausted");
    }
    if (options.attempt > 10) {
      return new Error("Redis retry attempts exhausted");
    }
    return Math.min(options.attempt * 100, 3000);
  },
});

redisClient.on("connect", () => {
  console.log("Connected to Redis for auth middleware");
});

redisClient.on("error", (err) => {
  console.error("Redis error:", err);
});

/**
 * JWT Authentication Middleware
 */
class AuthMiddleware {
  constructor() {
    this.publicPaths = [
      "/health",
      "/gateway/status",
      "/api/auth/login",
      "/api/auth/register",
      "/api/auth/refresh",
      "/metrics",
    ];

    this.adminPaths = ["/admin/", "/api/admin/"];
  }

  /**
   * Check if path requires authentication
   */
  requiresAuth(path) {
    return !this.publicPaths.some((publicPath) => path.startsWith(publicPath));
  }

  /**
   * Check if path requires admin privileges
   */
  requiresAdmin(path) {
    return this.adminPaths.some((adminPath) => path.startsWith(adminPath));
  }

  /**
   * Extract token from Authorization header
   */
  extractToken(authHeader) {
    if (!authHeader) {
      return null;
    }

    const parts = authHeader.split(" ");
    if (parts.length === 2 && parts[0] === "Bearer") {
      return parts[1];
    }

    return null;
  }

  /**
   * Verify JWT token
   */
  async verifyToken(token) {
    try {
      // Check if token is blacklisted
      const isBlacklisted = await redisClient.get(`blacklist:${token}`);
      if (isBlacklisted) {
        throw new Error("Token is blacklisted");
      }

      // Verify token signature and expiration
      const decoded = jwt.verify(token, JWT_SECRET);

      // Check if user is still active
      const userActive = await this.checkUserStatus(decoded.userId);
      if (!userActive) {
        throw new Error("User account is inactive");
      }

      return decoded;
    } catch (error) {
      throw new Error(`Token verification failed: ${error.message}`);
    }
  }

  /**
   * Check user status in Redis cache or database
   */
  async checkUserStatus(userId) {
    try {
      // Try to get user status from cache first
      const cachedStatus = await redisClient.get(`user:${userId}:active`);
      if (cachedStatus !== null) {
        return cachedStatus === "true";
      }

      // In a real implementation, you would check the user database
      // For this demo, we'll assume all users are active
      await redisClient.setex(`user:${userId}:active`, 300, "true");
      return true;
    } catch (error) {
      console.error("Error checking user status:", error);
      return false;
    }
  }

  /**
   * Rate limiting check
   */
  async checkRateLimit(userId, endpoint) {
    try {
      const key = `rate_limit:${userId}:${endpoint}`;
      const current = await redisClient.get(key);

      const limit = this.getRateLimit(endpoint);
      const window = this.getRateWindow(endpoint);

      if (current === null) {
        await redisClient.setex(key, window, 1);
        return { allowed: true, remaining: limit - 1 };
      }

      const count = parseInt(current);
      if (count >= limit) {
        const ttl = await redisClient.ttl(key);
        return {
          allowed: false,
          remaining: 0,
          resetTime: ttl,
        };
      }

      await redisClient.incr(key);
      return { allowed: true, remaining: limit - count - 1 };
    } catch (error) {
      console.error("Rate limiting error:", error);
      // Allow request if Redis is unavailable
      return { allowed: true, remaining: 100 };
    }
  }

  /**
   * Get rate limit for endpoint
   */
  getRateLimit(endpoint) {
    const limits = {
      "/api/auth/": 10,
      "/api/users/": 100,
      "/api/orders/": 50,
      "/api/notifications/": 200,
      default: 1000,
    };

    for (const [path, limit] of Object.entries(limits)) {
      if (endpoint.startsWith(path)) {
        return limit;
      }
    }

    return limits.default;
  }

  /**
   * Get rate limit window (in seconds)
   */
  getRateWindow(endpoint) {
    const windows = {
      "/api/auth/": 900, // 15 minutes
      "/api/users/": 3600, // 1 hour
      "/api/orders/": 3600, // 1 hour
      "/api/notifications/": 3600, // 1 hour
      default: 3600, // 1 hour
    };

    for (const [path, window] of Object.entries(windows)) {
      if (endpoint.startsWith(path)) {
        return window;
      }
    }

    return windows.default;
  }

  /**
   * Log authentication attempt
   */
  async logAuthAttempt(userId, ip, userAgent, success, reason = "") {
    try {
      const logEntry = {
        userId: userId,
        ip: ip,
        userAgent: userAgent,
        success: success,
        reason: reason,
        timestamp: new Date().toISOString(),
      };

      // Store in Redis for audit purposes
      const key = `auth_log:${Date.now()}:${Math.random()}`;
      await redisClient.setex(key, 86400, JSON.stringify(logEntry)); // 24 hours

      console.log("Auth attempt:", logEntry);
    } catch (error) {
      console.error("Error logging auth attempt:", error);
    }
  }

  /**
   * Main authentication middleware function
   */
  async authenticate(request) {
    const { path, headers, ip, method } = request;

    try {
      // Check if path requires authentication
      if (!this.requiresAuth(path)) {
        return {
          success: true,
          user: null,
          headers: {
            "X-Auth-Status": "public",
          },
        };
      }

      // Extract and verify token
      const token = this.extractToken(headers.authorization);
      if (!token) {
        await this.logAuthAttempt(
          null,
          ip,
          headers["user-agent"],
          false,
          "No token provided"
        );
        return {
          success: false,
          statusCode: 401,
          error: "Authorization token required",
          headers: {
            "WWW-Authenticate": 'Bearer realm="API"',
          },
        };
      }

      const decoded = await this.verifyToken(token);

      // Check admin requirements
      if (this.requiresAdmin(path) && decoded.role !== "admin") {
        await this.logAuthAttempt(
          decoded.userId,
          ip,
          headers["user-agent"],
          false,
          "Insufficient privileges"
        );
        return {
          success: false,
          statusCode: 403,
          error: "Insufficient privileges",
        };
      }

      // Check rate limiting
      const rateLimitResult = await this.checkRateLimit(decoded.userId, path);
      if (!rateLimitResult.allowed) {
        await this.logAuthAttempt(
          decoded.userId,
          ip,
          headers["user-agent"],
          false,
          "Rate limit exceeded"
        );
        return {
          success: false,
          statusCode: 429,
          error: "Rate limit exceeded",
          headers: {
            "X-RateLimit-Remaining": "0",
            "X-RateLimit-Reset": rateLimitResult.resetTime.toString(),
          },
        };
      }

      // Success - add user info to headers for upstream services
      await this.logAuthAttempt(
        decoded.userId,
        ip,
        headers["user-agent"],
        true
      );

      return {
        success: true,
        user: decoded,
        headers: {
          "X-Auth-Status": "authenticated",
          "X-User-Id": decoded.userId.toString(),
          "X-User-Role": decoded.role,
          "X-User-Email": decoded.email,
          "X-RateLimit-Remaining": rateLimitResult.remaining.toString(),
        },
      };
    } catch (error) {
      console.error("Authentication error:", error);
      await this.logAuthAttempt(
        null,
        ip,
        headers["user-agent"],
        false,
        error.message
      );

      return {
        success: false,
        statusCode: 401,
        error: "Authentication failed",
        headers: {
          "WWW-Authenticate": 'Bearer realm="API"',
        },
      };
    }
  }

  /**
   * Blacklist a token
   */
  async blacklistToken(token) {
    try {
      const decoded = jwt.decode(token);
      const expiresIn = decoded.exp - Math.floor(Date.now() / 1000);

      if (expiresIn > 0) {
        await redisClient.setex(`blacklist:${token}`, expiresIn, "true");
      }

      return true;
    } catch (error) {
      console.error("Error blacklisting token:", error);
      return false;
    }
  }

  /**
   * Clean up expired entries
   */
  async cleanup() {
    try {
      // This would typically be run as a background job
      const keys = await redisClient.keys("auth_log:*");
      const expiredKeys = [];

      for (const key of keys) {
        const ttl = await redisClient.ttl(key);
        if (ttl === -1) {
          // No expiration set
          expiredKeys.push(key);
        }
      }

      if (expiredKeys.length > 0) {
        await redisClient.del(expiredKeys);
        console.log(
          `Cleaned up ${expiredKeys.length} expired auth log entries`
        );
      }
    } catch (error) {
      console.error("Cleanup error:", error);
    }
  }
}

// Export singleton instance
module.exports = new AuthMiddleware();

// For testing purposes, also export the class
module.exports.AuthMiddleware = AuthMiddleware;
