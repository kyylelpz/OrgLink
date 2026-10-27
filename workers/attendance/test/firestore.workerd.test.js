import { test } from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { Miniflare, convertV4MiniflareOptions } from "miniflare";

const source = await readFile(
  new URL("../src/firestore.js", import.meta.url),
  "utf8",
);
const url =
  "https://firestore.googleapis.com/v1/projects/orglink-dev/databases/(default)/documents:beginTransaction";

test("workerd confirms native fetch receiver restriction with exact Firestore request options", async () => {
  let outboundCalls = 0;
  const mf = new Miniflare(
    convertV4MiniflareOptions({
      modules: true,
      compatibilityDate: "2026-10-23",
      script: `export default { async fetch() {
      const options = {method:'POST', redirect:'manual', headers:{Authorization:'Bearer test-only-invalid-bearer','Content-Type':'application/json'}, body:JSON.stringify({options:{readWrite:{}}}), signal:AbortSignal.timeout(8000)};
      const receiver = {fetch};
      let instanceCall;
      try { await receiver.fetch(${JSON.stringify(url)}, options); instanceCall = 'accepted'; }
      catch(error) { instanceCall = error.name; }
      const response = await fetch(${JSON.stringify(url)}, options);
      return Response.json({instanceCall, directStatus:response.status});
    }};`,
      outboundService: async (request) => {
        outboundCalls++;
        assert.equal(request.url, url);
        assert.equal(request.method, "POST");
        assert.equal(
          request.headers.get("Authorization"),
          "Bearer test-only-invalid-bearer",
        );
        assert.equal(request.headers.get("Content-Type"), "application/json");
        assert.deepEqual(await request.json(), { options: { readWrite: {} } });
        return Response.json({ transaction: "mock-tx" });
      },
    }),
  );
  try {
    assert.deepEqual(
      await (await mf.dispatchFetch("http://localhost")).json(),
      {
        instanceCall: "TypeError",
        directStatus: 200,
      },
    );
    assert.equal(outboundCalls, 1);
  } finally {
    await mf.dispose();
  }
});

test("real RestFirestore runs transactions and rollback in workerd using native fetch", async () => {
  const methods = [];
  const mf = new Miniflare(
    convertV4MiniflareOptions({
      modules: true,
      compatibilityDate: "2026-10-23",
      script:
        source +
        `
      export default {async fetch() {
        const db = new RestFirestore(async () => 'test-only-invalid-bearer');
        await db.runTransaction(async t => {
          const ref = db.doc('test/mock');
          await t.getAll(ref);
          t.create(ref, {status:'present'});
        });
        try { await db.runTransaction(async () => {throw new Error('fixture');}); }
        catch { /* Exercise rollback without exposing the fixture error. */ }
        return Response.json({ok:true});
      }};`,
      outboundService: async (request) => {
        const method = new URL(request.url).pathname.split(":").at(-1);
        methods.push(method);
        assert.equal(request.method, "POST");
        assert.equal(
          request.headers.get("Authorization"),
          "Bearer test-only-invalid-bearer",
        );
        const body = await request.json();
        if (method === "beginTransaction")
          return Response.json({ transaction: "mock-tx" });
        assert.equal(body.transaction, "mock-tx");
        if (method === "batchGet")
          return Response.json([{ missing: body.documents[0] }]);
        if (method === "commit")
          assert.equal(body.writes[0].currentDocument.exists, false);
        return Response.json({});
      },
    }),
  );
  try {
    assert.deepEqual(
      await (await mf.dispatchFetch("http://localhost")).json(),
      { ok: true },
    );
    assert.deepEqual(methods, [
      "beginTransaction",
      "batchGet",
      "commit",
      "beginTransaction",
      "rollback",
    ]);
  } finally {
    await mf.dispose();
  }
});
