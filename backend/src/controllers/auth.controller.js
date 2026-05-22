// HTTP handlers for authentication: register, login, refresh, logout, me, OAuth.
const prisma = require('../prisma');
const authService = require('../services/auth.service');
const oauthService = require('../services/oauth.service');

function ok(res, data, status = 200) {
  return res.status(status).json({ success: true, data });
}
function fail(res, err) {
  const status = err.status || 500;
  if (status >= 500) console.error(err);
  return res.status(status).json({ success: false, error: err.message });
}

async function register(req, res) {
  try {
    const { email, displayName, password } = req.body;
    const result = await authService.registerUser({ email, displayName, password });
    return ok(res, result, 201);
  } catch (err) {
    return fail(res, err);
  }
}

async function login(req, res) {
  try {
    const { email, password } = req.body;
    const result = await authService.loginUser({ email, password });
    return ok(res, result);
  } catch (err) {
    return fail(res, err);
  }
}

async function refresh(req, res) {
  try {
    const { refreshToken } = req.body;
    if (!refreshToken) {
      return fail(res, Object.assign(new Error('refreshToken is required'), { status: 400 }));
    }
    const result = await authService.rotateRefreshToken(refreshToken);
    return ok(res, result);
  } catch (err) {
    return fail(res, err);
  }
}

async function logout(req, res) {
  try {
    await authService.revokeRefreshToken(req.body.refreshToken);
    return ok(res, { message: 'Logged out' });
  } catch (err) {
    return fail(res, err);
  }
}

async function me(req, res) {
  try {
    const user = await prisma.user.findUnique({ where: { id: req.user.id } });
    if (!user) {
      return fail(res, Object.assign(new Error('User not found'), { status: 404 }));
    }
    return ok(res, { user: authService.publicUser(user) });
  } catch (err) {
    return fail(res, err);
  }
}

// ── OAuth ──────────────────────────────────────────────────────────────────────
async function googleLogin(req, res) {
  try {
    const { accessToken, idToken } = req.body;
    // Web (and mobile) reliably provide an access token; idToken is a fallback.
    let profile;
    if (accessToken) {
      profile = await oauthService.verifyGoogleAccessToken(accessToken);
    } else if (idToken) {
      profile = await oauthService.verifyGoogleIdToken(idToken);
    } else {
      return fail(res, Object.assign(new Error('accessToken or idToken is required'), { status: 400 }));
    }
    const result = await authService.findOrCreateOAuthUser({ ...profile, provider: 'google' });
    return ok(res, result);
  } catch (err) {
    return fail(res, err);
  }
}

module.exports = {
  register,
  login,
  refresh,
  logout,
  me,
  googleLogin,
};
