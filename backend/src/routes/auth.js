const express = require("express");
const { z } = require("zod");
const { OAuth2Client } = require("google-auth-library");
const { hashPassword, verifyPassword } = require("../auth/password");
const { createTotpSecret, verifyTotp } = require("../auth/totp");
const { signAccessToken, signTwoFactorToken, verifyToken } = require("../auth/jwt");
const { nowIso, newId } = require("../db");
const { requireAuth, requireRole } = require("../auth/middleware");
const { config } = require("../config");

function createAuthRouter({ db }) {
  const router = express.Router();
  const googleClient = config.googleClientId ? new OAuth2Client(config.googleClientId) : null;

  const registerSchema = z.object({
    email: z.string().email().max(255),
    password: z.string().min(8).max(200)
  });

  router.post("/register", async (req, res) => {
    const parsed = registerSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: "Invalid payload" });
      return;
    }

    const { email, password } = parsed.data;
    const existing = db
      .prepare("SELECT id FROM users WHERE email = ?")
      .get(email);
    if (existing) {
      res.status(409).json({ error: "Email already registered" });
      return;
    }

    const passwordHash = await hashPassword(password);
    const totp = createTotpSecret(email);
    const userCount = db.prepare("SELECT COUNT(*) as c FROM users").get();
    const role = userCount && userCount.c > 0 ? "cashier" : "admin";
    const user = {
      id: newId(),
      email,
      password_hash: passwordHash,
      totp_secret: totp.base32,
      totp_enabled: 0,
      role,
      created_at: nowIso()
    };

    db.prepare(
      "INSERT INTO users (id, email, password_hash, totp_secret, totp_enabled, role, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)"
    ).run(
      user.id,
      user.email,
      user.password_hash,
      user.totp_secret,
      user.totp_enabled,
      user.role,
      user.created_at
    );

    const response = {
      id: user.id,
      email: user.email,
      twoFactor: {
        enabled: false,
        otpauthUrl: totp.otpauthUrl
      }
    };
    if (config.env === "test") {
      response.twoFactor.secretBase32 = totp.base32;
    }
    res.status(201).json({ ...response, role: user.role });
  });

  const confirm2faSchema = z.object({
    email: z.string().email(),
    password: z.string().min(8),
    otp: z.string().min(6).max(8)
  });

  router.post("/2fa/confirm", async (req, res) => {
    const parsed = confirm2faSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: "Invalid payload" });
      return;
    }

    const { email, password, otp } = parsed.data;
    const user = db
      .prepare(
        "SELECT id, email, password_hash, totp_secret, totp_enabled, role FROM users WHERE email = ?"
      )
      .get(email);

    if (!user) {
      res.status(401).json({ error: "Invalid credentials" });
      return;
    }

    const ok = await verifyPassword(password, user.password_hash);
    if (!ok) {
      res.status(401).json({ error: "Invalid credentials" });
      return;
    }

    if (!user.totp_secret) {
      res.status(400).json({ error: "2FA not initialized" });
      return;
    }

    if (!verifyTotp({ secretBase32: user.totp_secret, token: otp })) {
      res.status(401).json({ error: "Invalid OTP" });
      return;
    }

    db.prepare("UPDATE users SET totp_enabled = 1 WHERE id = ?").run(user.id);

    const accessToken = signAccessToken({ id: user.id, email: user.email, role: user.role });
    res.json({ accessToken });
  });

  const loginSchema = z.object({
    email: z.string().email(),
    password: z.string().min(8)
  });

  router.post("/login", async (req, res) => {
    const parsed = loginSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: "Invalid payload" });
      return;
    }

    const { email, password } = parsed.data;
    const user = db
      .prepare(
        "SELECT id, email, password_hash, totp_secret, totp_enabled, role FROM users WHERE email = ?"
      )
      .get(email);

    if (!user) {
      res.status(401).json({ error: "Invalid credentials" });
      return;
    }

    const ok = await verifyPassword(password, user.password_hash);
    if (!ok) {
      res.status(401).json({ error: "Invalid credentials" });
      return;
    }

    if (user.totp_enabled) {
      const twoFactorToken = signTwoFactorToken({ id: user.id });
      res.json({ requiresOtp: true, twoFactorToken });
      return;
    }

    const accessToken = signAccessToken({ id: user.id, email: user.email, role: user.role });
    res.json({ accessToken });
  });

  const verifyOtpSchema = z.object({
    twoFactorToken: z.string().min(10),
    otp: z.string().min(6).max(8)
  });

  router.post("/login/verify-otp", (req, res) => {
    const parsed = verifyOtpSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: "Invalid payload" });
      return;
    }

    let payload;
    try {
      payload = verifyToken(parsed.data.twoFactorToken);
    } catch (_err) {
      res.status(401).json({ error: "Invalid token" });
      return;
    }

    if (payload.typ !== "2fa") {
      res.status(401).json({ error: "Invalid token" });
      return;
    }

    const user = db
      .prepare("SELECT id, email, totp_secret, totp_enabled, role FROM users WHERE id = ?")
      .get(payload.sub);
    if (!user || !user.totp_enabled || !user.totp_secret) {
      res.status(401).json({ error: "Invalid token" });
      return;
    }

    if (!verifyTotp({ secretBase32: user.totp_secret, token: parsed.data.otp })) {
      res.status(401).json({ error: "Invalid OTP" });
      return;
    }

    const accessToken = signAccessToken({ id: user.id, email: user.email, role: user.role });
    res.json({ accessToken });
  });

  router.get("/me", requireAuth, (req, res) => {
    res.json({ id: req.user.id, email: req.user.email, role: req.user.role });
  });

  const googleSchema = z.object({ idToken: z.string().min(20) });
  router.post("/google", async (req, res) => {
    const parsed = googleSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: "Invalid payload" });
      return;
    }
    if (!googleClient) {
      res.status(400).json({ error: "Google Sign-In not configured" });
      return;
    }

    let ticket;
    try {
      ticket = await googleClient.verifyIdToken({
        idToken: parsed.data.idToken,
        audience: config.googleClientId
      });
    } catch (_err) {
      res.status(401).json({ error: "Invalid Google token" });
      return;
    }

    const payload = ticket.getPayload();
    const email = payload && payload.email;
    if (!email) {
      res.status(401).json({ error: "Invalid Google token" });
      return;
    }

    let user = db.prepare("SELECT id, email, role FROM users WHERE email = ?").get(email);
    if (!user) {
      const passwordHash = await hashPassword(newId());
      const userCount = db.prepare("SELECT COUNT(*) as c FROM users").get();
      const role = userCount && userCount.c > 0 ? "cashier" : "admin";
      const row = {
        id: newId(),
        email,
        password_hash: passwordHash,
        totp_secret: null,
        totp_enabled: 0,
        role,
        created_at: nowIso()
      };
      db.prepare(
        "INSERT INTO users (id, email, password_hash, totp_secret, totp_enabled, role, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)"
      ).run(
        row.id,
        row.email,
        row.password_hash,
        row.totp_secret,
        row.totp_enabled,
        row.role,
        row.created_at
      );
      user = { id: row.id, email: row.email, role: row.role };
    }

    const accessToken = signAccessToken({ id: user.id, email: user.email, role: user.role });
    res.json({ accessToken });
  });

  const setupSchema = z.object({});
  router.post("/2fa/setup", requireAuth, (req, res) => {
    const parsed = setupSchema.safeParse(req.body || {});
    if (!parsed.success) {
      res.status(400).json({ error: "Invalid payload" });
      return;
    }

    const user = db
      .prepare("SELECT id, email FROM users WHERE id = ?")
      .get(req.user.id);
    if (!user) {
      res.status(401).json({ error: "Unauthorized" });
      return;
    }

    const totp = createTotpSecret(user.email);
    db.prepare("UPDATE users SET totp_secret = ?, totp_enabled = 0 WHERE id = ?").run(
      totp.base32,
      user.id
    );

    const response = { otpauthUrl: totp.otpauthUrl };
    if (config.env === "test") {
      response.secretBase32 = totp.base32;
    }
    res.json(response);
  });

  const enableSchema = z.object({ otp: z.string().min(6).max(8) });
  router.post("/2fa/enable", requireAuth, (req, res) => {
    const parsed = enableSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: "Invalid payload" });
      return;
    }

    const user = db
      .prepare("SELECT id, totp_secret FROM users WHERE id = ?")
      .get(req.user.id);
    if (!user || !user.totp_secret) {
      res.status(400).json({ error: "2FA not initialized" });
      return;
    }

    if (!verifyTotp({ secretBase32: user.totp_secret, token: parsed.data.otp })) {
      res.status(401).json({ error: "Invalid OTP" });
      return;
    }

    db.prepare("UPDATE users SET totp_enabled = 1 WHERE id = ?").run(user.id);
    res.json({ enabled: true });
  });

  const roleSchema = z.object({
    role: z.enum(["admin", "cashier", "kitchen"])
  });

  router.put("/users/:id/role", requireAuth, requireRole(["admin"]), (req, res) => {
    const parsed = roleSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: "Invalid payload" });
      return;
    }

    const result = db.prepare("UPDATE users SET role = ? WHERE id = ?").run(
      parsed.data.role,
      req.params.id
    );
    if (result.changes === 0) {
      res.status(404).json({ error: "Not found" });
      return;
    }
    res.json({ ok: true });
  });

  router.get("/users", requireAuth, requireRole(["admin"]), (_req, res) => {
    const rows = db
      .prepare("SELECT id, email, role, created_at FROM users ORDER BY created_at DESC")
      .all();
    res.json(rows);
  });

  return router;
}

module.exports = { createAuthRouter };
