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
      assert.equal(options.redirect, "manual");
      assert.ok(options.signal instanceof AbortSignal);
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
      assert.equal(options.redirect, "manual");
      assert.ok(options.signal instanceof AbortSignal);
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
      assert.equal(options.redirect, "manual");
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

test("every Firestore REST operation rejects redirects without forwarding credentials or retrying", async () => {
  for (const method of ["beginTransaction", "batchGet", "commit", "rollback"]) {
    for (const status of [301, 302, 303, 307, 308]) {
      let calls = 0,
        cancelled = false;
      const store = new RestFirestore(async () => "DO_NOT_LOG_ACCESS_TOKEN", {
        fetchImpl: async (url, options) => {
          calls++;
          assert.equal(
            url,
            `https://firestore.googleapis.com/v1/projects/orglink-dev/databases/(default)/documents:${method}`,
          );
          assert.equal(options.redirect, "manual");
          assert.equal(
            options.headers.Authorization,
            "Bearer DO_NOT_LOG_ACCESS_TOKEN",
          );
          assert.ok(options.signal instanceof AbortSignal);
          return new Response(
            new ReadableStream({
              cancel() {
                cancelled = true;
              },
            }),
            {
              status,
              headers: {
                Location: "https://untrusted.test/DO_NOT_LOG_DESTINATION",
              },
            },
          );
        },
      });
      await assert.rejects(
        store.call(method, { transaction: "DO_NOT_LOG_TRANSACTION" }),
        (error) => {
          assert.ok(error instanceof RestError);
          assert.equal(error.stage, `firestore.${method}`);
          assert.equal(error.reason, "http-error");
          assert.equal(error.status, status);
          assert.equal(error.upstreamStatus, status);
          assert.equal(JSON.stringify(error).includes("DO_NOT_LOG"), false);
          return true;
        },
      );
      assert.equal(calls, 1);
      assert.equal(cancelled, true);
    }
  }
});

test("redirected transaction commits fail closed, roll back, and never retry as success", async () => {
  const methods = [];
  const store = new RestFirestore(async () => "oauth", {
    fetchImpl: async (url, options) => {
      assert.equal(options.redirect, "manual");
      const method = url.split(":").at(-1);
      methods.push(method);
      if (method === "beginTransaction")
        return Response.json({ transaction: "tx" });
      assert.equal(JSON.parse(options.body).transaction, "tx");
      return new Response(null, {
        status: 307,
        headers: { Location: "https://untrusted.test" },
      });
    },
  });
  await assert.rejects(
    store.runTransaction(async (t) => {
      t.create(store.doc("attendance/student"), {
        attendanceStatus: "present",
      });
      return "must-not-return";
    }),
    (error) => error.stage === "firestore.commit" && error.status === 307,
  );
  assert.deepEqual(methods, ["beginTransaction", "commit", "rollback"]);
});

