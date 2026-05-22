// AES-256-GCM symmetric encryption for the hidden rate constant `k`.
//
// Per the spec, the per-session encryption key is derived as:
//     key = HMAC-SHA256(studentId + sessionId, ENCRYPTION_SECRET)
// HMAC-SHA256 yields exactly 32 bytes — a valid AES-256 key.
//
// Ciphertext format stored in DB (base64 parts joined by '.'):
//     <iv>.<authTag>.<ciphertext>
const crypto = require('crypto');

const MASTER_SECRET = process.env.ENCRYPTION_SECRET || '';
const ALGO = 'aes-256-gcm';

// Derive the 32-byte session key from the student + session identifiers.
function deriveKey(studentId, sessionId) {
  return crypto
    .createHmac('sha256', MASTER_SECRET)
    .update(`${studentId}${sessionId}`)
    .digest(); // 32-byte Buffer
}

// Encrypt a plaintext string with the derived key. Returns "iv.tag.cipher" (base64).
function encrypt(plaintext, key) {
  const iv = crypto.randomBytes(12); // 96-bit nonce recommended for GCM
  const cipher = crypto.createCipheriv(ALGO, key, iv);
  const enc = Buffer.concat([
    cipher.update(String(plaintext), 'utf8'),
    cipher.final(),
  ]);
  const tag = cipher.getAuthTag();
  return [
    iv.toString('base64'),
    tag.toString('base64'),
    enc.toString('base64'),
  ].join('.');
}

// Decrypt a payload produced by encrypt(). Throws if the auth tag fails.
function decrypt(payload, key) {
  const [ivB64, tagB64, dataB64] = String(payload).split('.');
  const iv = Buffer.from(ivB64, 'base64');
  const tag = Buffer.from(tagB64, 'base64');
  const data = Buffer.from(dataB64, 'base64');
  const decipher = crypto.createDecipheriv(ALGO, key, iv);
  decipher.setAuthTag(tag);
  const dec = Buffer.concat([decipher.update(data), decipher.final()]);
  return dec.toString('utf8');
}

module.exports = { deriveKey, encrypt, decrypt };
