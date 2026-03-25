const express = require("express");
const { z } = require("zod");
const { requireAuth, requireRole } = require("../auth/middleware");
const { nowIso, newId } = require("../db");

function createCategoriesRouter({ db, cache }) {
  const router = express.Router();

  router.get("/", async (_req, res) => {
    const cacheKey = "categories:v1";
    const cached = await cache.get(cacheKey);
    if (cached) {
      res.json(JSON.parse(cached));
      return;
    }

    const rows = db
      .prepare("SELECT id, name, created_at FROM categories ORDER BY created_at DESC")
      .all();
    await cache.set(cacheKey, JSON.stringify(rows), 30);
    res.json(rows);
  });

  const createSchema = z.object({ name: z.string().min(1).max(120) });
  router.post("/", requireAuth, requireRole(["admin"]), async (req, res) => {
    const parsed = createSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: "Invalid payload" });
      return;
    }

    const row = { id: newId(), name: parsed.data.name, created_at: nowIso() };
    db.prepare("INSERT INTO categories (id, name, created_at) VALUES (?, ?, ?)").run(
      row.id,
      row.name,
      row.created_at
    );
    await cache.del("categories:v1");
    res.status(201).json(row);
  });

  const updateSchema = z.object({ name: z.string().min(1).max(120) });
  router.put("/:id", requireAuth, requireRole(["admin"]), async (req, res) => {
    const parsed = updateSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: "Invalid payload" });
      return;
    }

    const result = db
      .prepare("UPDATE categories SET name = ? WHERE id = ?")
      .run(parsed.data.name, req.params.id);
    if (result.changes === 0) {
      res.status(404).json({ error: "Not found" });
      return;
    }
    await cache.del("categories:v1");
    res.json({ id: req.params.id, name: parsed.data.name });
  });

  router.delete("/:id", requireAuth, requireRole(["admin"]), async (req, res) => {
    const result = db.prepare("DELETE FROM categories WHERE id = ?").run(req.params.id);
    if (result.changes === 0) {
      res.status(404).json({ error: "Not found" });
      return;
    }
    await cache.del("categories:v1");
    res.json({ ok: true });
  });

  return router;
}

module.exports = { createCategoriesRouter };
