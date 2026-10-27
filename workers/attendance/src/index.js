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
};
const response = (body, code = 200) =>
  Response.json(body, {
    status: code,
    headers: {
      "Cache-Control": "no-store",
      "X-Content-Type-Options": "nosniff",
    },
  });
async function readJSON(request) {
  if (
    !/^application\/json(?:;|$)/i.test(
      request.headers.get("Content-Type") ?? "",
    )
  )
    throw new AttendanceError(
      "invalid-argument",
      "Send a JSON attendance request.",
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
    if (size > 8192) {
      await reader.cancel();
      throw new AttendanceError(
        "invalid-argument",
        "Attendance request is too large.",
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
  const verify = firebaseVerifier({ fetchImpl, clock }),
    oauth = googleAccessToken({ fetchImpl, clock });
  return async (request, env) => {
    const path = new URL(request.url).pathname;
    if (!["/issue", "/redeem"].includes(path))
      return response(
        { error: { code: "not-found", message: "Endpoint not found." } },
        404,
      );
    if (request.method !== "POST")
      return response(
        {
          error: {
            code: "invalid-argument",
            message: "Use POST for attendance.",
          },
        },
        405,
      );
    let stage = "firebase-auth";
    try {
      const uid = await verify(request.headers.get("Authorization"));
      stage = "request-json";
      const data = await readJSON(request);
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
      const backend = attendanceBackend(db, clock);
      stage = path === "/issue" ? "attendance.issue" : "attendance.redeem";
      const result = await backend[path === "/issue" ? "issue" : "redeem"]({
        auth: { uid },
        data,
      });
      stage = "response";
      return response({ result });
    } catch (error) {
      if (error instanceof AttendanceError)
        return response(
          { error: { code: error.code, message: error.message } },
          status[error.code] ?? 400,
        );
      // Never return upstream Google errors, token contents or service-account details.
      const diagnostic = {
        event: "attendance_backend_failure",
        endpoint: path === "/issue" ? "issue" : "redeem",
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
              "Verification could not be confirmed. Check attendance status before retrying.",
          },
        },
        503,
      );
    }
  };
}
const handler = createHandler();
export default { fetch: (request, env) => handler(request, env) };
