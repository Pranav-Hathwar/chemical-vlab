// Hidden-k specific encryption helpers built on the AES-256-GCM primitives.
//
// The hidden rate constant `k` is generated SERVER-SIDE in the same physical
// range as the original Flutter MFRSolver.generateK() ([0.25, 0.50]) so the
// simulation behaves identically — but here it is the server that owns it.
const crypto = require('crypto');
const { deriveKey, encrypt, decrypt } = require('../config/encryption');

const K_MIN = 0.25; // L/(mol·min)
const K_MAX = 0.5; // L/(mol·min)

// Cryptographically-strong uniform random k in [K_MIN, K_MAX].
function generateHiddenK() {
  // 6 random bytes -> [0,1) float, then scale into the k range.
  const r = crypto.randomBytes(6).readUIntBE(0, 6) / 0x1000000000000;
  const k = K_MIN + r * (K_MAX - K_MIN);
  return Number(k.toFixed(6));
}

function encryptK(plainK, studentId, sessionId) {
  const key = deriveKey(studentId, sessionId);
  return encrypt(plainK, key);
}

function decryptK(payload, studentId, sessionId) {
  const key = deriveKey(studentId, sessionId);
  return parseFloat(decrypt(payload, key));
}

module.exports = { generateHiddenK, encryptK, decryptK, K_MIN, K_MAX };
