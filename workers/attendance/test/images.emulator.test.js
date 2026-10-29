import { test } from 'node:test';
import assert from 'node:assert/strict';
import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { RestFirestore } from '../src/firestore.js';
import { imageBackend } from '../src/images.js';
if (!/^(127\.0\.0\.1|localhost):\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST ?? '')) throw Error('Local Firestore emulator required; no live fallback.');

test('real Firestore image finalization is atomic, preserves identity and queries cleanup queues', async () => {
  const app = initializeApp({ projectId: 'orglink-dev' }, 'image-tests'), store = getFirestore(app);
  const db = new RestFirestore(async () => 'owner', { origin: `http://${process.env.FIRESTORE_EMULATOR_HOST}` });
  const uid = 'synthetic-image-' + Date.now(), path = `users/${uid}`, assets = new Map(), destroyed = [];
  let now = Date.now();
  const env = { CLOUDINARY_CLOUD_NAME: 'synthetic-test', CLOUDINARY_API_KEY: '123', CLOUDINARY_API_SECRET: 'synthetic-secret' };
  const fetchImpl = async (url, options) => {
    if (url.endsWith('/image/upload')) {
      const publicId = options.body.get('public_id');
      assert.equal(options.body.get('asset_folder'), 'orglink/profiles');
      const asset = { public_id: publicId, resource_type: 'image', type: 'upload', format: 'png', bytes: 100, width: 8, height: 8,
        secure_url: `https://res.cloudinary.com/synthetic-test/image/upload/v1/${publicId}.png` };
      assets.set(publicId, asset); return Response.json(asset);
    }
    if (url.endsWith('/image/destroy')) { destroyed.push(options.body.get('public_id')); return Response.json({ result: 'ok' }); }
    return Response.json(assets.get(decodeURIComponent(url.split('/resources/image/upload/')[1])));
  };
  const api = imageBackend(db, env, () => now, fetchImpl);
  const req = data => ({ auth: { uid }, data });
  const png = Buffer.from([137,80,78,71,13,10,26,10]).toString('base64');
  try {
    await store.doc(path).set({ uid, email: `${uid}@example.test`, fullName: 'Synthetic Student', studentNumber: '2026000001', yearLevel: 1, section: 'A', accountStatus: 'active', platformRole: 'user', photoURL: null });
    const upload = async () => {
      const ticket = await api.sign(req({ kind: 'profile' }));
      await api.upload(req({ uploadId: ticket.uploadId, signature: ticket.signature, file: png })); return ticket;
    };
    const a = await upload(); now += 11000; const b = await upload();
    const settled = await Promise.allSettled([a,b].map(s => api.finalize(req({ uploadId: s.uploadId }))));
    assert.equal(settled.filter(r => r.status === 'fulfilled').length, 1);
    assert.equal(settled.find(r => r.status === 'rejected').reason.code, 'conflict');
    const profile = (await store.doc(path).get()).data();
    assert.equal(profile.studentNumber, '2026000001'); assert.equal(profile.platformRole, 'user');
    assert.ok([a.uploadId,b.uploadId].includes(profile.imageRevision));
    await api.remove(req({ kind: 'profile', expectedURL: profile.photoURL }));
    assert.equal((await store.doc(path).get()).data().photoURL, null);
    now += 4000000; await api.cleanup(); now += 61000; await api.cleanup();
    assert.ok(destroyed.includes(`orglink/profiles/${a.uploadId}`));
    assert.ok(destroyed.includes(`orglink/profiles/${b.uploadId}`));
  } finally { await deleteApp(app); }
});
