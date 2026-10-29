import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { imageBackend, cloudinarySignature } from '../src/images.js';
import { createHandler } from '../src/index.js';
import { MemoryDb } from './support/memory_db.js';

const env = { CLOUDINARY_CLOUD_NAME: 'synthetic-test', CLOUDINARY_API_KEY: '123', CLOUDINARY_API_SECRET: 'synthetic-secret' };
const profile = uid => ({ uid, email: `${uid}@example.test`, fullName: 'Synthetic Student', studentNumber: '2026000001', yearLevel: 1, section: 'A', accountStatus: 'active' });
const request = (uid, data) => ({ auth: { uid }, data });
const png = Buffer.from([137,80,78,71,13,10,26,10]).toString('base64');
function fixture() {
  const db = new MemoryDb();
  for (const uid of ['student', 'other', 'manager', 'officer']) db.seed(`users/${uid}`, profile(uid));
  db.seed('organizations/org', { managerUid: 'manager', organizationId: 'org', status: 'active' });
  db.seed('organizations/org/memberships/officer', { uid: 'officer', organizationId: 'org', membershipRole: 'officer', membershipStatus: 'active', permissions: { manageEvents: true } });
  db.seed('organizations/org/events/event', { organizationId: 'org', eventId: 'event', createdBy: 'officer', eventStatus: 'draft', approvalStatus: 'pending', submittedAt: null });
  let now = 1700000000000, invalid = {}, calls = [], failUpload = false;
  const assets = new Map();
  const fetchImpl = async (url, options) => {
    calls.push({ url, options });
    assert.equal(options.redirect, 'manual');
    if (url.endsWith('/image/upload')) {
      if (failUpload) throw Error('synthetic transport failure');
      const params = Object.fromEntries([...options.body.entries()].filter(([k]) => !['file', 'api_key', 'signature'].includes(k)));
      assert.equal(options.body.get('signature'), await cloudinarySignature(params, env.CLOUDINARY_API_SECRET));
      assert.equal(params.overwrite, 'false');
      assert.equal(params.asset_folder, params.public_id.slice(0, params.public_id.lastIndexOf('/')));
      assert.equal(options.body.has('folder'), false);
      const id = params.public_id;
      const a = { public_id: id, resource_type: 'image', type: 'upload', format: 'png', bytes: 100, width: 200, height: 200,
        secure_url: `https://res.cloudinary.com/synthetic-test/image/upload/v1/${id}.png` };
      assets.set(id, a);
      return Response.json(a);
    }
    if (url.endsWith('/image/destroy')) return Response.json({ result: 'ok' });
    const id = decodeURIComponent(url.split('/resources/image/upload/')[1]);
    return Response.json({ ...assets.get(id), ...invalid });
  };
  return { db, assets, calls, api: imageBackend(db, env, () => now, fetchImpl),
    advance: ms => now += ms, invalid: value => invalid = value, failUpload: () => failUpload = true };
}
async function uploaded(f, uid = 'student', resource = { kind: 'profile' }) {
  const s = await f.api.sign(request(uid, resource));
  await f.api.upload(request(uid, { uploadId: s.uploadId, signature: s.signature, file: png }));
  return s;
}
test('Cloudinary SHA-256 signing sorts fields exactly and never returns the secret', async () => {
  const params = { timestamp: '10', public_id: 'orglink/profiles/test', overwrite: 'false', asset_folder: 'orglink/profiles' };
  assert.equal(await cloudinarySignature(params, 'synthetic'), createHash('sha256').update('asset_folder=orglink/profiles&overwrite=false&public_id=orglink/profiles/test&timestamp=10synthetic').digest('hex'));
  const f = fixture(), s = await f.api.sign(request('student', { kind: 'profile' }));
  assert.equal(s.maxBytes, 5242880);
  assert.equal(JSON.stringify(s).includes(env.CLOUDINARY_API_SECRET), false);
  assert.equal(s.expiresAt, 1700000300000);
});
test('all resource kinds upload to signed dynamic asset folders without changing their public IDs or references', async () => {
  for (const [uid, resource, folder, path, field, publicIdField] of [
    ['student', { kind: 'profile' }, 'profiles', 'users/student', 'photoURL', 'photoPublicId'],
    ['manager', { kind: 'organization', organizationId: 'org' }, 'organizations', 'organizations/org', 'logoURL', 'logoPublicId'],
    ['officer', { kind: 'event', organizationId: 'org', eventId: 'event' }, 'events', 'organizations/org/events/event', 'posterURL', 'posterPublicId'],
  ]) {
    const f = fixture(), s = await uploaded(f, uid, resource);
    const form = f.calls.find(call => call.url.endsWith('/image/upload')).options.body;
    const publicId = `orglink/${folder}/${s.uploadId}`;
    assert.equal(form.get('asset_folder'), `orglink/${folder}`);
    assert.equal(form.get('public_id'), publicId);
    const params = Object.fromEntries([...form.entries()].filter(([key]) => !['file', 'api_key', 'signature'].includes(key)));
    const expected = createHash('sha256').update(Object.keys(params).sort().map(key => `${key}=${params[key]}`).join('&') + env.CLOUDINARY_API_SECRET).digest('hex');
    assert.equal(form.get('signature'), expected);
    delete params.asset_folder;
    assert.notEqual(form.get('signature'), await cloudinarySignature(params, env.CLOUDINARY_API_SECRET));
    await f.api.finalize(request(uid, { uploadId: s.uploadId }));
    assert.equal(f.db.get(path)[publicIdField], publicId);
    assert.equal(f.db.get(path)[field], `https://res.cloudinary.com/synthetic-test/image/upload/v1/${publicId}.png`);
  }
});
test('profile finalization verifies upstream asset, preserves data and is idempotent; upload replay denied', async () => {
  const f = fixture(), s = await uploaded(f);
  const data = { uploadId: s.uploadId };
  await f.api.finalize(request('student', data));
  const p = f.db.get('users/student');
  assert.equal(p.photoPublicId, `orglink/profiles/${s.uploadId}`);
  assert.equal(p.studentNumber, '2026000001');
  assert.equal(p.imageRevision, s.uploadId);
  assert.equal((await f.api.finalize(request('student', data))).duplicate, true);
  await assert.rejects(f.api.upload(request('student', { ...data, signature: s.signature, file: png })), e => e.code === 'failed-precondition');
});
test('cannot impersonate a UID or inject URL, path, public ID or extra parameters', async () => {
  const f = fixture();
  for (const extra of [{ uid: 'other' }, { folder: 'x' }, { asset_folder: 'attacker/folder' }, { publicId: 'x' }, { photoURL: 'https://attacker.test' }])
    await assert.rejects(f.api.sign(request('student', { kind: 'profile', ...extra })), e => e.code === 'invalid-argument');
  for (const data of [{ kind: 'event', organizationId: '../x', eventId: 'x' }, { kind: 'profile', organizationId: 'org' }])
    await assert.rejects(f.api.sign(request('student', data)), e => e.code === 'invalid-argument');
  const s = await uploaded(f);
  await assert.rejects(f.api.upload(request('student', { uploadId: s.uploadId, signature: s.signature, file: png, asset_folder: 'attacker/folder' })), e => e.code === 'invalid-argument');
  await assert.rejects(f.api.finalize(request('other', { uploadId: s.uploadId })), e => e.code === 'permission-denied');
  await assert.rejects(f.api.finalize(request('student', { uploadId: s.uploadId, secure_url: 'https://attacker.test' })), e => e.code === 'invalid-argument');
});
test('active manager logos and own-draft event officers only; role claims never grant access', async () => {
  const f = fixture();
  const org = { kind: 'organization', organizationId: 'org' }, event = { ...org, kind: 'event', eventId: 'event' };
  for (const uid of ['student', 'officer']) await assert.rejects(f.api.sign(request(uid, org)), e => e.code === 'permission-denied');
  for (const uid of ['student', 'other']) await assert.rejects(f.api.sign(request(uid, event)), e => e.code === 'permission-denied');
  for (const [uid, r] of [['manager', org], ['officer', event]]) {
    const s = await uploaded(f, uid, r); await f.api.finalize(request(uid, { uploadId: s.uploadId }));
  }
  f.advance(11000);
  f.db.seed('organizations/org/events/event', { ...f.db.get('organizations/org/events/event'), createdBy: 'other' });
  await assert.rejects(f.api.sign(request('officer', event)), e => e.code === 'permission-denied');
});
test('revoked permissions, inactive accounts and submitted/published/archived events fail closed', async () => {
  for (const patch of [{ submittedAt: 1 }, { eventStatus: 'published' }, { archivedAt: 1 }]) {
    const f = fixture(); f.db.seed('organizations/org/events/event', { ...f.db.get('organizations/org/events/event'), ...patch });
    await assert.rejects(f.api.sign(request('manager', { kind: 'event', organizationId: 'org', eventId: 'event' })), e => e.code === 'failed-precondition');
  }
  const f = fixture(), s = await uploaded(f, 'officer', { kind: 'event', organizationId: 'org', eventId: 'event' });
  f.db.seed('organizations/org/memberships/officer', { ...f.db.get('organizations/org/memberships/officer'), membershipStatus: 'removed' });
  await assert.rejects(f.api.finalize(request('officer', { uploadId: s.uploadId })), e => e.code === 'permission-denied');
  for (const status of ['disabled', 'suspended', 'rejected']) {
    f.db.seed('users/student', { ...profile('student'), accountStatus: status });
    await assert.rejects(f.api.sign(request('student', { kind: 'profile' })), e => e.code === 'permission-denied');
  }
});
test('existing platform organization administration can manage verified logos without gaining event access', async () => {
  const f = fixture(); f.db.seed('users/admin', { ...profile('admin'), platformRole: 'platformAdmin' });
  const s = await uploaded(f, 'admin', { kind: 'organization', organizationId: 'org' });
  await f.api.finalize(request('admin', { uploadId: s.uploadId }));
  assert.equal(f.db.get('organizations/org').logoPublicId, `orglink/organizations/${s.uploadId}`);
  await assert.rejects(f.api.sign(request('admin', { kind: 'event', organizationId: 'org', eventId: 'event' })), e => e.code === 'permission-denied');
  f.db.seed('users/admin', { ...profile('admin'), platformRole: 'platformAdmin', accountStatus: 'disabled' });
  await assert.rejects(f.api.remove(request('admin', { kind: 'organization', organizationId: 'org', expectedURL: f.db.get('organizations/org').logoURL })), e => e.code === 'permission-denied');
});
test('malformed/oversized files, forged assets and expiry cannot assign a reference', async () => {
  const f = fixture(), s = await f.api.sign(request('student', { kind: 'profile' }));
  for (const file of ['<svg></svg>', Buffer.from('%PDF fake').toString('base64'), 'A'.repeat(6990509)])
    await assert.rejects(f.api.upload(request('student', { uploadId: s.uploadId, signature: s.signature, file })), e => e.code === 'invalid-argument');
  await f.api.upload(request('student', { uploadId: s.uploadId, signature: s.signature, file: png }));
  for (const invalid of [{ public_id: 'orglink/profiles/other' }, { bytes: 5242881 }, { width: 5000 }, { format: 'svg' }, { resource_type: 'video' }, { pages: 2 }, { secure_url: 'http://attacker.test' }]) {
    f.invalid(invalid);
    await assert.rejects(f.api.finalize(request('student', { uploadId: s.uploadId })), e => e.code === 'invalid-argument');
    assert.equal(f.db.get('users/student').photoURL, undefined);
  }
  f.invalid({}); f.advance(300001);
  await assert.rejects(f.api.finalize(request('student', { uploadId: s.uploadId })), e => e.code === 'failed-precondition');
});
test('concurrent uploads have one winner, stale remove fails; replacement/removal queue owned assets only', async () => {
  const f = fixture(), a = await uploaded(f);
  f.advance(11000); const b = await uploaded(f);
  const results = await Promise.allSettled([a, b].map(s => f.api.finalize(request('student', { uploadId: s.uploadId }))));
  assert.equal(results.filter(r => r.status === 'fulfilled').length, 1);
  const p = f.db.get('users/student');
  await assert.rejects(f.api.remove(request('student', { kind: 'profile', expectedURL: 'stale' })), e => e.code === 'conflict');
  await f.api.remove(request('student', { kind: 'profile', expectedURL: p.photoURL }));
  assert.equal(f.db.get('users/student').photoURL, null);
  assert.equal(f.db.get(`_imageCleanup/${p.photoPublicId.split('/').at(-1)}`).publicId, p.photoPublicId);
});
test('network failure consumes upload ticket; retry cannot overwrite an uncertain upload', async () => {
  const f = fixture(), s = await f.api.sign(request('student', { kind: 'profile' }));
  f.failUpload();
  await assert.rejects(f.api.upload(request('student', { uploadId: s.uploadId, signature: s.signature, file: png })));
  await assert.rejects(f.api.upload(request('student', { uploadId: s.uploadId, signature: s.signature, file: png })), e => e.code === 'failed-precondition');
});
test('signed tickets reject tampering, expired upload attempts and cross-session replay', async () => {
  const f = fixture(), s = await f.api.sign(request('student', { kind: 'profile' }));
  for (const signature of [undefined, '', 'f'.repeat(64)])
    await assert.rejects(f.api.upload(request('student', { uploadId: s.uploadId, signature, file: png })), e => e.code === 'permission-denied');
  f.advance(11000); const other = await f.api.sign(request('other', { kind: 'profile' }));
  await assert.rejects(f.api.upload(request('other', { uploadId: other.uploadId, signature: s.signature, file: png })), e => e.code === 'permission-denied');
  f.advance(300001);
  await assert.rejects(f.api.upload(request('student', { uploadId: s.uploadId, signature: s.signature, file: png })), e => e.code === 'failed-precondition');
  assert.equal(f.calls.length, 0);
});
test('missing Cloudinary bindings fail closed without upstream access', async () => {
  const f = fixture();
  for (const key of Object.keys(env)) {
    const missing = { ...env }; delete missing[key];
    await assert.rejects(imageBackend(f.db, missing).sign(request('student', { kind: 'profile' })), e => e.stage === 'images.configuration');
  }
  assert.equal(f.calls.length, 0);
});
test('image HTTP endpoints reject missing/forged tokens before any upstream call', async () => {
  const handler = createHandler({ fetchImpl: () => { throw Error('must not fetch'); } });
  for (const path of ['sign', 'upload', 'finalize', 'remove']) for (const token of ['', 'Bearer forged.token.value']) {
    const response = await handler(new Request(`https://example.test/images/${path}`, { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: token }, body: '{}' }), env);
    assert.equal(response.status, 401);
  }
});
test('cleanup retires expired sessions and destroys orphans but retains current completed assets', async () => {
  const f = fixture(), current = await uploaded(f);
  await f.api.finalize(request('student', { uploadId: current.uploadId }));
  f.advance(11000); const orphan = await uploaded(f); f.advance(4000000);
  // Numeric range query implemented by the real REST adapter; emulate here.
  f.db.query = async q => [...f.db.records].filter(([p, record]) => {
    const filter = q.where.fieldFilter;
    return p.startsWith(q.from[0].collectionId + '/') && record.value[filter.field.fieldPath] < Number(filter.value.integerValue);
  }).slice(0, q.limit).map(([p, r]) => ({ ...r.value, id: p.split('/').at(-1) }));
  await f.api.cleanup(); f.advance(61000); await f.api.cleanup();
  const destroyed = f.calls.filter(c => c.url.endsWith('/image/destroy')).map(c => c.options.body.get('public_id'));
  assert.deepEqual(destroyed, [`orglink/profiles/${orphan.uploadId}`]);
  assert.equal(f.db.get('users/student').imageRevision, current.uploadId);
});
