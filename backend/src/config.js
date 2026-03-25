const path = require("path");

function requireEnv(name) {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing env: ${name}`);
  }
  return value;
}

const config = {
  env: process.env.NODE_ENV || "development",
  port: Number(process.env.PORT || 4000),
  jwtSecret: process.env.JWT_SECRET || "dev-secret-change-me",
  jwtIssuer: process.env.JWT_ISSUER || "restaurant-order-backend",
  sqlitePath:
    process.env.SQLITE_PATH || path.join(__dirname, "..", "data.sqlite"),
  redisUrl: process.env.REDIS_URL || null,
  googleClientId: process.env.GOOGLE_CLIENT_ID || null,
  requireEnv
};

module.exports = { config };