async function testAccountSecret() {
  const key = await crypto.subtle.exportKey("pkcs8", fixture.pair.privateKey);
  return JSON.stringify({
    project_id: "orglink-dev",
    client_email: "DO_NOT_LOG_ACCOUNT",
    private_key: `-----BEGIN PRIVATE KEY-----\n${btoa(String.fromCharCode(...new Uint8Array(key)))}\n-----END PRIVATE KEY-----`,
  });
}
const failureCases = [
  {
    label: "missing binding",
    secret: undefined,
    stage: "service-account",
    reason: "missing-secret",
  },
  {
    label: "blank binding",
    secret: " ",
    stage: "service-account",
    reason: "missing-secret",
  },
  {
    label: "malformed JSON",
    secret: "DO_NOT_LOG_SECRET",
    stage: "service-account",
    reason: "invalid-secret-json",
  },
  {
    label: "JSON null",
    secret: "null",
    stage: "service-account",
    reason: "invalid-secret-fields",
  },
  {
    label: "double-encoded JSON",
    secret: JSON.stringify('{"project_id":"orglink-dev"}'),
    stage: "service-account",
    reason: "invalid-secret-fields",
  },
  {
    label: "wrong project",
    secret: '{"project_id":"other-project"}',
    stage: "service-account",
    reason: "invalid-secret-fields",
  },
  {
    label: "non-string key",
    secret:
      '{"project_id":"orglink-dev","client_email":"DO_NOT_LOG_ACCOUNT","private_key":42}',
    stage: "service-account",
    reason: "invalid-secret-fields",
  },
  {
    label: "invalid PEM",
    secret:
      '{"project_id":"orglink-dev","client_email":"DO_NOT_LOG_ACCOUNT","private_key":"DO_NOT_LOG_KEY"}',
    stage: "service-account",
    reason: "invalid-private-key",
  },
  {
    label: "key fetch transport",
    fault: "keys-network",
    stage: "firebase-keys",
    reason: "transport-error",
  },
  {
    label: "key fetch HTTP",
    fault: "keys-http",
    stage: "firebase-keys",
    reason: "http-error",
    upstreamStatus: 503,
  },
  {
    label: "key response malformed",
    fault: "keys-json",
    stage: "firebase-keys",
    reason: "invalid-key-response",
  },
  {
    label: "OAuth transport",
    fault: "oauth-network",
    stage: "oauth",
    reason: "transport-error",
  },
  {
    label: "OAuth timeout",
    fault: "oauth-timeout",
    stage: "oauth",
    reason: "timeout",
  },
  {
    label: "OAuth rejected grant",
    fault: "oauth-http",
    stage: "oauth",
    reason: "http-error",
    upstreamStatus: 400,
  },
  {
    label: "OAuth response malformed",
    fault: "oauth-json",
    stage: "oauth",
    reason: "invalid-response",
  },
  {
    label: "OAuth response fields invalid",
    fault: "oauth-fields",
    stage: "oauth",
    reason: "invalid-response",
  },
  {
    label: "Firestore IAM rejection",
    fault: "firestore-http",
    stage: "firestore.beginTransaction",
    reason: "http-error",
    upstreamStatus: 403,
  },
  {
    label: "Firestore transport",
    fault: "firestore-network",
    stage: "firestore.beginTransaction",
    reason: "transport-error",
  },
  {
    label: "Firestore timeout",
    fault: "firestore-timeout",
    stage: "firestore.beginTransaction",
    reason: "timeout",
  },
  {
    label: "Firestore JSON malformed",
    fault: "firestore-json",
    stage: "firestore.beginTransaction",
    reason: "invalid-json-response",
  },
];
for (const scenario of failureCases)
  test(`503 diagnostics: ${scenario.label} is classified without sensitive data`, async () => {
    const token = await fixture.sign();
    const logs = [];
    const secret = Object.hasOwn(scenario, "secret")
      ? scenario.secret
      : await testAccountSecret();
    const handler = createHandler({
      clock: () => now,
      logFailure: (entry) => logs.push(entry),
      fetchImpl: async (url, options) => {
        if (url.includes("service_accounts/v1/jwk/")) {
          if (scenario.fault === "keys-network")
            throw Error("DO_NOT_LOG_PRIVATE_ERROR");
          if (scenario.fault === "keys-http")
            return new Response("DO_NOT_LOG_UPSTREAM_BODY", { status: 503 });
          if (scenario.fault === "keys-json")
            return new Response("DO_NOT_LOG_UPSTREAM_BODY");
          return fixture.fetchKeys(url, options);
        }
        if (url === "https://oauth2.googleapis.com/token") {
          if (scenario.fault === "oauth-network")
            throw Error("DO_NOT_LOG_PRIVATE_ERROR");
          if (scenario.fault === "oauth-timeout")
            throw new DOMException("DO_NOT_LOG_PRIVATE_ERROR", "TimeoutError");
          if (scenario.fault === "oauth-http")
            return Response.json(
              {
                error: "invalid_grant",
                error_description: "DO_NOT_LOG_ACCOUNT",
              },
              { status: 400 },
            );
          if (scenario.fault === "oauth-json")
            return new Response("DO_NOT_LOG_UPSTREAM_BODY");
          if (scenario.fault === "oauth-fields")
            return Response.json({
              access_token: "DO_NOT_LOG_ACCESS_TOKEN",
              expires_in: null,
            });
          return Response.json({
            access_token: "DO_NOT_LOG_ACCESS_TOKEN",
            expires_in: 3600,
          });
        }
        assert.match(url, /^https:\/\/firestore\.googleapis\.com\//);
        if (scenario.fault === "firestore-network")
          throw Error("DO_NOT_LOG_PRIVATE_ERROR");
        if (scenario.fault === "firestore-timeout")
          throw new DOMException("DO_NOT_LOG_PRIVATE_ERROR", "TimeoutError");
        if (scenario.fault === "firestore-json")
          return new Response("DO_NOT_LOG_UPSTREAM_BODY");
        return new Response("DO_NOT_LOG_UPSTREAM_BODY", { status: 403 });
      },
    });
    const response = await handler(
      new Request("https://worker.test/issue", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          organizationId: "DO_NOT_LOG_ORGANIZATION",
          eventId: "DO_NOT_LOG_EVENT",
          fullName: "DO_NOT_LOG_PERSON",
        }),
      }),
      { FIREBASE_SERVICE_ACCOUNT: secret },
    );
    assert.equal(response.status, 503);
    const body = await response.json();
    assert.equal(body.error.code, "unavailable");
    assert.deepEqual(logs, [
      {
        event: "attendance_backend_failure",
        endpoint: "issue",
        stage: scenario.stage,
        code: "unavailable",
        reason: scenario.reason,
        ...(scenario.upstreamStatus
          ? { upstreamStatus: scenario.upstreamStatus }
          : {}),
        ...([
          "keys-network",
          "oauth-network",
          "oauth-timeout",
          "firestore-network",
          "firestore-timeout",
        ].includes(scenario.fault)
          ? {
              errorName: scenario.fault.endsWith("-timeout")
                ? "TimeoutError"
                : "Error",
            }
          : {}),
      },
    ]);
    const serialized = JSON.stringify({ logs, body });
    assert.equal(serialized.includes("DO_NOT_LOG"), false);
    assert.equal(serialized.includes(token), false);
    assert.equal(serialized.includes("PRIVATE KEY"), false);
  });

