const express = require("express");
const { z } = require("zod");
const { requireAuth, requireRole } = require("../auth/middleware");
const { nowIso, newId } = require("../db");

const orderStatus = z.enum(["pending", "processing", "done"]);

function canTransition(from, to) {
  if (from === to) return true;
  if (from === "pending" && to === "processing") return true;
  if (from === "processing" && to === "done") return true;
  return false;
}

function getOrdersWithItems(db, { status }) {
  const orders = status
    ? db
        .prepare(
          "SELECT id, table_id, status, created_at, updated_at FROM orders WHERE status = ? ORDER BY updated_at DESC"
        )
        .all(status)
    : db
        .prepare(
          "SELECT id, table_id, status, created_at, updated_at FROM orders ORDER BY updated_at DESC"
        )
        .all();

  const orderIds = orders.map((o) => o.id);
  if (orderIds.length === 0) return [];

  const placeholders = orderIds.map(() => "?").join(", ");
  const items = db
    .prepare(
      `SELECT id, order_id, menu_item_id, name_snapshot, price_cents_snapshot, qty FROM order_items WHERE order_id IN (${placeholders})`
    )
    .all(...orderIds);

  const byOrder = new Map();
  for (const item of items) {
    const list = byOrder.get(item.order_id) || [];
    list.push(item);
    byOrder.set(item.order_id, list);
  }

  return orders.map((o) => ({
    ...o,
    items: byOrder.get(o.id) || []
  }));
}

function createOrdersRouter({ db, realtime }) {
  const router = express.Router();

  router.get("/", requireAuth, requireRole(["admin", "cashier", "kitchen"]), (req, res) => {
    const status = req.query.status ? String(req.query.status) : null;
    const parsedStatus = status ? orderStatus.safeParse(status) : { success: true, data: null };
    if (!parsedStatus.success) {
      res.status(400).json({ error: "Invalid status" });
      return;
    }

    const rows = getOrdersWithItems(db, { status: parsedStatus.data });
    res.json(rows);
  });

  const createSchema = z.object({
    tableId: z.string().min(1),
    items: z
      .array(
        z.object({
          menuItemId: z.string().min(1),
          qty: z.number().int().positive().max(99)
        })
      )
      .min(1)
  });

  function handleCreateOrder(body, res) {
    const parsed = createSchema.safeParse(body);
    if (!parsed.success) {
      res.status(400).json({ error: "Invalid payload" });
      return null;
    }

    const { tableId, items } = parsed.data;
    const table = db.prepare("SELECT id FROM tables WHERE id = ?").get(tableId);
    if (!table) {
      res.status(400).json({ error: "Invalid tableId" });
      return null;
    }

    const menuById = new Map();
    const fetchStmt = db.prepare(
      "SELECT id, name, price_cents, is_available FROM menu_items WHERE id = ?"
    );
    for (const it of items) {
      const mi = fetchStmt.get(it.menuItemId);
      if (!mi) {
        res.status(400).json({ error: "Invalid menuItemId", menuItemId: it.menuItemId });
        return null;
      }
      if (!mi.is_available) {
        res.status(400).json({ error: "Menu item not available", menuItemId: it.menuItemId });
        return null;
      }
      menuById.set(mi.id, mi);
    }

    const order = {
      id: newId(),
      table_id: tableId,
      status: "pending",
      created_at: nowIso(),
      updated_at: nowIso()
    };

    const insertOrder = db.prepare(
      "INSERT INTO orders (id, table_id, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?)"
    );
    const insertItem = db.prepare(
      "INSERT INTO order_items (id, order_id, menu_item_id, name_snapshot, price_cents_snapshot, qty) VALUES (?, ?, ?, ?, ?, ?)"
    );

    const tx = db.transaction(() => {
      insertOrder.run(
        order.id,
        order.table_id,
        order.status,
        order.created_at,
        order.updated_at
      );
      for (const it of items) {
        const mi = menuById.get(it.menuItemId);
        insertItem.run(
          newId(),
          order.id,
          mi.id,
          mi.name,
          mi.price_cents,
          it.qty
        );
      }
    });
    tx();

    const fullOrder = getOrdersWithItems(db, { status: null }).find((o) => o.id === order.id);
    return fullOrder || { ...order, items: [] };
  }

  router.post("/", requireAuth, requireRole(["admin", "cashier"]), (req, res) => {
    const created = handleCreateOrder(req.body, res);
    if (!created) return;
    if (realtime) realtime.emit("order:new", created);
    res.status(201).json(created);
  });

  router.post("/public", (req, res) => {
    const created = handleCreateOrder(req.body, res);
    if (!created) return;
    if (realtime) realtime.emit("order:new", created);
    res.status(201).json(created);
  });

  const statusSchema = z.object({ status: orderStatus });
  router.put("/:id/status", requireAuth, requireRole(["admin", "kitchen"]), (req, res) => {
    const parsed = statusSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: "Invalid payload" });
      return;
    }

    const current = db
      .prepare("SELECT id, status FROM orders WHERE id = ?")
      .get(req.params.id);
    if (!current) {
      res.status(404).json({ error: "Not found" });
      return;
    }

    if (!canTransition(current.status, parsed.data.status)) {
      res.status(400).json({ error: "Invalid status transition" });
      return;
    }

    const updatedAt = nowIso();
    db.prepare("UPDATE orders SET status = ?, updated_at = ? WHERE id = ?").run(
      parsed.data.status,
      updatedAt,
      req.params.id
    );

    const updated = getOrdersWithItems(db, { status: null }).find((o) => o.id === req.params.id);
    if (realtime && updated) realtime.emit("order:updated", updated);
    res.json(updated || { ok: true });
  });

  return router;
}

module.exports = { createOrdersRouter, orderStatus };
