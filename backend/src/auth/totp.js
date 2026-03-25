const speakeasy = require("speakeasy");

function createTotpSecret(email) {
  const secret = speakeasy.generateSecret({
    name: `Restaurant (${email})`
  });
  return {
    base32: secret.base32,
    otpauthUrl: secret.otpauth_url
  };
}

function verifyTotp({ secretBase32, token }) {
  return speakeasy.totp.verify({
    secret: secretBase32,
    encoding: "base32",
    token,
    window: 1
  });
}

module.exports = { createTotpSecret, verifyTotp };

