const { test, before, after, beforeEach } = require("node:test");
const assert = require("node:assert/strict");
const { initializeApp, deleteApp } = require("firebase-admin/app");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const { attendanceBackend } = require("../attendance");
const { createRequire } = require("node:module");
const testRequire = createRequire(require.resolve("../../tests/package.json"));
const { initializeTestEnvironment } = testRequire(
  "@firebase/rules-unit-testing",
);
const { doc, setDoc, serverTimestamp } = testRequire("firebase/firestore");
const { readFileSync } = require("node:fs");
// Refuse to run against a live Firebase project, even with local ADC credentials.
if (!process.env.FIRESTORE_EMULATOR_HOST)
  throw Error("Firestore emulator is required.");
let app, db, backend, now, env;
const base = "organizations/public/events/demo";
const req = (uid = "student", data = {}) => ({
  auth: uid ? { uid } : undefined,
  data: { organizationId: "public", eventId: "demo", ...data },
});
const payload = (issued) => ({
  version: 1,
  type: "attendance",
  token: issued.token,
});
const seed = (path, data) => db.doc(path).set(data);
const update = (path, data) => db.doc(path).update(data);
const code = (expected) => (e) => {
  assert.equal(e.code, expected, e.message);
  return true;
};
before(async () => {
  app = initializeApp({ projectId: "orglink-dev" }, "attendance-tests");
  db = getFirestore(app);
  env = await initializeTestEnvironment({
    projectId: "orglink-dev",
    firestore: {
      rules: readFileSync(require.resolve("../../firebase.rules"), "utf8"),
    },
  });
});
after(async () => {
  await env?.cleanup();
  await db?.terminate();
  await deleteApp(app);
});
beforeEach(async () => {
  await env.clearFirestore();
  now = Date.now();
  backend = attendanceBackend(db, () => now);
  for (const uid of [
    "student",
    "otherStudent",
    "manager",
    "scanner",
    "coordinator",
    "other",
    "suspended",
  ])
    await seed(`users/${uid}`, {
      uid,
      fullName: "Demo Student",
      studentNumber: "DEMO-001",
      yearLevel: 1,
      section: "A",
      accountStatus: uid === "suspended" ? "suspended" : "active",
      platformRole: uid === "other" ? "platformAdmin" : "user",
    });
  await seed("organizations/public", {
    organizationId: "public",
    name: "Demo Organization",
    managerUid: "manager",
    status: "active",
    visibility: "public",
  });
  await seed(base, {
    eventId: "demo",
    organizationId: "public",
    title: "Demo Event",
    eventStatus: "published",
    approvalStatus: "approved",
    publishedAt: Timestamp.fromMillis(now - 7200000),
    archivedAt: null,
    startAt: Timestamp.fromMillis(now - 3600000),
    endAt: Timestamp.fromMillis(now + 3600000),
    registrationCount: 2,
  });
  for (const uid of ["student", "otherStudent"])
    await seed(`${base}/registrations/${uid}`, {
      uid,
      eventId: "demo",
      organizationId: "public",
      registrationStatus: "registered",
      registeredAt: Timestamp.fromMillis(now - 500000),
      updatedAt: Timestamp.fromMillis(now - 500000),
    });
  await seed(`${base}/participantIdentities/student`, {
    uid: "student",
    fullName: "McDonald de la Cruz",
    updatedAt: Timestamp.fromMillis(now),
  });
  for (const [uid, permissions] of Object.entries({
    scanner: { manageAttendance: true },
    coordinator: { manageEvents: true },
  }))
    await seed(`organizations/public/memberships/${uid}`, {
      uid,
      organizationId: "public",
      membershipStatus: "active",
      membershipRole: "officer",
      permissions,
    });
});
test("authenticated issuance binds requesting student; stores only a token hash; rate limit and regeneration", async () => {
  const issued = await backend.issue(req());
  assert.match(issued.token, /^[A-Za-z0-9_-]{43}$/);
  assert.equal(issued.expiresAt - now, 60000);
  const docs = await db.collection("_attendanceCredentials").get();
  assert.equal(docs.size, 1);
  assert.equal(docs.docs[0].data().uid, "student");
  assert.equal(
    JSON.stringify(docs.docs[0].data()).includes(issued.token),
    false,
  );
  await assert.rejects(backend.issue(req()), code("resource-exhausted"));
  now += 5001;
  const next = await backend.issue(req());
  assert.notEqual(next.token, issued.token);
  await assert.rejects(
    backend.redeem(req("manager", payload(issued))),
    code("invalid-argument"),
  );
  assert.equal((await db.collection("_attendanceCredentials").get()).size, 1);
});
test("deny unauthenticated, incomplete, suspended, unregistered and forged UID issuance", async () => {
  await assert.rejects(backend.issue(req(null)), code("unauthenticated"));
  await assert.rejects(
    backend.issue(req("suspended")),
    code("permission-denied"),
  );
  await assert.rejects(
    backend.issue(req("other", { uid: "student" })),
    code("failed-precondition"),
  );
  await update("users/student", { section: "" });
  await assert.rejects(backend.issue(req()), code("permission-denied"));
});
test("scanner redeems to exactly seven immutable fields and projection name; replay returns same result", async () => {
  const issued = await backend.issue(req());
  const result = await backend.redeem(req("scanner", payload(issued)));
  assert.equal(result.fullName, "McDonald de la Cruz");
  assert.equal(result.record.verifiedBy, "scanner");
  assert.equal(result.record.verificationMethod, "qr");
  assert.equal(result.duplicate, false);
  assert.equal(Object.keys(result.record).length, 7);
  assert.equal(result.record.uid, "student");
  const duplicate = await backend.redeem(req("manager", payload(issued)));
  assert.equal(duplicate.duplicate, true);
  assert.deepEqual(duplicate.record, result.record);
  assert.equal((await db.doc(base).get()).data().registrationCount, 2);
});
test("reject invalid token, unsupported payload, path and organization/event rebinding", async () => {
  const issued = await backend.issue(req());
  for (const changes of [
    { eventId: "other" },
    { organizationId: "other" },
    { token: "x".repeat(43) },
    { type: "other" },
    { version: 2 },
    { eventId: "../demo" },
  ]) {
    await assert.rejects(
      backend.redeem(req("manager", { ...payload(issued), ...changes })),
    );
  }
  assert.equal((await db.collection(`${base}/attendance`).get()).size, 0);
});
test("unauthorized students, event coordinators and platform admins cannot scan", async () => {
  const issued = await backend.issue(req());
  for (const uid of ["student", "coordinator", "other"])
    await assert.rejects(
      backend.redeem(req(uid, payload(issued))),
      code("permission-denied"),
    );
  await assert.rejects(
    backend.redeem(req(null, payload(issued))),
    code("unauthenticated"),
  );
});
test("expiry is enforced using server clock including exact 60-second boundary", async () => {
  const issued = await backend.issue(req());
  now = issued.expiresAt;
  await assert.rejects(
    backend.redeem(req("manager", payload(issued))),
    code("failed-precondition"),
  );
  assert.equal((await db.collection(`${base}/attendance`).get()).size, 0);
});
test("end of window caps token expiry; no issuance after event end or before start", async () => {
  await update(base, { endAt: Timestamp.fromMillis(now + 2000) });
  const issued = await backend.issue(req());
  assert.equal(issued.expiresAt, now + 2000);
  now += 2000;
  await assert.rejects(backend.redeem(req("manager", payload(issued))));
  await assert.rejects(backend.issue(req()));
  await update(base, {
    startAt: Timestamp.fromMillis(now + 10000),
    endAt: Timestamp.fromMillis(now + 20000),
  });
  await assert.rejects(backend.issue(req()));
});
for (const changes of [
  { eventStatus: "draft" },
  { eventStatus: "cancelled" },
  { eventStatus: "completed" },
  { approvalStatus: "pending" },
  { archivedAt: Timestamp.now() },
  { publishedAt: null },
])
  test(`lifecycle denial at issuance and redemption ${JSON.stringify(changes)}`, async () => {
    const issued = await backend.issue(req());
    await update(base, changes);
    await assert.rejects(backend.issue(req()));
    await assert.rejects(backend.redeem(req("manager", payload(issued))));
  });
