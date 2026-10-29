import { profileBackend } from "./student_ids.js";
import { adminBackend } from "./admin.js";
import { attendanceBackend, AttendanceError } from "./attendance.js";
import { firebaseVerifier, googleAccessToken } from "./auth.js";
import { BackendError, RestFirestore, TransportError } from "./firestore.js";
const status = {
  unauthenticated: 401,
  "permission-denied": 403,
  "invalid-argument": 400,
  "not-found": 404,
  "failed-precondition": 409,
  "already-exists": 409,
  "resource-exhausted": 429,
  conflict: 409,
};
const response = (body, code = 200) =>
  Response.json(body, {
    status: code,
    headers: {
      "Cache-Control": "no-store",
      "X-Content-Type-Options": "nosniff",
    },
  });
async function readJSON(request, limit = 8192) {
  if (
    !/^application\/json(?:;|$)/i.test(
      request.headers.get("Content-Type") ?? "",
    )
  )
    throw new AttendanceError(
      "invalid-argument",
      "Send a JSON request.",
    );
  const reader = request.body?.getReader();
  if (!reader)
    throw new AttendanceError("invalid-argument", "Missing request.");
  let size = 0;
  const chunks = [];
  while (true) {
    const { value, done } = await reader.read();
    if (done) break;
    size += value.byteLength;
    if (size > limit) {
      await reader.cancel();
      throw new AttendanceError(
        "invalid-argument",
        "The request is too large.",
      );
    }
    chunks.push(value);
  }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.length;
  }
  try {
    const value = JSON.parse(new TextDecoder().decode(bytes));
    if (!value || typeof value !== "object" || Array.isArray(value))
      throw Error();
    return value;
  } catch {
    throw new AttendanceError("invalid-argument", "Invalid JSON request.");
  }
}
export function createHandler({
  fetchImpl = fetch,
  clock = Date.now,
  logFailure = (entry) => console.error(JSON.stringify(entry)),
} = {}) {
  const verify = firebaseVerifier({ fetchImpl, clock, returnClaims: true }),
    oauth = googleAccessToken({ fetchImpl, clock });
  return async (request, env) => {
    const path = new URL(request.url).pathname;
    if (!["/issue", "/redeem", "/correct", "/admin/stats", "/admin/list", "/admin/mutate", "/admin/manager", "/profile/save"].includes(path))
      return response(
        { error: { code: "not-found", message: "Endpoint not found." } },
        404,
      );
    if (request.method !== "POST")
      return response(
        {
          error: {
            code: "invalid-argument",
            message: "Use POST for this endpoint.",
          },
        },
        405,
      );
    let stage = "firebase-auth";
    try {
      const identity = await verify(request.headers.get("Authorization"));
      const uid = identity.sub;
      stage = "request-json";
      const data = await readJSON(request, path.startsWith("/admin/") ? 65536 : 8192);
      stage = "configuration";
      let origin = "https://firestore.googleapis.com";
      if (env.FIRESTORE_EMULATOR_HOST) {
        if (!/^(127\.0\.0\.1|localhost):\d+$/.test(env.FIRESTORE_EMULATOR_HOST))
          throw new BackendError("configuration", "invalid-emulator-host");
        origin = `http://${env.FIRESTORE_EMULATOR_HOST}`;
      }
      const db = new RestFirestore(
        () =>
          origin.startsWith("http:")
            ? Promise.resolve("owner")
            : oauth(env.FIREBASE_SERVICE_ACCOUNT),
        { fetchImpl, origin },
      );
      const isAdmin = path.startsWith("/admin/");
      const isProfile = path.startsWith("/profile/");
      const backend = isAdmin ? adminBackend(db, clock) : isProfile ? profileBackend(db, clock) : attendanceBackend(db, clock);
      const operation = isAdmin ? path.slice(7) : isProfile ? path.slice(9) : path.slice(1);
      stage = `${isAdmin ? "platform-admin" : isProfile ? "profile" : "attendance"}.${operation}`;
      const result = await backend[operation]({
        auth: { uid, email: identity.email, photoURL: identity.picture },
        data,
      });
      stage = "response";
      return response({ result });
    } catch (error) {
      if (error instanceof AttendanceError)
        return response(
          { error: { code: error.code, message: path.startsWith("/admin/") && error.code === "unauthenticated" ? "Sign in again to open administration." : path.startsWith("/profile/") && error.code === "unauthenticated" ? "Sign in again before saving your profile." : error.message } },
          status[error.code] ?? 400,
        );
      // Never return upstream Google errors, token contents or service-account details.
      const diagnostic = {
        event: path.startsWith("/admin/") ? "platform_admin_backend_failure" : path.startsWith("/profile/") ? "profile_backend_failure" : "attendance_backend_failure",
        endpoint: path.slice(1),
        stage: error instanceof BackendError ? error.stage : stage,
        code: "unavailable",
        reason:
          error instanceof BackendError ? error.reason : "unexpected-error",
      };
      if (error instanceof TransportError) {
        diagnostic.errorName = error.errorName;
        if (error.runtimeCode) diagnostic.runtimeCode = error.runtimeCode;
      }
      if (
        error instanceof BackendError &&
        Number.isInteger(error.upstreamStatus)
      ) {
        diagnostic.upstreamStatus = error.upstreamStatus;
      }
      try {
        logFailure(diagnostic);
      } catch {
        /* Diagnostics must not affect the response. */
      }
      return response(
        {
          error: {
            code: "unavailable",
            message:
              path.startsWith("/admin/") ? "The administration operation could not be confirmed. Refresh records before retrying." : path.startsWith("/profile/") ? "Your profile save could not be confirmed. Refresh your profile before retrying." : "Verification could not be confirmed. Check attendance status before retrying.",
          },
        },
        503,
      );
    }
  };
}
const handler = createHandler();
export default { fetch: (request, env) => handler(request, env) };
