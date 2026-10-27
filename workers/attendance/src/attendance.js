import { Timestamp } from "./firestore.js";
export class AttendanceError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}
const randomToken = () => base64url(crypto.getRandomValues(new Uint8Array(32)));
export function base64url(bytes) {
  return btoa(String.fromCharCode(...bytes))
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replaceAll("=", "");
}
const fail = (code, message) => {
  throw new AttendanceError(code, message);
};
const hash = async (token) =>
  Array.from(
    new Uint8Array(
      await crypto.subtle.digest("SHA-256", new TextEncoder().encode(token)),
    ),
    (b) => b.toString(16).padStart(2, "0"),
  ).join("");
function id(value) {
  return (
    typeof value === "string" &&
    value.length > 0 &&
    value.length <= 1500 &&
    !value.includes("/") &&
    ![".", ".."].includes(value)
  );
}
function eligible(data) {
  return (
    data?.accountStatus === "active" &&
    typeof data.fullName === "string" &&
    data.fullName.trim().length >= 2 &&
    data.fullName.length <= 100 &&
    typeof data.studentNumber === "string" &&
    /^[A-Za-z0-9][A-Za-z0-9-]{2,29}$/.test(data.studentNumber) &&
    Number.isInteger(data.yearLevel) &&
    data.yearLevel >= 1 &&
    data.yearLevel <= 6 &&
    typeof data.section === "string" &&
    /^[A-Za-z0-9][A-Za-z0-9 -]{0,29}$/.test(data.section)
  );
}
function operator(org, membership, uid) {
  return (
    org?.managerUid === uid ||
    (membership?.uid === uid &&
      membership?.organizationId === org?.organizationId &&
      membership.membershipStatus === "active" &&
      membership.membershipRole === "officer" &&
      membership.permissions?.manageAttendance === true)
  );
}
function checkEvent(org, event, orgId, eventId, now) {
  if (!org || !event)
    fail("not-found", "The organization or event is no longer available.");
  if (
    org.status !== "active" ||
    event.organizationId !== orgId ||
    event.eventId !== eventId ||
    event.eventStatus !== "published" ||
    event.approvalStatus !== "approved" ||
    !(event.publishedAt instanceof Timestamp) ||
    event.archivedAt != null
  ) {
    fail(
      "failed-precondition",
      "This event is not eligible for attendance verification.",
    );
  }
  if (
    !(event.startAt instanceof Timestamp) ||
    !(event.endAt instanceof Timestamp) ||
    now < event.startAt.toMillis() ||
    now >= event.endAt.toMillis()
  ) {
    fail(
      "failed-precondition",
      "Attendance is available only between the event start and end times.",
    );
  }
}
function checkRegistration(reg, uid, org, event) {
  if (
    reg?.uid !== uid ||
    reg.organizationId !== org ||
    reg.eventId !== event ||
    reg.registrationStatus !== "registered"
  ) {
    fail("failed-precondition", "An active event registration is required.");
  }
}
// The clock is injectable for deterministic boundary tests; callable clients cannot set it.
function attendanceBackend(db, clock = Date.now) {
  function input(request) {
    if (!request.auth?.uid)
      fail("unauthenticated", "Sign in before using attendance.");
    const { organizationId: org, eventId: event } = request.data ?? {};
    if (!id(org) || !id(event))
      fail("invalid-argument", "Invalid organization or event identifier.");
    return {
      uid: request.auth.uid,
      org,
      event,
      base: `organizations/${org}/events/${event}`,
    };
  }
  async function issue(request) {
    const { uid, org, event, base } = input(request);
    const token = randomToken(),
      digest = await hash(token);
    return db.runTransaction(async (t) => {
      const refs = [
        `users/${uid}`,
        `organizations/${org}`,
        base,
        `${base}/registrations/${uid}`,
        `${base}/attendance/${uid}`,
        `_attendanceIssuance/${uid}`,
      ];
      const [profile, organization, target, registration, attendance, slot] = (
        await t.getAll(...refs.map((p) => db.doc(p)))
      ).map((d) => d.data());
      const now = clock();
      if (!eligible(profile))
        fail(
          "permission-denied",
          "An active account and complete student profile are required.",
        );
      checkEvent(organization, target, org, event, now);
      checkRegistration(registration, uid, org, event);
      if (attendance)
        fail("already-exists", "Your attendance has already been verified.");
      if (slot?.issuedAt?.toMillis() > now - 5000)
        fail(
          "resource-exhausted",
          "Wait a few seconds before generating another QR pass.",
        );
      const expiresAt = Math.min(now + 60000, target.endAt.toMillis());
      if (slot?.tokenHash)
        t.delete(db.doc(`_attendanceCredentials/${slot.tokenHash}`));
      t.set(db.doc(`_attendanceCredentials/${digest}`), {
        uid,
        organizationId: org,
        eventId: event,
        issuedAt: Timestamp.fromMillis(now),
        expiresAt: Timestamp.fromMillis(expiresAt),
        consumedAt: null,
      });
      t.set(db.doc(`_attendanceIssuance/${uid}`), {
        issuedAt: Timestamp.fromMillis(now),
        tokenHash: digest,
      });
      return { token, expiresAt, serverTime: now };
    });
  }
  async function redeem(request) {
    const { uid, org, event, base } = input(request);
    const { version, type, token } = request.data;
    if (
      version !== 1 ||
      type !== "attendance" ||
      typeof token !== "string" ||
      !/^[A-Za-z0-9_-]{43}$/.test(token)
    )
      fail(
        "invalid-argument",
        "This is not a supported OrgLink attendance QR code.",
      );
    const digest = await hash(token);
    return db.runTransaction(async (t) => {
      const [profile, organization, membership, target, credential] = (
        await t.getAll(
          ...[
            `users/${uid}`,
            `organizations/${org}`,
            `organizations/${org}/memberships/${uid}`,
            base,
            `_attendanceCredentials/${digest}`,
          ].map((p) => db.doc(p)),
        )
      ).map((d) => d.data());
      // Authorize before revealing whether a credential/student exists.
      if (!eligible(profile) || !operator(organization, membership, uid))
        fail(
          "permission-denied",
          "You are not authorized to verify attendance for this organization.",
        );
      if (
        !credential ||
        credential.organizationId !== org ||
        credential.eventId !== event ||
        !id(credential.uid)
      )
        fail("invalid-argument", "Invalid attendance credential.");
      if (credential.uid === uid)
        fail("permission-denied", "You cannot verify your own attendance.");
      const [registration, existing, identity, student] = (
        await t.getAll(
          ...[
            `${base}/registrations/${credential.uid}`,
            `${base}/attendance/${credential.uid}`,
            `${base}/participantIdentities/${credential.uid}`,
            `users/${credential.uid}`,
          ].map((p) => db.doc(p)),
        )
      ).map((d) => d.data());
      const now = clock();
      if (now >= credential.expiresAt.toMillis())
        fail(
          "failed-precondition",
          "This QR pass has expired. Ask the student to generate another.",
        );
      checkEvent(organization, target, org, event, now);
      checkRegistration(registration, credential.uid, org, event);
      if (!eligible(student))
        fail(
          "failed-precondition",
          "The student account is no longer eligible.",
        );
      const safeResult = (record, duplicate) => ({
        duplicate,
        record: { ...record, verifiedAt: record.verifiedAt.toMillis() },
        fullName:
          typeof identity?.fullName === "string" && identity.fullName.trim()
            ? identity.fullName
            : "Unknown Participant",
        eventTitle: target.title,
        organizationName: organization.name,
      });
      if (existing) return safeResult(existing, true);
      if (credential.consumedAt)
        fail("already-exists", "This QR pass has already been used.");
      const record = {
        uid: credential.uid,
        eventId: event,
        organizationId: org,
        attendanceStatus: "present",
        verifiedAt: Timestamp.fromMillis(now),
        verifiedBy: uid,
        verificationMethod: "qr",
      };
      t.create(db.doc(`${base}/attendance/${credential.uid}`), record);
      t.update(db.doc(`_attendanceCredentials/${digest}`), {
        consumedAt: Timestamp.fromMillis(now),
      });
      return safeResult(record, false);
    });
  }
  async function correct(request) {
    const { uid, org, event, base } = input(request);
    const { operation, participantUid, newStatus, reason, revision } =
      request.data;
    if (!["preview", "apply"].includes(operation) || !id(participantUid))
      fail("invalid-argument", "Invalid attendance correction request.");
    if (
      operation === "apply" &&
      (!["present", "absent", "pending"].includes(newStatus) ||
        typeof reason !== "string" ||
        !reason.trim() ||
        reason.trim().length > 1000 ||
        typeof revision !== "string" ||
        revision.length > 100)
    )
      fail(
        "invalid-argument",
        "Select a status and provide a correction reason (1–1000 characters).",
      );
    const auditId = crypto.randomUUID();
    return db.runTransaction(async (t) => {
      const paths = [
        `users/${uid}`,
        `organizations/${org}`,
        base,
        `${base}/registrations/${participantUid}`,
        `${base}/attendance/${participantUid}`,
        `_attendanceIssuance/${participantUid}`,
      ];
      const snapshots = await t.getAll(...paths.map((p) => db.doc(p)));
      const [profile, organization, target, registration, existing, slot] =
        snapshots.map((d) => d.data());
      if (
        !eligible(profile) ||
        organization?.managerUid !== uid ||
        organization?.status !== "active"
      )
        fail(
          "permission-denied",
          "Only the assigned organization manager can correct attendance.",
        );
      if (participantUid === uid)
        fail("permission-denied", "You cannot correct your own attendance.");
      const now = clock();
      if (
        !target ||
        target.organizationId !== org ||
        target.eventId !== event ||
        !["published", "completed"].includes(target.eventStatus) ||
        target.approvalStatus !== "approved" ||
        !(target.publishedAt instanceof Timestamp) ||
        target.archivedAt != null ||
        !(target.startAt instanceof Timestamp) ||
        now < target.startAt.toMillis()
      )
        fail(
          "failed-precondition",
          "Corrections require an approved, unarchived event that has started.",
        );
      if (
        registration?.uid !== participantUid ||
        registration.organizationId !== org ||
        registration.eventId !== event ||
        !["registered", "cancelled"].includes(registration.registrationStatus)
      )
        fail(
          "failed-precondition",
          "The participant does not belong to this event.",
        );
      if (!existing)
        fail(
          "conflict",
          "Attendance changed or is Pending. Refresh the roster before correcting.",
        );
      if (
        existing.uid !== participantUid ||
        existing.organizationId !== org ||
        existing.eventId !== event ||
        !["present", "absent"].includes(existing.attendanceStatus) ||
        !(existing.verifiedAt instanceof Timestamp) ||
        !["manual", "qr"].includes(existing.verificationMethod) ||
        typeof existing.verifiedBy !== "string" ||
        Object.keys(existing).length !== 7
      )
        fail(
          "failed-precondition",
          "The stored attendance record is invalid and cannot be corrected.",
        );
      const currentRevision = snapshots[4].updateTime;
      if (typeof currentRevision !== "string" || !currentRevision)
        throw Error("Attendance revision unavailable.");
      if (operation === "preview")
        return {
          previousStatus: existing.attendanceStatus,
          revision: currentRevision,
        };
      if (revision !== currentRevision)
        fail(
          "conflict",
          "Attendance changed. Review the current result and confirm a new correction.",
        );
      if (newStatus === existing.attendanceStatus)
        fail("invalid-argument", "Choose a different attendance status.");
      // Read the current credential before writes. Concurrent issuance/redemption conflicts
      // on these transaction reads; a reset never reactivates a pre-correction pass.
      let credential;
      if (slot?.tokenHash) {
        if (
          typeof slot.tokenHash !== "string" ||
          !/^[a-f0-9]{64}$/.test(slot.tokenHash)
        )
          throw Error("Invalid issuance slot.");
        [credential] = (
          await t.getAll(db.doc(`_attendanceCredentials/${slot.tokenHash}`))
        ).map((d) => d.data());
      }
      const attendanceRef = db.doc(`${base}/attendance/${participantUid}`);
      if (newStatus === "pending") t.delete(attendanceRef);
      else
        t.set(attendanceRef, {
          uid: participantUid,
          eventId: event,
          organizationId: org,
          attendanceStatus: newStatus,
          verifiedAt: Timestamp.fromMillis(now),
          verifiedBy: uid,
          verificationMethod: "manual",
        });
      t.create(
        db.doc(`${base}/attendanceCorrections/${auditId}`),
        {
          eventId: event,
          participantUid,
          previousStatus: existing.attendanceStatus,
          newStatus,
          reason: reason.trim(),
          correctedBy: uid,
          previousRecord: existing,
        },
        { serverTimestampFields: ["correctedAt"] },
      );
      if (
        credential?.uid === participantUid &&
        credential.organizationId === org &&
        credential.eventId === event
      ) {
        t.delete(db.doc(`_attendanceCredentials/${slot.tokenHash}`));
        t.delete(db.doc(`_attendanceIssuance/${participantUid}`));
      }
      return { correctionId: auditId, newStatus };
    });
  }
  return { issue, redeem, correct };
}
export { attendanceBackend, eligible, operator };
