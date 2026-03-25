const express = require("express");
const helmet = require("helmet");
const cors = require("cors");
const { authLimiter } = require("./rateLimit");
const { createAuthRouter } = require("./routes/auth");
const { createCategoriesRouter } = require("./routes/categories");
const { createMenuItemsRouter } = require("./routes/menuItems");
const { createTablesRouter } = require("./routes/tables");
const { createOrdersRouter } = require("./routes/orders");

function createApp({ db, cache, realtime }) {
  const app = express();
  app.disable("x-powered-by");

  app.use(helmet());
  app.use(cors());
  app.use(express.json({ limit: "1mb" }));

  app.get("/health", (_req, res) => {
    res.json({ ok: true });
  });

  app.use("/auth", authLimiter, createAuthRouter({ db }));
  app.use("/categories", createCategoriesRouter({ db, cache }));
  app.use("/menu-items", createMenuItemsRouter({ db, cache }));
  app.use("/tables", createTablesRouter({ db }));
  app.use("/orders", createOrdersRouter({ db, realtime }));

  app.use((err, _req, res, _next) => {
    res.status(500).json({ error: "Internal error" });
  });

  return app;
}

module.exports = { createApp };

