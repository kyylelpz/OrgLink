import { test, before } from "node:test";
import assert from "node:assert/strict";
import { firebaseVerifier, googleAccessToken } from "../src/auth.js";
import { createHandler } from "../src/index.js";
import { RestFirestore, RestError } from "../src/firestore.js";
import { tokenFixture } from "./token-fixture.js";
let fixture;
const now = Date.now();
before(async () => {
  fixture = await tokenFixture(() => now);
});
const denied = (e) => e.code === "unauthenticated";
test("RS256 Firebase ID token: verifies signature, fixed trusted keys and cached keys", async () => {
  let calls = 0;
  const verify = firebaseVerifier({
    clock: () => now,
    fetchImpl: async (url, options) => {
      assert.equal(
        url,
        "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com",
      );
      calls++;
      return fixture.fetchKeys(url, options);
    },
  });
  const token = await fixture.sign();
  assert.equal(await verify(`Bearer ${token}`), "student");
  assert.equal(await verify(`Bearer ${token}`), "student");
  assert.equal(calls, 1);
  const parts = token.split(".");
  parts[2] = (parts[2][0] === "a" ? "b" : "a") + parts[2].slice(1);
  await assert.rejects(verify(`Bearer ${parts.join(".")}`), denied);
});
for (const changes of [
  { aud: "other-project" },
  { iss: "https://attacker.test" },
  { sub: "" },
  { sub: "student/other" },
  { exp: Math.floor(now / 1000) },
  { iat: Math.ceil(now / 1000) + 100 },
  { auth_time: Math.ceil(now / 1000) + 100 },
  { auth_time: undefined },
  { nbf: Math.ceil(now / 1000) + 100 },
])
  test(`reject invalid signed token claims ${JSON.stringify(changes)}`, async () => {
    const verify = firebaseVerifier({
      clock: () => now,
      fetchImpl: fixture.fetchKeys,
    });
    await assert.rejects(
      verify(`Bearer ${await fixture.sign("student", changes)}`),
      denied,
    );
  });
