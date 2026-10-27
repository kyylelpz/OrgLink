import { readFileSync } from "node:fs";
import { before, after, beforeEach, test } from "node:test";
import assert from "node:assert/strict";
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from "@firebase/rules-unit-testing";
import {
  doc,
  collection,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
  deleteDoc,
  Timestamp,
  serverTimestamp,
  runTransaction,
} from "firebase/firestore";
let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: "orglink-dev",
    firestore: {
      rules: readFileSync(
        new URL("../firebase.rules", import.meta.url),
        "utf8",
      ),
    },
  });
});
after(async () => await env?.cleanup());
const db = (uid = "manager") => env.authenticatedContext(uid).firestore();
const base = "organizations/public/events/demo";
const ref = (database, uid = "student") =>
  doc(database, `${base}/attendance/${uid}`);
const record = (changes = {}) => ({
  uid: "student",
  eventId: "demo",
  organizationId: "public",
  attendanceStatus: "present",
  verifiedAt: serverTimestamp(),
  verifiedBy: "manager",
  verificationMethod: "manual",
  ...changes,
});

test("correction audit is manager-readable and no client can create, mutate or delete audit history", async () => {
  const path = `${base}/attendanceCorrections/audit-one`;
  const audit = {
    eventId: "demo",
    participantUid: "student",
    previousStatus: "present",
    newStatus: "pending",
    reason: "Verified correction",
    correctedBy: "manager",
    correctedAt: Timestamp.now(),
  };
  await seed(path, audit);
  await assertSucceeds(getDoc(doc(db("manager"), path)));
  await assertSucceeds(
    getDocs(collection(db("manager"), `${base}/attendanceCorrections`)),
  );
  for (const uid of ["manager", "scanner", "student", "other", "suspended"]) {
    await assertFails(
      setDoc(doc(db(uid), `${base}/attendanceCorrections/new-audit`), audit),
    );
    await assertFails(updateDoc(doc(db(uid), path), { reason: "Forged" }));
    await assertFails(deleteDoc(doc(db(uid), path)));
    if (uid !== "manager") {
      await assertFails(getDoc(doc(db(uid), path)));
      await assertFails(
        getDocs(collection(db(uid), `${base}/attendanceCorrections`)),
      );
    }
  }
});

test("clients cannot directly correct or reset attendance even with a fabricated audit", async () => {
  await seed(
    `${base}/attendance/student`,
    record({ verifiedAt: Timestamp.now() }),
  );
  for (const uid of ["manager", "scanner", "student", "other"]) {
    await assertFails(updateDoc(ref(db(uid)), { attendanceStatus: "absent" }));
    await assertFails(deleteDoc(ref(db(uid))));
    await assertFails(updateDoc(ref(db(uid)), { attendanceStatus: "pending" }));
  }
});
async function seed(path, data) {
  await env.withSecurityRulesDisabled(async (c) =>
    setDoc(doc(c.firestore(), path), data),
  );
}
beforeEach(async () => {
  await env.clearFirestore();
  for (const uid of [
    "student",
    "manager",
    "scanner",
    "coordinator",
    "ordinary",
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
    name: "Public",
    managerUid: "manager",
    status: "active",
    visibility: "public",
  });
  await seed(base, {
    eventId: "demo",
    organizationId: "public",
    title: "Ongoing",
    createdBy: "manager",
    visibility: "public",
    eventStatus: "published",
    approvalStatus: "approved",
    publishedAt: Timestamp.fromMillis(Date.now() - 7200000),
    archivedAt: null,
    startAt: Timestamp.fromMillis(Date.now() - 3600000),
    endAt: Timestamp.fromMillis(Date.now() + 3600000),
    registrationCount: 1,
  });
  await seed(`${base}/registrations/student`, {
    uid: "student",
    organizationId: "public",
    eventId: "demo",
    registrationStatus: "registered",
    registeredAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  });
  await seed(`${base}/participantIdentities/student`, {
    uid: "student",
    fullName: "Demo Student",
    updatedAt: Timestamp.now(),
  });
  for (const [uid, permissions] of Object.entries({
    scanner: { manageAttendance: true },
    coordinator: { manageEvents: true },
    ordinary: {},
  }))
    await seed(`organizations/public/memberships/${uid}`, {
      uid,
      organizationId: "public",
      membershipStatus: "active",
      membershipRole: "officer",
      permissions,
    });
});
test("manager creates exact manual attendance; operator and student read; no capacity change", async () => {
  await assertSucceeds(setDoc(ref(db()), record()));
  const value = (await getDoc(ref(db("student")))).data();
  assert.equal(Object.keys(value).length, 7);
  assert.equal(value.verificationMethod, "manual");
  assert.equal((await getDoc(doc(db(), base))).data().registrationCount, 1);
  await assertSucceeds(getDocs(collection(db(), `${base}/attendance`)));
});
test("attendance officer reads event roster and names without private user reads", async () => {
  await assertSucceeds(
    setDoc(ref(db("scanner")), record({ verifiedBy: "scanner" })),
  );
  for (const name of ["registrations", "participantIdentities", "attendance"])
    await assertSucceeds(getDocs(collection(db("scanner"), `${base}/${name}`)));
  await assertFails(getDoc(doc(db("scanner"), "users/student")));
  await assertSucceeds(getDoc(doc(db("scanner"), base)));
});
for (const uid of ["student", "coordinator", "ordinary", "other", "suspended"])
  test(`deny unauthorized manual operator ${uid}`, async () => {
    await assertFails(setDoc(ref(db(uid)), record({ verifiedBy: uid })));
    await assertFails(getDocs(collection(db(uid), `${base}/attendance`)));
  });
