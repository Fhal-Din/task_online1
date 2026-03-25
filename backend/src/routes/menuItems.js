const express = require("express");
const { z } = require("zod");
const { requireAuth, requireRole } = require("../auth/middleware");
const { nowIso, newId } = require("../db");

function createMenuItemsRouter({ db, cache }) {
  const router = express.Router();

  router.get("/", async (req, res) => {
    const categoryId = req.query.categoryId ? String(req.query.categoryId) : null;
    const cacheKey = categoryId ? `menu_items:v1:${categoryId}` : "menu_items:v1:all";
    const cached = await cache.get(cacheKey);
    if (cached) {
      res.json(JSON.parse(cached));
      return;
    }

    const rows = categoryId
      ? db
          .prepare(
            "SELECT id, category_id, name, description, price_cents, is_available, created_at FROM menu_items WHERE category_id = ? ORDER BY created_at DESC"
          )
          .all(categoryId)
      : db
          .prepare(
            "SELECT id, category_id, name, description, price_cents, is_available, created_at FROM menu_items ORDER BY created_at DESC"
          )
          .all();

    await cache.set(cacheKey, JSON.stringify(rows), 30);
    res.json(rows);
  });

  const createSchema = z.object({
    categoryId: z.string().min(1),
    name: z.string().min(1).max(120),
    description: z.string().max(500).optional().nullable(),
    priceCents: z.number().int().nonnegative(),
    isAvailable: z.boolean().optional()
  });

  router.post("/", requireAuth, requireRole(["admin"]), async (req, res) => {
    const parsed = createSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: "Invalid payload" });
      return;
    }

    const category = db
      .prepare("SELECT id FROM categories WHERE id = ?")
      .get(parsed.data.categoryId);
    if (!category) {
      res.status(400).json({ error: "Invalid categoryId" });
      return;
    }

    const row = {
      id: newId(),
      category_id: parsed.data.categoryId,
      name: parsed.data.name,
      description: parsed.data.description || null,
      price_cents: parsed.data.priceCents,
      is_available: parsed.data.isAvailable === false ? 0 : 1,
      created_at: nowIso()
    };

    db.prepare(
      "INSERT INTO menu_items (id, category_id, name, description, price_cents, is_available, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)"
    ).run(
      row.id,
      row.category_id,
      row.name,
      row.description,
      row.price_cents,
      row.is_available,
      row.created_at
    );

    await cache.del("menu_items:v1:all");
    await cache.del(`menu_items:v1:${row.category_id}`);
    res.status(201).json(row);
  });

  const updateSchema = z.object({
    categoryId: z.string().min(1).optional(),
    name: z.string().min(1).max(120).optional(),
    description: z.string().max(500).optional().nullable(),
    priceCents: z.number().int().nonnegative().optional(),
    isAvailable: z.boolean().optional()
  });

  router.put("/:id", requireAuth, requireRole(["admin"]), async (req, res) => {
    const parsed = updateSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: "Invalid payload" });
      return;
    }

    const current = db
      .prepare("SELECT id, category_id FROM menu_items WHERE id = ?")
      .get(req.params.id);
    if (!current) {
      res.status(404).json({ error: "Not found" });
      return;
    }

    const patch = parsed.data;
    if (patch.categoryId) {
      const category = db
        .prepare("SELECT id FROM categories WHERE id = ?")
        .get(patch.categoryId);
      if (!category) {
        res.status(400).json({ error: "Invalid categoryId" });
        return;
      }
    }

    const next = {
      category_id: patch.categoryId || current.category_id,
      name: patch.name,
      description:
        patch.description === undefined ? undefined : patch.description || null,
      price_cents:
        patch.priceCents === undefined ? undefined : patch.priceCents,
      is_available:
        patch.isAvailable === undefined ? undefined : patch.isAvailable ? 1 : 0
    };

    const sets = [];
    const values = [];
    for (const [col, val] of Object.entries(next)) {
      if (val === undefined) continue;
      sets.push(`${col} = ?`);
      values.push(val);
    }
    if (sets.length === 0) {
      res.json({ ok: true });
      return;
    }
    values.push(req.params.id);

    db.prepare(`UPDATE menu_items SET ${sets.join(", ")} WHERE id = ?`).run(
      ...values
    );

    await cache.del("menu_items:v1:all");
    await cache.del(`menu_items:v1:${current.category_id}`);
    await cache.del(`menu_items:v1:${next.category_id}`);
    res.json({ ok: true });
  });

  router.delete("/:id", requireAuth, requireRole(["admin"]), async (req, res) => {
    const current = db
      .prepare("SELECT id, category_id FROM menu_items WHERE id = ?")
      .get(req.params.id);
    if (!current) {
      res.status(404).json({ error: "Not found" });
      return;
    }

    db.prepare("DELETE FROM menu_items WHERE id = ?").run(req.params.id);
    await cache.del("menu_items:v1:all");
    await cache.del(`menu_items:v1:${current.category_id}`);
    res.json({ ok: true });
  });

  return router;
}

module.exports = { createMenuItemsRouter };