test("reject unsigned, wrong algorithm, attacker keys and unknown kid", async () => {
  const verify = firebaseVerifier({
    clock: () => now,
    fetchImpl: fixture.fetchKeys,
  });
  for (const raw of [
    undefined,
    "Bearer unsigned.payload.",
    "Basic credentials",
    `Bearer ${await fixture.sign("student", {}, { alg: "HS256" })}`,
    `Bearer ${await fixture.sign("student", {}, { kid: "attacker" })}`,
  ])
    await assert.rejects(verify(raw), denied);
  const attacker = await tokenFixture(() => now);
  await assert.rejects(verify(`Bearer ${await attacker.sign()}`), denied);
});
test("key rotation refreshes unknown kid after cooldown and never falls back if fetch fails", async () => {
  const next = await tokenFixture(() => now);
  next.jwk.kid = "rotated";
  let clock = now,
    rotated = false;
  const verify = firebaseVerifier({
    clock: () => clock,
    fetchImpl: async () =>
      Response.json(
        { keys: rotated ? [next.jwk] : [fixture.jwk] },
        { headers: { "Cache-Control": "max-age=3600" } },
      ),
  });
  await verify(`Bearer ${await fixture.sign()}`);
  clock += 31000;
  rotated = true;
  assert.equal(
    await verify(
      `Bearer ${await next.sign("student", {}, { kid: "rotated" })}`,
    ),
    "student",
  );
  const unavailable = firebaseVerifier({
    clock: () => now,
    fetchImpl: async () => new Response("", { status: 503 }),
  });
  await assert.rejects(unavailable(`Bearer ${await fixture.sign()}`));
});
test("service account OAuth uses Web Crypto JWT assertion, fixed endpoint, datastore scope and token caching", async () => {
  const exported = await crypto.subtle.exportKey(
    "pkcs8",
    fixture.pair.privateKey,
  );
  const key = `-----BEGIN PRIVATE KEY-----\n${btoa(String.fromCharCode(...new Uint8Array(exported)))}\n-----END PRIVATE KEY-----`;
  const secret = JSON.stringify({
    project_id: "orglink-dev",
    client_email: "worker@orglink-dev.iam.gserviceaccount.com",
    private_key: key,
    token_uri: "https://attacker.test",
  });
  let calls = 0;
  const access = googleAccessToken({
    clock: () => now,
    fetchImpl: async (url, options) => {
      calls++;
      assert.equal(url, "https://oauth2.googleapis.com/token");
      const assertion = new URLSearchParams(options.body).get("assertion");
      const [h, p, s] = assertion.split(".");
      const claims = JSON.parse(
        atob(p.replaceAll("-", "+").replaceAll("_", "/")),
      );
      assert.equal(claims.iss, "worker@orglink-dev.iam.gserviceaccount.com");
      assert.equal(claims.aud, url);
      assert.equal(claims.scope, "https://www.googleapis.com/auth/datastore");
      const signature = Uint8Array.from(
        atob(s.replaceAll("-", "+").replaceAll("_", "/")),
        (c) => c.charCodeAt(0),
      );
      assert.equal(
        await crypto.subtle.verify(
          "RSASSA-PKCS1-v1_5",
          fixture.pair.publicKey,
          signature,
          new TextEncoder().encode(`${h}.${p}`),
        ),
        true,
      );
      return Response.json({
        access_token: "test-oauth-access",
        expires_in: 3600,
      });
    },
  });
  assert.equal(await access(secret), "test-oauth-access");
  assert.equal(await access(secret), "test-oauth-access");
  assert.equal(calls, 1);
  await assert.rejects(googleAccessToken()('{"project_id":"other"}'));
});
test("HTTP gateway authenticates before privileged access and does not expose credential details", async () => {
  const handler = createHandler({
    fetchImpl: fixture.fetchKeys,
    clock: () => now,
  });
  const missing = await handler(
    new Request("https://worker.example/issue", { method: "POST" }),
    {},
  );
  assert.equal(missing.status, 401);
  const unknown = await handler(
    new Request("https://worker.example/arbitrary-firestore-path"),
    {},
  );
  assert.equal(unknown.status, 404);
  const header = {
    Authorization: `Bearer ${await fixture.sign()}`,
    "Content-Type": "application/json",
  };
  const invalid = await handler(
    new Request("https://worker.example/issue", {
      method: "POST",
      headers: header,
      body: "x".repeat(8193),
    }),
    {},
  );
  assert.equal(invalid.status, 400);
  const badConfiguration = await handler(
    new Request("https://worker.example/issue", {
      method: "POST",
      headers: header,
      body: "{}",
    }),
    { FIREBASE_SERVICE_ACCOUNT: "secret-invalid-key" },
  );
  assert.equal(badConfiguration.status, 400); // Missing path IDs are rejected before credentials are accessed.
  const unavailable = await handler(
    new Request("https://worker.example/issue", {
      method: "POST",
      headers: header,
      body: '{"organizationId":"public","eventId":"demo"}',
    }),
    { FIREBASE_SERVICE_ACCOUNT: "secret-invalid-key" },
  );
  assert.equal(unavailable.status, 503);
  assert.equal(
    (await unavailable.text()).includes("secret-invalid-key"),
    false,
  );
});
test("REST transactions retry conflicts, bind every read to a transaction, and never use non-atomic batchWrite", async () => {
  let commits = 0,
    reads = 0;
  const methods = [];
  const store = new RestFirestore(async () => "oauth", {
    fetchImpl: async (url, options) => {
      const method = url.split(":").at(-1),
        body = JSON.parse(options.body);
      methods.push(method);
      assert.equal(options.headers.Authorization, "Bearer oauth");
      if (method === "beginTransaction") {
        assert.equal(
          body.options.readWrite.retryTransaction,
          commits ? "tx0" : undefined,
        );
        return Response.json({ transaction: `tx${commits}` });
      }
      if (method === "batchGet") {
        reads++;
        assert.ok(body.transaction);
        return Response.json([{ missing: body.documents[0] }]);
      }
      if (method === "rollback") return Response.json({});
      if (method === "commit") {
        commits++;
        assert.ok(body.transaction);
        assert.equal(body.writes[0].currentDocument.exists, false);
        return commits === 1
          ? new Response("{}", { status: 409 })
          : Response.json({});
      }
      throw Error("Unexpected REST method.");
    },
  });
  await store.runTransaction(async (t) => {
    const ref = store.doc("collection/id");
    await t.getAll(ref);
    t.create(ref, { status: "present" });
  });
  assert.equal(commits, 2);
  assert.equal(reads, 2);
  assert.equal(methods.includes("batchWrite"), false);
});
test("ambiguous network commit failure never retries a write as success", async () => {
  let commits = 0;
  const store = new RestFirestore(async () => "oauth", {
    fetchImpl: async (url) => {
      const method = url.split(":").at(-1);
      if (method === "beginTransaction")
        return Response.json({ transaction: "tx" });
      if (method === "rollback") return Response.json({});
      commits++;
      throw Error("Connection lost after commit.");
    },
  });
  await assert.rejects(store.runTransaction(async () => 42));
  assert.equal(commits, 1);
});