test("platform admin, cross-org manager and position titles confer no attendance authority", async () => {
  await seed("organizations/other", {
    organizationId: "other",
    managerUid: "other",
    status: "active",
    visibility: "public",
  });
  await seed("organizations/public/memberships/ordinary", {
    uid: "ordinary",
    organizationId: "public",
    membershipRole: "officer",
    membershipStatus: "active",
    positionTitle: "President",
    permissions: { manageEvents: true },
  });
  await assertFails(
    setDoc(ref(db("ordinary")), record({ verifiedBy: "ordinary" })),
  );
  await assertFails(setDoc(ref(db("other")), record({ verifiedBy: "other" })));
});
for (const changes of [
  { membershipStatus: "pending" },
  { membershipStatus: "removed" },
  { membershipRole: "member" },
  { permissions: { manageAttendance: false } },
])
  test(`deny revoked or invalid assignment ${JSON.stringify(changes)}`, async () => {
    await seed("organizations/public/memberships/scanner", {
      uid: "scanner",
      organizationId: "public",
      membershipRole: "officer",
      membershipStatus: "active",
      permissions: { manageAttendance: true },
      ...changes,
    });
    await assertFails(
      setDoc(ref(db("scanner")), record({ verifiedBy: "scanner" })),
    );
  });
for (const [label, changes] of Object.entries({
  status: { attendanceStatus: "notMarked" },
  method: { verificationMethod: "qr" },
  unknownMethod: { verificationMethod: "other" },
  extra: { fullName: "Private" },
  operator: { verifiedBy: "student" },
  time: { verifiedAt: Timestamp.fromMillis(0) },
  uid: { uid: "other" },
  event: { eventId: "other" },
  organization: { organizationId: "other" },
}))
  test(`reject malformed attendance ${label}`, async () =>
    await assertFails(setDoc(ref(db()), record(changes))));
for (const changes of [
  { eventStatus: "draft" },
  { eventStatus: "cancelled" },
  { eventStatus: "completed" },
  { archivedAt: Timestamp.now() },
  { approvalStatus: "pending" },
  { publishedAt: null },
  { startAt: Timestamp.fromMillis(Date.now() + 3600000) },
  { endAt: Timestamp.fromMillis(Date.now() - 1000) },
])
  test(`deny ineligible event ${JSON.stringify(changes)}`, async () => {
    await env.withSecurityRulesDisabled(async (c) =>
      updateDoc(doc(c.firestore(), base), changes),
    );
    await assertFails(setDoc(ref(db()), record()));
  });
test("unregistered, withdrawn, and self-verifying organizers are denied", async () => {
  await assertFails(setDoc(ref(db(), "other"), record({ uid: "other" })));
  await seed(`${base}/registrations/student`, {
    uid: "student",
    eventId: "demo",
    organizationId: "public",
    registrationStatus: "cancelled",
  });
  await assertFails(setDoc(ref(db()), record()));
  await seed(`${base}/registrations/manager`, {
    uid: "manager",
    eventId: "demo",
    organizationId: "public",
    registrationStatus: "registered",
  });
  await assertFails(setDoc(ref(db(), "manager"), record({ uid: "manager" })));
});
test("first result final: duplicate create, updates, deletes and method swaps denied", async () => {
  await setDoc(ref(db()), record({ attendanceStatus: "absent" }));
  await assertFails(setDoc(ref(db()), record()));
  await assertFails(updateDoc(ref(db()), { attendanceStatus: "present" }));
  await assertFails(updateDoc(ref(db()), { verificationMethod: "qr" }));
  await assertFails(deleteDoc(ref(db())));
  await assertFails(getDoc(ref(db("other"))));
  await assertSucceeds(getDoc(ref(db("student"))));
  await assertFails(getDoc(ref(env.unauthenticatedContext().firestore())));
});
test("concurrent manual attempts finalize only one immutable record", async () => {
  const attempt = async (uid, status) => {
    const database = db(uid);
    return runTransaction(database, async (t) => {
      const target = ref(database);
      const previous = await t.get(target);
      if (previous.exists()) return false;
      t.set(target, record({ verifiedBy: uid, attendanceStatus: status }));
      return true;
    });
  };
  const results = await Promise.all([
    attempt("manager", "present"),
    attempt("scanner", "absent"),
  ]);
  assert.equal(results.filter(Boolean).length, 1);
  assert.equal((await getDocs(collection(db(), `${base}/attendance`))).size, 1);
});
test("credential storage is inaccessible to every client", async () => {
  for (const name of ["_attendanceCredentials", "_attendanceIssuance"]) {
    await seed(`${name}/secret`, { uid: "student" });
    for (const uid of ["student", "manager", "scanner"]) {
      await assertFails(getDoc(doc(db(uid), `${name}/secret`)));
      await assertFails(getDocs(collection(db(uid), name)));
      await assertFails(
        setDoc(doc(db(uid), `${name}/forged`), { token: "forged" }),
      );
    }
  }
});
