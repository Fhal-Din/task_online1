const { verifyToken } = require("./jwt");

function requireAuth(req, res, next) {
  const header = req.headers.authorization || "";
  const token = header.startsWith("Bearer ") ? header.slice(7) : null;
  if (!token) {
    res.status(401).json({ error: "Unauthorized" });
    return;
  }

  try {
    const payload = verifyToken(token);
    if (payload.typ !== "access") {
      res.status(401).json({ error: "Unauthorized" });
      return;
    }
    req.user = { id: payload.sub, email: payload.email, role: payload.role };
    next();
  } catch (_err) {
    res.status(401).json({ error: "Unauthorized" });
  }
}

function requireRole(roles) {
  const allowed = new Set(roles);
  return (req, res, next) => {
    if (!req.user || !allowed.has(req.user.role)) {
      res.status(403).json({ error: "Forbidden" });
      return;
    }
    next();
  };
}

module.exports = { requireAuth, requireRole };
