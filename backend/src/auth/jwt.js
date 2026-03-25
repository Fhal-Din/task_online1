const jwt = require("jsonwebtoken");
const { config } = require("../config");

function signAccessToken(user) {
  return jwt.sign(
    { sub: user.id, email: user.email, role: user.role, typ: "access" },
    config.jwtSecret,
    {
      issuer: config.jwtIssuer,
      expiresIn: "12h"
    }
  );
}

function signTwoFactorToken(user) {
  return jwt.sign({ sub: user.id, typ: "2fa" }, config.jwtSecret, {
    issuer: config.jwtIssuer,
    expiresIn: "10m"
  });
}

function verifyToken(token) {
  return jwt.verify(token, config.jwtSecret, { issuer: config.jwtIssuer });
}

module.exports = { signAccessToken, signTwoFactorToken, verifyToken };
