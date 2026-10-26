import { base64url, AttendanceError } from "./attendance.js";
const JWKS_URL =
  "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com";
const encoder = new TextEncoder();
function unbase64(value) {
  return Uint8Array.from(
    atob(value.replaceAll("-", "+").replaceAll("_", "/")),
    (c) => c.charCodeAt(0),
  );
}
const invalid = () => {
  throw new AttendanceError(
    "unauthenticated",
    "Sign in again before using attendance.",
  );
};
// Cache keys and in-flight fetches per isolate. Request headers never select key URLs.
export function firebaseVerifier({ fetchImpl = fetch, clock = Date.now } = {}) {
  let keys = new Map(),
    expires = 0,
    pending,
    lastRefresh = 0;
  async function refresh() {
    if (pending) return pending;
    pending = (async () => {
      const response = await fetchImpl(JWKS_URL, {
        redirect: "error",
        signal: AbortSignal.timeout(5000),
      });
      if (!response.ok) throw new Error("Firebase keys unavailable.");
      const data = await response.json();
      const imported = new Map();
      for (const jwk of data.keys ?? []) {
        if (
          jwk.kty === "RSA" &&
          (!jwk.alg || jwk.alg === "RS256") &&
          jwk.kid &&
          (!jwk.use || jwk.use === "sig")
        ) {
          imported.set(
            jwk.kid,
            await crypto.subtle.importKey(
              "jwk",
              jwk,
              { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
              false,
              ["verify"],
            ),
          );
        }
      }
      if (!imported.size) throw new Error("Firebase keys unavailable.");
      const maxAge = Number(
        /max-age=(\d+)/.exec(
          response.headers.get("Cache-Control") ?? "",
        )?.[1] ?? 300,
      );
      keys = imported;
      expires = clock() + Math.min(maxAge, 86400) * 1000;
      lastRefresh = clock();
    })();
    try {
      await pending;
    } finally {
      pending = undefined;
    }
  }
  return async (authorization) => {
    const match =
      /^Bearer ([A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)$/.exec(
        authorization ?? "",
      );
    if (!match || match[1].length > 8192) invalid();
    const parts = match[1].split(".");
    let header, payload;
    try {
      header = JSON.parse(new TextDecoder().decode(unbase64(parts[0])));
      payload = JSON.parse(new TextDecoder().decode(unbase64(parts[1])));
    } catch {
      invalid();
    }
    const now = clock() / 1000;
    if (
      header?.alg !== "RS256" ||
      typeof header.kid !== "string" ||
      header.kid.length > 128 ||
      payload?.aud !== "orglink-dev" ||
      payload.iss !== "https://securetoken.google.com/orglink-dev" ||
      typeof payload.sub !== "string" ||
      !payload.sub.length ||
      payload.sub.length > 128 ||
      payload.sub.includes("/") ||
      !Number.isFinite(payload.exp) ||
      payload.exp <= now ||
      !Number.isFinite(payload.iat) ||
      payload.iat > now ||
      !Number.isFinite(payload.auth_time) ||
      payload.auth_time < 0 ||
      payload.auth_time > now ||
      (payload.nbf !== undefined &&
        (!Number.isFinite(payload.nbf) || payload.nbf > now))
    )
      invalid();
    if (clock() >= expires) await refresh();
    if (!keys.has(header.kid) && clock() - lastRefresh >= 30000)
      await refresh();
    const key = keys.get(header.kid);
    if (!key) invalid();
    let valid = false;
    try {
      valid = await crypto.subtle.verify(
        "RSASSA-PKCS1-v1_5",
        key,
        unbase64(parts[2]),
        encoder.encode(`${parts[0]}.${parts[1]}`),
      );
    } catch {
      invalid();
    }
    if (!valid) invalid();
    return payload.sub;
  };
}
export function googleAccessToken({
  fetchImpl = fetch,
  clock = Date.now,
} = {}) {
  let access,
    expiry = 0,
    pending;
  return async (secret) => {
    if (access && clock() < expiry) return access;
    if (pending) return pending;
    pending = (async () => {
      const account = JSON.parse(secret);
      if (
        account.project_id !== "orglink-dev" ||
        typeof account.client_email !== "string" ||
        !account.private_key
      )
        throw new Error("Invalid service account configuration.");
      const pem = account.private_key
        .replace(/-----[^-]+-----/g, "")
        .replace(/\s/g, "");
      const key = await crypto.subtle.importKey(
        "pkcs8",
        unbase64(pem),
        { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
        false,
        ["sign"],
      );
      const now = Math.floor(clock() / 1000);
      const header = base64url(
        encoder.encode(JSON.stringify({ alg: "RS256", typ: "JWT" })),
      );
      const body = base64url(
        encoder.encode(
          JSON.stringify({
            iss: account.client_email,
            scope: "https://www.googleapis.com/auth/datastore",
            aud: "https://oauth2.googleapis.com/token",
            iat: now,
            exp: now + 3600,
          }),
        ),
      );
      const input = `${header}.${body}`;
      const signature = base64url(
        new Uint8Array(
          await crypto.subtle.sign(
            "RSASSA-PKCS1-v1_5",
            key,
            encoder.encode(input),
          ),
        ),
      );
      const response = await fetchImpl("https://oauth2.googleapis.com/token", {
        method: "POST",
        redirect: "error",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({
          grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
          assertion: `${input}.${signature}`,
        }),
        signal: AbortSignal.timeout(8000),
      });
      if (!response.ok) {
        await response.body?.cancel();
        throw new Error("Server credentials unavailable.");
      }
      const data = await response.json();
      if (
        typeof data.access_token !== "string" ||
        !Number.isFinite(data.expires_in) ||
        data.expires_in <= 60
      )
        throw new Error("Invalid OAuth response.");
      access = data.access_token;
      expiry = clock() + (data.expires_in - 60) * 1000;
      return access;
    })();
    try {
      return await pending;
    } finally {
      pending = undefined;
    }
  };
}
