require("dotenv").config();

const http = require("http");
const { Server } = require("socket.io");
const { config } = require("./config");
const { openDb } = require("./db");
const { createCache } = require("./cache");
const { createApp } = require("./app");
const { verifyToken } = require("./auth/jwt");

const db = openDb();
const cache = createCache();

function createRealtime(io) {
  return {
    emit(event, payload) {
      io.emit(event, payload);
    }
  };
}

const httpServer = http.createServer();

const io = new Server(httpServer, {
  cors: {
    origin: "*"
  }
});

io.use((socket, next) => {
  const token = socket.handshake.auth && socket.handshake.auth.token;
  if (!token) return next(new Error("unauthorized"));
  try {
    const payload = verifyToken(token);
    if (payload.typ !== "access") return next(new Error("unauthorized"));
    socket.user = { id: payload.sub, email: payload.email };
    next();
  } catch (_err) {
    next(new Error("unauthorized"));
  }
});

const app = createApp({ db, cache, realtime: createRealtime(io) });
httpServer.on("request", app);

httpServer.listen(config.port, config.host, () => {
  console.log(`API listening on http://${config.host}:${config.port}`);
});