test("JWKS fetch rejection logs only allowlisted runtime name and code", async () => {
  const cases = [
    [new TypeError("DO_NOT_LOG_PRIVATE_ERROR"), "TypeError", undefined],
    [
      Object.assign(new Error("DO_NOT_LOG_PRIVATE_ERROR"), {
        code: "ECONNRESET",
      }),
      "Error",
      "ECONNRESET",
    ],
    [
      new TypeError("DO_NOT_LOG_PRIVATE_ERROR", {
        cause: { code: "ENOTFOUND", message: "DO_NOT_LOG_CAUSE" },
      }),
      "TypeError",
      "ENOTFOUND",
    ],
    [
      new DOMException("DO_NOT_LOG_PRIVATE_ERROR", "TimeoutError"),
      "TimeoutError",
      undefined,
    ],
    [
      new DOMException("DO_NOT_LOG_PRIVATE_ERROR", "AbortError"),
      "AbortError",
      undefined,
    ],
    [
      {
        name: "DO_NOT_LOG_NAME",
        code: "DO_NOT_LOG_CODE",
        cause: { code: "DO_NOT_LOG_CAUSE" },
      },
      "UnknownError",
      undefined,
    ],
  ];
  for (const [error, errorName, runtimeCode] of cases) {
    const logs = [];
    let calls = 0;
    const handler = createHandler({
      clock: () => now,
      logFailure: (entry) => logs.push(entry),
      fetchImpl: async (_url, options) => {
        calls++;
        assert.equal(options.redirect, "manual");
        throw error;
      },
    });
    const response = await handler(
      new Request("https://worker.test/issue", {
        method: "POST",
        headers: { Authorization: `Bearer ${await fixture.sign()}` },
      }),
      {},
    );
    assert.equal(response.status, 503);
    assert.equal(calls, 1); // No OAuth or Firestore access after key retrieval fails.
    assert.deepEqual(logs, [
      {
        event: "attendance_backend_failure",
        endpoint: "issue",
        stage: "firebase-keys",
        code: "unavailable",
        reason: errorName === "TimeoutError" ? "timeout" : "transport-error",
        errorName,
        ...(runtimeCode ? { runtimeCode } : {}),
      },
    ]);
    assert.equal(JSON.stringify(logs).includes("DO_NOT_LOG"), false);
    const body = await response.text();
    assert.equal(body.includes("DO_NOT_LOG"), false);
    assert.equal(body.includes("errorName"), false);
  }
});

