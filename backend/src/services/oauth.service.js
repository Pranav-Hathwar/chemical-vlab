// OAuth verification for Google sign-in.
//
// Google : the client (google_sign_in) may send EITHER token, so we accept both:
//          • On WEB (Google Identity Services, google_sign_in_web 0.12.x) the
//            interactive signIn() runs the OAuth2 token flow and returns an
//            ACCESS token; the idToken is null (the profile is read from the
//            userinfo endpoint). → verifyGoogleAccessToken — the primary web path.
//          • On native (Android/iOS) the plugin returns an ID token (and an
//            access token); the ID-token path is the reliable native fallback.
//            → verifyGoogleIdToken.
//          Both paths validate the token was issued for OUR client id (aud/azp)
//          against Google's tokeninfo endpoint and read the verified profile.
//
// Uses Node 18+ global fetch (no extra HTTP dependency).

// ── Google: access token (web + mobile) ───────────────────────────────────────
async function verifyGoogleAccessToken(accessToken) {
  // 1) Validate the token and confirm it was issued for our OAuth client.
  const ti = await fetch(
    `https://oauth2.googleapis.com/tokeninfo?access_token=${encodeURIComponent(accessToken)}`,
  );
  if (!ti.ok) {
    throw Object.assign(new Error('Invalid Google access token'), { status: 401 });
  }
  const info = await ti.json();
  const expectedAud = process.env.GOOGLE_CLIENT_ID;
  if (expectedAud && info.aud !== expectedAud && info.azp !== expectedAud) {
    throw Object.assign(new Error('Google token audience mismatch'), {
      status: 401,
    });
  }

  // 2) Fetch the profile (name, email, picture, sub).
  const ui = await fetch('https://www.googleapis.com/oauth2/v3/userinfo', {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (!ui.ok) {
    throw Object.assign(new Error('Could not read Google profile'), { status: 401 });
  }
  const data = await ui.json();
  if (!data.email) {
    throw Object.assign(new Error('Google account has no email'), { status: 400 });
  }

  return {
    email: data.email.toLowerCase(),
    displayName: data.name || data.email.split('@')[0],
    providerId: data.sub,
    photoUrl: data.picture || null,
  };
}

// ── Google: id token (native fallback) ────────────────────────────────────────
async function verifyGoogleIdToken(idToken) {
  const res = await fetch(
    `https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(idToken)}`,
  );
  if (!res.ok) {
    throw Object.assign(new Error('Invalid Google token'), { status: 401 });
  }
  const data = await res.json();

  // Confirm the ID token was minted for OUR client (aud), or authorized party
  // (azp) — parity with the access-token path above.
  const expectedAud = process.env.GOOGLE_CLIENT_ID;
  if (expectedAud && data.aud !== expectedAud && data.azp !== expectedAud) {
    throw Object.assign(new Error('Google token audience mismatch'), {
      status: 401,
    });
  }
  if (!data.email) {
    throw Object.assign(new Error('Google token missing email'), {
      status: 401,
    });
  }

  return {
    email: data.email.toLowerCase(),
    displayName: data.name || data.email.split('@')[0],
    providerId: data.sub,
    photoUrl: data.picture || null,
  };
}

module.exports = {
  verifyGoogleAccessToken,
  verifyGoogleIdToken,
};
