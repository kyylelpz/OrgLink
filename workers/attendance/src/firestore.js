// Workers-compatible Firestore REST transactions. No Admin SDK or Node APIs.
export class Timestamp {
  constructor(milliseconds) {
    this.milliseconds = milliseconds;
  }
  static fromMillis(value) {
    return new Timestamp(value);
  }
  toMillis() {
    return this.milliseconds;
  }
}
// Only fixed stage/reason identifiers and numeric HTTP status may reach logs.
export class BackendError extends Error {
  constructor(stage, reason, upstreamStatus) {
    super("Attendance backend failed.");
    this.stage = stage;
    this.reason = reason;
    this.upstreamStatus = upstreamStatus;
  }
}
// Allowlisted runtime identifiers only; exception messages and causes stay private.
export class TransportError extends BackendError {
  constructor(stage, error) {
    super(
      stage,
      error?.name === "TimeoutError" ? "timeout" : "transport-error",
    );
    this.errorName = [
      "Error",
      "TypeError",
      "RangeError",
      "AbortError",
      "TimeoutError",
      "NetworkError",
    ].includes(error?.name)
      ? error.name
      : "UnknownError";
    const code = error?.code ?? error?.cause?.code;
    if (
      [
        "ECONNRESET",
        "ECONNREFUSED",
        "ETIMEDOUT",
        "ENOTFOUND",
        "EAI_AGAIN",
        "ERR_INVALID_ARG_VALUE",
        "ERR_INVALID_URL",
        "UND_ERR_CONNECT_TIMEOUT",
        "UND_ERR_SOCKET",
        "ABORT_ERR",
      ].includes(code)
    )
      this.runtimeCode = code;
  }
}
export class RestError extends BackendError {
  constructor(status, method = "request") {
    super(`firestore.${method}`, "http-error", status);
    this.status = status;
  }
}
export function encode(value) {
  if (value instanceof Timestamp)
    return { timestampValue: new Date(value.toMillis()).toISOString() };
  if (value === null) return { nullValue: null };
  if (typeof value === "string") return { stringValue: value };
  if (typeof value === "boolean") return { booleanValue: value };
  if (typeof value === "number")
    return Number.isInteger(value)
      ? { integerValue: String(value) }
      : { doubleValue: value };
  if (Array.isArray(value))
    return { arrayValue: { values: value.map(encode) } };
  if (value && typeof value === "object")
    return {
      mapValue: {
        fields: Object.fromEntries(
          Object.entries(value).map(([k, v]) => [k, encode(v)]),
        ),
      },
    };
  throw new Error("Unsupported Firestore value.");
}
export function decode(value) {
  if ("timestampValue" in value) {
    const ms = Date.parse(value.timestampValue);
    if (!Number.isFinite(ms)) throw new Error("Invalid timestamp.");
    return Timestamp.fromMillis(ms);
  }
  if ("nullValue" in value) return null;
  if ("stringValue" in value) return value.stringValue;
  if ("booleanValue" in value) return value.booleanValue;
  if ("integerValue" in value) return Number(value.integerValue);
  if ("doubleValue" in value) return value.doubleValue;
  if ("arrayValue" in value) return (value.arrayValue.values ?? []).map(decode);
  if ("mapValue" in value)
    return Object.fromEntries(
      Object.entries(value.mapValue.fields ?? {}).map(([k, v]) => [
        k,
        decode(v),
      ]),
    );
  throw new Error("Unsupported Firestore value.");
}
export class RestFirestore {
  constructor(
    bearer,
    { fetchImpl = fetch, origin = "https://firestore.googleapis.com" } = {},
  ) {
    this.bearer = bearer;
    // Invoke ambient fetch without the client instance as its receiver (workerd brand check).
    this.fetch = (...args) => fetchImpl(...args);
    this.root = "projects/orglink-dev/databases/(default)";
    if (
      origin !== "https://firestore.googleapis.com" &&
      !/^http:\/\/(127\.0\.0\.1|localhost):\d+$/.test(origin)
    )
      throw new Error("Invalid Firestore origin.");
    this.origin = origin;
  }
  doc(path) {
    return `${this.root}/documents/${path}`;
  }
  async call(method, body) {
    const token = await this.bearer();
    let response;
    try {
      response = await this.fetch(
        `${this.origin}/v1/${this.root}/documents:${method}`,
        {
          method: "POST",
          // Workers does not support "error". Return redirects without forwarding credentials.
          redirect: "manual",
          headers: {
            Authorization: `Bearer ${token}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify(body),
          signal: AbortSignal.timeout(8000),
        },
      );
    } catch (error) {
      throw new TransportError(`firestore.${method}`, error);
    }
    // Includes every 3xx response: never follow Location or accept a redirected write.
    if (!response.ok) {
      try {
        await response.body?.cancel();
      } catch {
        /* Keep the HTTP failure. */
      }
      throw new RestError(response.status, method);
    }
    try {
      return await response.json();
    } catch {
      throw new BackendError(`firestore.${method}`, "invalid-json-response");
    }
  }
  async runTransaction(handler) {
    let retryTransaction;
    for (let attempt = 0; attempt < 5; attempt++) {
      let transaction;
      try {
        ({ transaction } = await this.call("beginTransaction", {
          options: { readWrite: retryTransaction ? { retryTransaction } : {} },
        }));
        const writes = [];
        const t = {
          getAll: async (...names) => {
            if (writes.length)
              throw new Error("Reads must precede transaction writes.");
            const response = await this.call("batchGet", {
              documents: names,
              transaction,
            });
            const docs = new Map(
              response
                .filter((d) => d.found)
                .map((d) => [
                  d.found.name,
                  decode({ mapValue: { fields: d.found.fields ?? {} } }),
                ]),
            );
            return names.map((name) => ({ data: () => docs.get(name) }));
          },
          set: (name, data) =>
            writes.push({
              update: { name, fields: encode(data).mapValue.fields },
            }),
          create: (name, data) =>
            writes.push({
              update: { name, fields: encode(data).mapValue.fields },
              currentDocument: { exists: false },
            }),
          update: (name, data) =>
            writes.push({
              update: { name, fields: encode(data).mapValue.fields },
              updateMask: { fieldPaths: Object.keys(data) },
              currentDocument: { exists: true },
            }),
          delete: (name) => writes.push({ delete: name }),
        };
        const result = await handler(t);
        // Even duplicate/read-only results commit the read transaction; no stale permission results.
        await this.call("commit", { writes, transaction });
        return result;
      } catch (error) {
        if (transaction)
          try {
            await this.call("rollback", { transaction });
          } catch {
            /* Preserve the original failure; server transactions also expire. */
          }
        if (
          error instanceof RestError &&
          [409, 412].includes(error.status) &&
          attempt < 4
        ) {
          retryTransaction = transaction;
          await new Promise((resolve) =>
            setTimeout(resolve, 100 * 2 ** attempt + Math.random() * 100),
          );
          continue;
        }
        throw error;
      }
    }
  }
}