test("permission revocation, registration cancellation and student suspension are rechecked at redemption", async () => {
  const issued = await backend.issue(req());
  await update("organizations/public/memberships/scanner", {
    "permissions.manageAttendance": false,
  });
  await assert.rejects(
    backend.redeem(req("scanner", payload(issued))),
    code("permission-denied"),
  );
  await update(`${base}/registrations/student`, {
    registrationStatus: "cancelled",
  });
  await assert.rejects(
    backend.redeem(req("manager", payload(issued))),
    code("failed-precondition"),
  );
  await update(`${base}/registrations/student`, {
    registrationStatus: "registered",
  });
  await update("users/student", { accountStatus: "suspended" });
  await assert.rejects(
    backend.redeem(req("manager", payload(issued))),
    code("failed-precondition"),
  );
});
test("two organizers concurrent redemption creates one result and consumes token once", async () => {
  const issued = await backend.issue(req());
  const results = await Promise.all(
    ["manager", "scanner"].map((uid) =>
      backend.redeem(req(uid, payload(issued))),
    ),
  );
  assert.equal(results.filter((r) => !r.duplicate).length, 1);
  assert.deepEqual(results[0].record, results[1].record);
  assert.equal((await db.collection(`${base}/attendance`).get()).size, 1);
});
test("manual versus QR race preserves first result and method", async () => {
  const issued = await backend.issue(req());
  const client = env.authenticatedContext("manager").firestore();
  const manual = setDoc(doc(client, `${base}/attendance/student`), {
    uid: "student",
    organizationId: "public",
    eventId: "demo",
    attendanceStatus: "absent",
    verifiedBy: "manager",
    verifiedAt: serverTimestamp(),
    verificationMethod: "manual",
  });
  const qr = backend.redeem(req("scanner", payload(issued)));
  await Promise.allSettled([manual, qr]);
  const before = (await db.doc(`${base}/attendance/student`).get()).data();
  assert.ok(before);
  assert.equal((await db.collection(`${base}/attendance`).get()).size, 1);
  const retry = await backend.redeem(req("manager", payload(issued)));
  assert.equal(retry.duplicate, true);
  assert.equal(retry.record.verificationMethod, before.verificationMethod);
  assert.equal(retry.record.attendanceStatus, before.attendanceStatus);
});
test("student binding prevents extra request UID from issuing for another student", async () => {
  const issued = await backend.issue(req("otherStudent", { uid: "student" }));
  const result = await backend.redeem(req("manager", payload(issued)));
  assert.equal(result.record.uid, "otherStudent");
  assert.equal(result.fullName, "Unknown Participant");
});
test("already marked student cannot issue, and organizers cannot verify themselves", async () => {
  await seed(`${base}/registrations/manager`, {
    uid: "manager",
    eventId: "demo",
    organizationId: "public",
    registrationStatus: "registered",
  });
  const issued = await backend.issue(req("manager"));
  await assert.rejects(
    backend.redeem(req("manager", payload(issued))),
    code("permission-denied"),
  );
  await seed(`${base}/attendance/student`, {
    uid: "student",
    eventId: "demo",
    organizationId: "public",
    attendanceStatus: "absent",
    verifiedAt: Timestamp.now(),
    verifiedBy: "manager",
    verificationMethod: "manual",
  });
  await assert.rejects(backend.issue(req()), code("already-exists"));
});
test("callable emulator accepts Auth emulator token and returns private-safe response", async () => {
  if (
    !process.env.FIREBASE_AUTH_EMULATOR_HOST ||
    !process.env.FUNCTIONS_EMULATOR_HOST
  )
    throw Error("Auth and Functions emulators are required.");
  const auth = await fetch(
    `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=emulator-key`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        email: `module4-${Date.now()}@example.test`,
        password: "Demo-only-password-123",
        returnSecureToken: true,
      }),
    },
  ).then((r) => r.json());
  assert.ok(auth.idToken, JSON.stringify(auth));
  const uid = auth.localId;
  await seed(`users/${uid}`, {
    uid,
    fullName: "Callable Student",
    studentNumber: "DEMO-002",
    yearLevel: 1,
    section: "A",
    accountStatus: "active",
  });
  await seed(`${base}/registrations/${uid}`, {
    uid,
    eventId: "demo",
    organizationId: "public",
    registrationStatus: "registered",
  });
  const url = `http://${process.env.FUNCTIONS_EMULATOR_HOST}/orglink-dev/us-central1/issueAttendanceCredential`;
  const response = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${auth.idToken}`,
    },
    body: JSON.stringify({
      data: { organizationId: "public", eventId: "demo" },
    }),
  }).then((r) => r.json());
  assert.match(
    response.result?.token ?? "",
    /^[A-Za-z0-9_-]{43}$/,
    JSON.stringify(response),
  );
  assert.equal(response.result.uid, undefined);
  const denied = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      data: { organizationId: "public", eventId: "demo" },
    }),
  }).then((r) => r.json());
  assert.equal(denied.error.status, "UNAUTHENTICATED");
  const organizer = await fetch(
    `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=emulator-key`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        email: `organizer-${Date.now()}@example.test`,
        password: "Demo-only-password-123",
        returnSecureToken: true,
      }),
    },
  ).then((r) => r.json());
  await seed(`users/${organizer.localId}`, {
    uid: organizer.localId,
    fullName: "Callable Manager",
    studentNumber: "DEMO-003",
    yearLevel: 1,
    section: "A",
    accountStatus: "active",
  });
  await update("organizations/public", { managerUid: organizer.localId });
  const redeemUrl = `http://${process.env.FUNCTIONS_EMULATOR_HOST}/orglink-dev/us-central1/redeemAttendanceCredential`;
  const redeem = async (authToken) =>
    fetch(redeemUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${authToken}`,
      },
      body: JSON.stringify({
        data: {
          organizationId: "public",
          eventId: "demo",
          version: 1,
          type: "attendance",
          token: response.result.token,
        },
      }),
    }).then((r) => r.json());
  const unauthorized = await redeem(auth.idToken);
  assert.equal(unauthorized.error.status, "PERMISSION_DENIED");
  const verified = await redeem(organizer.idToken);
  assert.equal(verified.result?.record?.uid, uid, JSON.stringify(verified));
  assert.equal(verified.result.record.verifiedBy, organizer.localId);
  assert.equal(verified.result.record.verificationMethod, "qr");
  const duplicate = await redeem(organizer.idToken);
  assert.equal(duplicate.result.duplicate, true);
  assert.deepEqual(duplicate.result.record, verified.result.record);
});

for (const change of ["registration", "event", "permission", "expiry"])
  test(`in-flight redemption rechecks ${change} changes before writing`, async () => {
    const issued = await backend.issue(req());
    let signal, release;
    const started = new Promise((resolve) => (signal = resolve)),
      gate = new Promise((resolve) => (release = resolve));
    let first = true;
    const controlled = {
      doc: db.doc.bind(db),
      runTransaction: (handler) =>
        db.runTransaction((t) =>
          handler(
            new Proxy(t, {
              get(target, key) {
                if (key === "getAll")
                  return async (...refs) => {
                    if (first) {
                      first = false;
                      signal();
                      await gate;
                    }
                    return target.getAll(...refs);
                  };
                const value = target[key];
                return typeof value === "function" ? value.bind(target) : value;
              },
            }),
          ),
        ),
    };
    const pending = attendanceBackend(controlled, () => now).redeem(
      req("scanner", payload(issued)),
    );
    const rejection = assert.rejects(pending);
    await started;
    if (change === "registration")
      await update(`${base}/registrations/student`, {
        registrationStatus: "cancelled",
      });
    if (change === "event") await update(base, { eventStatus: "cancelled" });
    if (change === "permission")
      await update("organizations/public/memberships/scanner", {
        "permissions.manageAttendance": false,
      });
    if (change === "expiry") now = issued.expiresAt;
    release();
    await rejection;
    assert.equal((await db.collection(`${base}/attendance`).get()).size, 0);
  });
