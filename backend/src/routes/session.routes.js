const express = require('express');
const { body, param } = require('express-validator');
const ctrl = require('../controllers/session.controller');
const { validate } = require('../middleware/validate.middleware');
const { authenticate } = require('../middleware/auth.middleware');
const { requireStudent } = require('../middleware/role.middleware');

const router = express.Router();

// Sessions belong to the authenticated student (admins may also use them).
router.use(authenticate, requireStudent);

const positive = (field) =>
  body(field).isFloat({ gt: 0 }).withMessage(`${field} must be a positive number`);

router.post(
  '/',
  validate([positive('ca0Prime'), positive('cb0Prime'), positive('vr')]),
  ctrl.createSession,
);

router.get('/active', ctrl.getActive);

router.post(
  '/:id/trials',
  validate([
    param('id').isUUID().withMessage('Invalid session id'),
    body('runNumber')
      .isInt({ min: 1, max: 10 })
      .withMessage('runNumber must be between 1 and 10'),
    positive('va'),
    positive('vb'),
    positive('ca0'),
    positive('cb0'),
    positive('tau'),
    positive('m'),
    body('xa').isFloat().withMessage('xa must be a number'),
    body('ca').isFloat().withMessage('ca must be a number'),
    body('graphY').isFloat().withMessage('graphY must be a number'),
  ]),
  ctrl.recordTrial,
);

router.post(
  '/:id/submit',
  validate([
    param('id').isUUID().withMessage('Invalid session id'),
    body('studentK').isFloat({ gt: 0 }).withMessage('studentK must be positive'),
  ]),
  ctrl.submitK,
);

module.exports = router;
