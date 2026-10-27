import { base64url, AttendanceError } from "./attendance.js";
import { BackendError, TransportError } from "./firestore.js";
const JWKS_URL =
  "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com";
const encoder = new TextEncoder();
export class AuthFetchError extends TransportError {}

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
      let response;
      try {
        response = await fetchImpl(JWKS_URL, {
          // Workers rejects redirect: "error" at construction. Never follow redirects.
          redirect: "manual",
          signal: AbortSignal.timeout(5000),
        });
      } catch (error) {
        throw new AuthFetchError("firebase-keys", error);
      }
      if (!response.ok) {
        try {
          await response.body?.cancel();
        } catch {
          /* Keep the HTTP failure. */
        }
        throw new BackendError("firebase-keys", "http-error", response.status);
      }
      try {
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
      } catch {
        throw new BackendError("firebase-keys", "invalid-key-response");
      }
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
      if (typeof secret !== "string" || !secret.trim()) {
        throw new BackendError("service-account", "missing-secret");
      }
      let account;
      try {
        account = JSON.parse(secret);
      } catch {
        throw new BackendError("service-account", "invalid-secret-json");
      }
      if (
        account?.project_id !== "orglink-dev" ||
        typeof account.client_email !== "string" ||
        !account.client_email.trim() ||
        typeof account.private_key !== "string" ||
        !account.private_key.trim()
      )
        throw new BackendError("service-account", "invalid-secret-fields");
      const pem = account.private_key
        .replace(/-----[^-]+-----/g, "")
        .replace(/\s/g, "");
      let key;
      try {
        key = await crypto.subtle.importKey(
          "pkcs8",
          unbase64(pem),
          { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
          false,
          ["sign"],
        );
      } catch {
        throw new BackendError("service-account", "invalid-private-key");
      }
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
      let signature;
      try {
        signature = base64url(
          new Uint8Array(
            await crypto.subtle.sign(
              "RSASSA-PKCS1-v1_5",
              key,
              encoder.encode(input),
            ),
          ),
        );
      } catch {
        throw new BackendError("oauth", "sign-failed");
      }
      let response;
      try {
        response = await fetchImpl("https://oauth2.googleapis.com/token", {
          method: "POST",
          redirect: "manual",
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
          body: new URLSearchParams({
            grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
            assertion: `${input}.${signature}`,
          }),
          signal: AbortSignal.timeout(8000),
        });
      } catch (error) {
        throw new AuthFetchError("oauth", error);
      }
      if (!response.ok) {
        try {
          await response.body?.cancel();
        } catch {
          /* Keep the HTTP failure. */
        }
        throw new BackendError("oauth", "http-error", response.status);
      }
      let data;
      try {
        data = await response.json();
      } catch {
        throw new BackendError("oauth", "invalid-response");
      }
      if (
        typeof data?.access_token !== "string" ||
        !data.access_token ||
        !Number.isFinite(data.expires_in) ||
        data.expires_in <= 60
      )
        throw new BackendError("oauth", "invalid-response");
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
