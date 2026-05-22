// HTTP handlers for student sessions and trials.
const sessionService = require('../services/session.service');

function ok(res, data, status = 200) {
  return res.status(status).json({ success: true, data });
}
function fail(res, err) {
  const status = err.status || 500;
  if (status >= 500) console.error(err);
  return res.status(status).json({ success: false, error: err.message });
}

async function createSession(req, res) {
  try {
    const { ca0Prime, cb0Prime, vr } = req.body;
    const result = await sessionService.createSession({
      studentId: req.user.id,
      ca0Prime,
      cb0Prime,
      vr,
    });
    return ok(res, result, 201);
  } catch (err) {
    return fail(res, err);
  }
}

async function getActive(req, res) {
  try {
    const result = await sessionService.getActiveSession(req.user.id);
    return ok(res, { active: result }); // active === null when none
  } catch (err) {
    return fail(res, err);
  }
}

async function recordTrial(req, res) {
  try {
    const { runNumber, va, vb, ca0, cb0, tau, m, xa, ca, graphY } = req.body;
    const result = await sessionService.recordTrial({
      studentId: req.user.id,
      sessionId: req.params.id,
      trial: { runNumber, va, vb, ca0, cb0, tau, m, xa, ca, graphY },
    });
    return ok(res, result, 201);
  } catch (err) {
    return fail(res, err);
  }
}

async function submitK(req, res) {
  try {
    const { studentK } = req.body;
    const result = await sessionService.submitStudentK({
      studentId: req.user.id,
      sessionId: req.params.id,
      studentK,
    });
    return ok(res, result);
  } catch (err) {
    return fail(res, err);
  }
}

module.exports = { createSession, getActive, recordTrial, submitK };
