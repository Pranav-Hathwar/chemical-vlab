// Verifies the Bearer access token and attaches req.user = { id, email, role }.
const { verifyAccessToken } = require('../config/jwt');

function authenticate(req, res, next) {
  const header = req.headers.authorization || '';
  const [scheme, token] = header.split(' ');

  if (scheme !== 'Bearer' || !token) {
    return res
      .status(401)
      .json({ success: false, error: 'Missing or malformed Authorization header' });
  }

  try {
    const payload = verifyAccessToken(token);
    req.user = { id: payload.sub, email: payload.email, role: payload.role };
    return next();
  } catch (_) {
    return res
      .status(401)
      .json({ success: false, error: 'Invalid or expired access token' });
  }
}

module.exports = { authenticate };
