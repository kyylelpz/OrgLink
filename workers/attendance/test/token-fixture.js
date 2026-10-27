import { base64url } from "../src/attendance.js";
export async function tokenFixture(clock = Date.now) {
  const pair = await crypto.subtle.generateKey(
    {
      name: "RSASSA-PKCS1-v1_5",
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: "SHA-256",
    },
    true,
    ["sign", "verify"],
  );
  const jwk = {
    ...(await crypto.subtle.exportKey("jwk", pair.publicKey)),
    kid: "test-key",
    use: "sig",
    alg: "RS256",
  };
  const sign = async (uid = "student", changes = {}, header = {}) => {
    const now = Math.floor(clock() / 1000),
      encoder = new TextEncoder();
    const h = base64url(
      encoder.encode(JSON.stringify({ alg: "RS256", kid: jwk.kid, ...header })),
    );
    const p = base64url(
      encoder.encode(
        JSON.stringify({
          sub: uid,
          aud: "orglink-dev",
          iss: "https://securetoken.google.com/orglink-dev",
          iat: now,
          auth_time: now,
          exp: now + 3600,
          ...changes,
        }),
      ),
    );
    const input = `${h}.${p}`;
    return `${input}.${base64url(new Uint8Array(await crypto.subtle.sign("RSASSA-PKCS1-v1_5", pair.privateKey, encoder.encode(input))))}`;
  };
  const fetchKeys = async (url, options) => {
    if (
      url ===
      "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com"
    )
      return Response.json(
        { keys: [jwk] },
        { headers: { "Cache-Control": "max-age=3600" } },
      );
    return fetch(url, options);
  };
  return { sign, fetchKeys, pair, jwk };
}
