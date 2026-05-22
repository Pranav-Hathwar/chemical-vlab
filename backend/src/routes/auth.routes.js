const express = require('express');
const { body } = require('express-validator');
const ctrl = require('../controllers/auth.controller');
const { validate } = require('../middleware/validate.middleware');
const { authenticate } = require('../middleware/auth.middleware');
const { authLimiter } = require('../middleware/rateLimit.middleware');

const router = express.Router();

// Tighter rate limit on every auth endpoint (5/min).
router.use(authLimiter);

router.post(
  '/register',
  validate([
    body('email').isEmail().withMessage('A valid email is required'),
    body('displayName')
      .trim()
      .isLength({ min: 1, max: 255 })
      .withMessage('Display name is required'),
    body('password')
      .isLength({ min: 8 })
      .withMessage('Password must be at least 8 characters'),
  ]),
  ctrl.register,
);

router.post(
  '/login',
  validate([
    body('email').isEmail().withMessage('A valid email is required'),
    body('password').notEmpty().withMessage('Password is required'),
  ]),
  ctrl.login,
);

router.post('/refresh', ctrl.refresh);
router.post('/logout', ctrl.logout);
router.get('/me', authenticate, ctrl.me);

// OAuth
router.post(
  '/google',
  validate([
    body().custom((value, { req }) => {
      if (!req.body.accessToken && !req.body.idToken) {
        throw new Error('accessToken or idToken is required');
      }
      return true;
    }),
  ]),
  ctrl.googleLogin,
);

module.exports = router;
