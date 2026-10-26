const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { onCall } = require("firebase-functions/v2/https");
const { attendanceBackend } = require("./attendance");
initializeApp();
const backend = attendanceBackend(getFirestore());
// Auth/profile/organization checks are mandatory inside both handlers.
// App Check can be added after Android attestation is configured; never bypass Auth.
const options = { region: "us-central1", maxInstances: 3, timeoutSeconds: 30 };
exports.issueAttendanceCredential = onCall(options, backend.issue);
exports.redeemAttendanceCredential = onCall(options, backend.redeem);
