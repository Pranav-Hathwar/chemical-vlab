// Role guards. Must run after authenticate (relies on req.user.role).
function requireRole(...roles) {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ success: false, error: 'Not authenticated' });
    }
    if (!roles.includes(req.user.role)) {
      return res
        .status(403)
        .json({ success: false, error: 'Forbidden: insufficient permissions' });
    }
    return next();
  };
}

const requireAdmin = requireRole('admin');
const requireStudent = requireRole('student', 'admin');

module.exports = { requireRole, requireAdmin, requireStudent };