test("Firestore transport diagnostics allowlist names and runtime codes without leaking upstream details", async () => {
  for (const [failure, errorName, runtimeCode] of [
    [
      new TypeError("DO_NOT_LOG_MESSAGE", {
        cause: { code: "ECONNRESET", message: "DO_NOT_LOG_CAUSE" },
      }),
      "TypeError",
      "ECONNRESET",
    ],
    [
      new DOMException("DO_NOT_LOG_MESSAGE", "AbortError"),
      "AbortError",
      undefined,
    ],
    [
      { name: "DO_NOT_LOG_NAME", code: "DO_NOT_LOG_CODE" },
      "UnknownError",
      undefined,
    ],
  ]) {
    const logs = [];
    const handler = createHandler({
      clock: () => now,
      logFailure: (entry) => logs.push(entry),
      fetchImpl: async (url, options) => {
        if (url.includes("service_accounts/v1/jwk/"))
          return fixture.fetchKeys(url, options);
        if (url === "https://oauth2.googleapis.com/token")
          return Response.json({
            access_token: "DO_NOT_LOG_ACCESS_TOKEN",
            expires_in: 3600,
          });
        throw failure;
      },
    });
    const response = await handler(
      new Request("https://worker.test/issue", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${await fixture.sign()}`,
          "Content-Type": "application/json",
        },
        body: '{"organizationId":"DO_NOT_LOG_ORGANIZATION","eventId":"DO_NOT_LOG_EVENT"}',
      }),
      { FIREBASE_SERVICE_ACCOUNT: await testAccountSecret() },
    );
    assert.equal(response.status, 503);
    assert.deepEqual(logs, [
      {
        event: "attendance_backend_failure",
        endpoint: "issue",
        stage: "firestore.beginTransaction",
        code: "unavailable",
        reason: "transport-error",
        errorName,
        ...(runtimeCode ? { runtimeCode } : {}),
      },
    ]);
    assert.equal(JSON.stringify(logs).includes("DO_NOT_LOG"), false);
    const body = await response.text();
    assert.equal(body.includes("DO_NOT_LOG"), false);
    assert.equal(body.includes("errorName"), false);
  }
});

test("JWKS and OAuth redirects fail closed without following Location", async () => {
  let keyCalls = 0;
  const verify = firebaseVerifier({
    clock: () => now,
    fetchImpl: async (_url, options) => {
      keyCalls++;
      assert.equal(options.redirect, "manual");
      return new Response(null, {
        status: 302,
        headers: { Location: "https://untrusted.test" },
      });
    },
  });
  await assert.rejects(
    verify(`Bearer ${await fixture.sign()}`),
    (error) =>
      error.stage === "firebase-keys" &&
      error.reason === "http-error" &&
      error.upstreamStatus === 302,
  );
  assert.equal(keyCalls, 1);
  let oauthCalls = 0;
  const access = googleAccessToken({
    clock: () => now,
    fetchImpl: async (_url, options) => {
      oauthCalls++;
      assert.equal(options.redirect, "manual");
      return new Response(null, {
        status: 307,
        headers: { Location: "https://untrusted.test" },
      });
    },
  });
  await assert.rejects(
    access(await testAccountSecret()),
    (error) =>
      error.stage === "oauth" &&
      error.reason === "http-error" &&
      error.upstreamStatus === 307,
  );
  assert.equal(oauthCalls, 1);
});
test("503 diagnostics classify signing failure and logging failures cannot change fail-closed response", async (t) => {
  const token = await fixture.sign(),
    secret = await testAccountSecret(),
    logs = [];
  t.mock.method(crypto.subtle, "sign", async () => {
    throw Error("DO_NOT_LOG_PRIVATE_ERROR");
  });
  const handler = createHandler({
    fetchImpl: fixture.fetchKeys,
    clock: () => now,
    logFailure: (entry) => {
      logs.push(entry);
      throw Error("DO_NOT_LOG_LOGGER");
    },
  });
  const response = await handler(
    new Request("https://worker.test/issue", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: '{"organizationId":"public","eventId":"demo"}',
    }),
    { FIREBASE_SERVICE_ACCOUNT: secret },
  );
  assert.equal(response.status, 503);
  assert.equal(logs[0].stage, "oauth");
  assert.equal(logs[0].reason, "sign-failed");
  assert.equal((await response.text()).includes("DO_NOT_LOG"), false);
});
test("invalid Firebase tokens still return 401 without privileged access or 503 diagnostics", async () => {
  const logs = [];
  const handler = createHandler({
    logFailure: (entry) => logs.push(entry),
    fetchImpl: async () => {
      throw Error("Unexpected privileged fetch.");
    },
  });
  const response = await handler(
    new Request("https://worker.test/issue", {
      method: "POST",
      headers: { Authorization: "Bearer not-a-token" },
    }),
    {},
  );
  assert.equal(response.status, 401);
  assert.equal((await response.json()).error.code, "unauthenticated");
  assert.deepEqual(logs, []);
});
test("Firestore read and commit failures retain their exact operation and HTTP code", async () => {
  for (const method of ["batchGet", "commit"]) {
    const store = new RestFirestore(async () => "DO_NOT_LOG_ACCESS_TOKEN", {
      fetchImpl: async (url) => {
        const operation = url.split(":").at(-1);
        if (operation === method)
          return new Response("DO_NOT_LOG_UPSTREAM_BODY", { status: 403 });
        if (operation === "beginTransaction")
          return Response.json({ transaction: "DO_NOT_LOG_TRANSACTION" });
        if (operation === "batchGet") return Response.json([]);
        // A failed rollback must never replace the original error.
        return new Response("DO_NOT_LOG_UPSTREAM_BODY", { status: 500 });
      },
    });
    await assert.rejects(
      store.runTransaction(async (t) => {
        await t.getAll(store.doc("users/DO_NOT_LOG_PERSON"));
      }),
      (error) => {
        assert.equal(error.stage, `firestore.${method}`);
        assert.equal(error.reason, "http-error");
        assert.equal(error.status, 403);
        assert.equal(error.upstreamStatus, 403);
        return true;
      },
    );
  }
});

test("invalid emulator configuration has a distinct sanitized 503 reason", async () => {
  const logs = [];
  const handler = createHandler({
    fetchImpl: fixture.fetchKeys,
    clock: () => now,
    logFailure: (e) => logs.push(e),
  });
  const response = await handler(
    new Request("https://worker.test/issue", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${await fixture.sign()}`,
        "Content-Type": "application/json",
      },
      body: '{"organizationId":"public","eventId":"demo"}',
    }),
    { FIRESTORE_EMULATOR_HOST: "DO_NOT_LOG_REMOTE_HOST" },
  );
  assert.equal(response.status, 503);
  assert.deepEqual(logs, [
    {
      event: "attendance_backend_failure",
      endpoint: "issue",
      stage: "configuration",
      code: "unavailable",
      reason: "invalid-emulator-host",
    },
  ]);
});
test("unexpected attendance data errors remain sanitized and retain the backend stage", async () => {
  const logs = [],
    secret = await testAccountSecret();
  const stamp = (ms) => ({ timestampValue: new Date(ms).toISOString() });
  const string = (value) => ({ stringValue: value });
  const fields = [
    {
      accountStatus: string("active"),
      fullName: string("DO_NOT_LOG_PERSON"),
      studentNumber: string("DEMO-001"),
      yearLevel: { integerValue: "1" },
      section: string("A"),
    },
    { status: string("active") },
    {
      eventId: string("demo"),
      organizationId: string("public"),
      eventStatus: string("published"),
      approvalStatus: string("approved"),
      publishedAt: stamp(now - 7200000),
      startAt: stamp(now - 3600000),
      endAt: stamp(now + 3600000),
      archivedAt: { nullValue: null },
    },
    {
      uid: string("student"),
      organizationId: string("public"),
      eventId: string("demo"),
      registrationStatus: string("registered"),
    },
    null,
    { issuedAt: string("DO_NOT_LOG_MALFORMED_DATA") },
  ];
  const handler = createHandler({
    clock: () => now,
    logFailure: (e) => logs.push(e),
    fetchImpl: async (url, options) => {
      if (url.includes("service_accounts/v1/jwk/"))
        return fixture.fetchKeys(url, options);
      if (url === "https://oauth2.googleapis.com/token")
        return Response.json({
          access_token: "DO_NOT_LOG_ACCESS_TOKEN",
          expires_in: 3600,
        });
      if (url.endsWith(":beginTransaction"))
        return Response.json({ transaction: "DO_NOT_LOG_TRANSACTION" });
      if (url.endsWith(":batchGet")) {
        const body = JSON.parse(options.body);
        return Response.json(
          body.documents.map((name, i) =>
            fields[i]
              ? { found: { name, fields: fields[i] } }
              : { missing: name },
          ),
        );
      }
      assert.ok(url.endsWith(":rollback"));
      return Response.json({});
    },
  });
  const response = await handler(
    new Request("https://worker.test/issue", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${await fixture.sign()}`,
        "Content-Type": "application/json",
      },
      body: '{"organizationId":"public","eventId":"demo"}',
    }),
    { FIREBASE_SERVICE_ACCOUNT: secret },
  );
  assert.equal(response.status, 503);
  assert.deepEqual(logs, [
    {
      event: "attendance_backend_failure",
      endpoint: "issue",
      stage: "attendance.issue",
      code: "unavailable",
      reason: "unexpected-error",
    },
  ]);
  assert.equal(JSON.stringify(logs).includes("DO_NOT_LOG"), false);
});

for (const verified of [false, true]) {
  test(`password credentials require verified email (${verified})`, async () => {
    const verify=firebaseVerifier({clock:()=>now,fetchImpl:fixture.fetchKeys});
    const credential=`Bearer ${await fixture.sign('student',{firebase:{sign_in_provider:'password'},email_verified:verified})}`;
    if (verified) assert.equal(await verify(credential),'student');
    else await assert.rejects(verify(credential),denied);
  });
}
