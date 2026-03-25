process.env.NODE_ENV = "test";
process.env.SQLITE_PATH = ":memory:";
process.env.JWT_SECRET = "test-secret";

const request = require("supertest");
const speakeasy = require("speakeasy");

const { openDb } = require("../src/db");
const { createCache } = require("../src/cache");
const { createApp } = require("../src/app");

function buildApp() {
  const db = openDb();
  const cache = createCache();
  const realtime = { emit() {} };
  return { app: createApp({ db, cache, realtime }), db };
}

async function registerAndEnable2fa(app, email, password) {
  const reg = await request(app).post("/auth/register").send({ email, password });
  expect(reg.status).toBe(201);
  expect(reg.body.twoFactor.secretBase32).toBeTruthy();

  const otp = speakeasy.totp({
    secret: reg.body.twoFactor.secretBase32,
    encoding: "base32"
  });
  const conf = await request(app)
    .post("/auth/2fa/confirm")
    .send({ email, password, otp });
  expect(conf.status).toBe(200);
  expect(conf.body.accessToken).toBeTruthy();
  return conf.body.accessToken;
}

test("Auth: register + 2FA confirm + login verify-otp", async () => {
  const { app } = buildApp();
  const email = "a@example.com";
  const password = "password123";

  const reg = await request(app).post("/auth/register").send({ email, password });
  expect(reg.status).toBe(201);
  const secret = reg.body.twoFactor.secretBase32;

  const otpSetup = speakeasy.totp({ secret, encoding: "base32" });
  const conf = await request(app)
    .post("/auth/2fa/confirm")
    .send({ email, password, otp: otpSetup });
  expect(conf.status).toBe(200);

  const login = await request(app).post("/auth/login").send({ email, password });
  expect(login.status).toBe(200);
  expect(login.body.requiresOtp).toBe(true);
  expect(login.body.twoFactorToken).toBeTruthy();

  const otpLogin = speakeasy.totp({ secret, encoding: "base32" });
  const verified = await request(app)
    .post("/auth/login/verify-otp")
    .send({ twoFactorToken: login.body.twoFactorToken, otp: otpLogin });
  expect(verified.status).toBe(200);
  expect(verified.body.accessToken).toBeTruthy();
});

test("Menu: categories + menu items CRUD happy path", async () => {
  const { app } = buildApp();
  const token = await registerAndEnable2fa(app, "menu@example.com", "password123");

  const cat = await request(app)
    .post("/categories")
    .set("Authorization", `Bearer ${token}`)
    .send({ name: "Main" });
  expect(cat.status).toBe(201);

  const item = await request(app)
    .post("/menu-items")
    .set("Authorization", `Bearer ${token}`)
    .send({
      categoryId: cat.body.id,
      name: "Nasi Goreng",
      description: "Spicy",
      priceCents: 25000
    });
  expect(item.status).toBe(201);

  const list = await request(app).get("/menu-items");
  expect(list.status).toBe(200);
  expect(list.body.length).toBe(1);
});

test("Orders: create order + update status", async () => {
  const { app } = buildApp();
  const token = await registerAndEnable2fa(app, "orders@example.com", "password123");

  const cat = await request(app)
    .post("/categories")
    .set("Authorization", `Bearer ${token}`)
    .send({ name: "Food" });
  expect(cat.status).toBe(201);

  const item = await request(app)
    .post("/menu-items")
    .set("Authorization", `Bearer ${token}`)
    .send({ categoryId: cat.body.id, name: "Soup", priceCents: 12000 });
  expect(item.status).toBe(201);

  const table = await request(app)
    .post("/tables")
    .set("Authorization", `Bearer ${token}`)
    .send({ name: "T1" });
  expect(table.status).toBe(201);

  const order = await request(app)
    .post("/orders")
    .set("Authorization", `Bearer ${token}`)
    .send({ tableId: table.body.id, items: [{ menuItemId: item.body.id, qty: 2 }] });
  expect(order.status).toBe(201);
  expect(order.body.status).toBe("pending");

  const processing = await request(app)
    .put(`/orders/${order.body.id}/status`)
    .set("Authorization", `Bearer ${token}`)
    .send({ status: "processing" });
  expect(processing.status).toBe(200);
  expect(processing.body.status).toBe("processing");

  const done = await request(app)
    .put(`/orders/${order.body.id}/status`)
    .set("Authorization", `Bearer ${token}`)
    .send({ status: "done" });
  expect(done.status).toBe(200);
  expect(done.body.status).toBe("done");
});

