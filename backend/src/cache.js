const Redis = require("ioredis");
const { config } = require("./config");

function createCache() {
  if (config.redisUrl) {
    const redis = new Redis(config.redisUrl, { maxRetriesPerRequest: 1 });
    return {
      async get(key) {
        return redis.get(key);
      },
      async set(key, value, ttlSeconds) {
        if (ttlSeconds) {
          await redis.set(key, value, "EX", ttlSeconds);
          return;
        }
        await redis.set(key, value);
      },
      async del(key) {
        await redis.del(key);
      }
    };
  }

  const store = new Map();
  return {
    async get(key) {
      const entry = store.get(key);
      if (!entry) return null;
      if (entry.expiresAt && Date.now() > entry.expiresAt) {
        store.delete(key);
        return null;
      }
      return entry.value;
    },
    async set(key, value, ttlSeconds) {
      store.set(key, {
        value,
        expiresAt: ttlSeconds ? Date.now() + ttlSeconds * 1000 : null
      });
    },
    async del(key) {
      store.delete(key);
    }
  };
}

module.exports = { createCache };

