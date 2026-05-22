const express = require('express');
const { param } = require('express-validator');
const ctrl = require('../controllers/admin.controller');
const { validate } = require('../middleware/validate.middleware');
const { authenticate } = require('../middleware/auth.middleware');
const { requireAdmin } = require('../middleware/role.middleware');

const router = express.Router();

// Every /api/admin/* route requires a valid token AND the admin role.
// Students hitting these get 403 from requireAdmin.
router.use(authenticate, requireAdmin);

router.get('/stats', ctrl.stats);
router.get('/students', ctrl.listStudents);
router.get(
  '/students/:id',
  validate([param('id').isUUID().withMessage('Invalid student id')]),
  ctrl.getStudent,
);
router.get(
  '/sessions/:id',
  validate([param('id').isUUID().withMessage('Invalid session id')]),
  ctrl.getSession,
);

module.exports = router;
