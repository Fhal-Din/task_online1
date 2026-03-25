const express = require("express");
const { z } = require("zod");
const { requireAuth, requireRole } = require("../auth/middleware");
const { nowIso, newId } = require("../db");

const tableStatus = z.enum(["available", "occupied", "reserved", "cleaning"]);

function createTablesRouter({ db }) {
  const router = express.Router();

  router.get("/", (_req, res) => {
    const rows = db
      .prepare("SELECT id, name, status, created_at FROM tables ORDER BY created_at DESC")
      .all();
    res.json(rows);
  });

  const createSchema = z.object({
    name: z.string().min(1).max(60),
    status: tableStatus.optional()
  });

  router.post("/", requireAuth, requireRole(["admin"]), (req, res) => {
    const parsed = createSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: "Invalid payload" });
      return;
    }

    const row = {
      id: newId(),
      name: parsed.data.name,
      status: parsed.data.status || "available",
      created_at: nowIso()
    };

    db.prepare("INSERT INTO tables (id, name, status, created_at) VALUES (?, ?, ?, ?)").run(
      row.id,
      row.name,
      row.status,
      row.created_at
    );
    res.status(201).json(row);
  });

  const updateSchema = z.object({
    name: z.string().min(1).max(60).optional(),
    status: tableStatus.optional()
  });

  router.put("/:id", requireAuth, requireRole(["admin"]), (req, res) => {
    const parsed = updateSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: "Invalid payload" });
      return;
    }

    const sets = [];
    const values = [];
    if (parsed.data.name !== undefined) {
      sets.push("name = ?");
      values.push(parsed.data.name);
    }
    if (parsed.data.status !== undefined) {
      sets.push("status = ?");
      values.push(parsed.data.status);
    }
    if (sets.length === 0) {
      res.json({ ok: true });
      return;
    }

    values.push(req.params.id);
    const result = db.prepare(`UPDATE tables SET ${sets.join(", ")} WHERE id = ?`).run(
      ...values
    );
    if (result.changes === 0) {
      res.status(404).json({ error: "Not found" });
      return;
    }
    res.json({ ok: true });
  });

  router.delete("/:id", requireAuth, requireRole(["admin"]), (req, res) => {
    const result = db.prepare("DELETE FROM tables WHERE id = ?").run(req.params.id);
    if (result.changes === 0) {
      res.status(404).json({ error: "Not found" });
      return;
    }
    res.json({ ok: true });
  });

  return router;
}

module.exports = { createTablesRouter, tableStatus };
