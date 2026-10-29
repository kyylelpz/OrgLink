import { AttendanceError } from './attendance.js';
import { BackendError, Timestamp } from './firestore.js';
import { completeProfile, validId } from './admin.js';

const MAX = 5 * 1024 * 1024;
const TTL = 5 * 60 * 1000;
const fail = (code, message) => { throw new AttendanceError(code, message); };
const hex = bytes => Array.from(new Uint8Array(bytes), b => b.toString(16).padStart(2, '0')).join('');
async function ticketKey(secret) {
  return crypto.subtle.importKey('raw', new TextEncoder().encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign', 'verify']);
}
const ticketMessage = (uid, uploadId, expiresAt) => new TextEncoder().encode(JSON.stringify(['orglink-image-upload-v1', uid, uploadId, expiresAt]));
export async function cloudinarySignature(params, secret) {
  const value = Object.keys(params).sort().map(k => `${k}=${params[k]}`).join('&') + secret;
  return hex(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value)));
}
function config(env) {
  if (!/^[a-z0-9_-]+$/i.test(env.CLOUDINARY_CLOUD_NAME ?? '') ||
      !/^\d+$/.test(env.CLOUDINARY_API_KEY ?? '') || !env.CLOUDINARY_API_SECRET)
    throw new BackendError('images.configuration', 'missing-cloudinary-bindings');
}
function resource(uid, data) {
  if (!validId(uid)) fail('unauthenticated', 'Sign in again.');
  const { kind, organizationId, eventId } = data;
  if (!['profile', 'organization', 'event'].includes(kind) ||
      (kind === 'profile' && (organizationId != null || eventId != null)) ||
      (kind === 'organization' && eventId != null) ||
      (kind !== 'profile' && !validId(organizationId)) || (kind === 'event' && !validId(eventId)))
    fail('invalid-argument', 'Choose a valid image resource.');
  return { kind, organizationId: kind === 'profile' ? null : organizationId,
    eventId: kind === 'event' ? eventId : null,
    path: kind === 'profile' ? `users/${uid}` : `organizations/${organizationId}${kind === 'event' ? `/events/${eventId}` : ''}`,
    field: { profile: 'photoURL', organization: 'logoURL', event: 'posterURL' }[kind],
    publicIdField: { profile: 'photoPublicId', organization: 'logoPublicId', event: 'posterPublicId' }[kind],
    folder: { profile: 'profiles', organization: 'organizations', event: 'events' }[kind] };
}
async function authorize(db, t, uid, r) {
  const names = [`users/${uid}`, r.path];
  if (r.kind !== 'profile') names.push(`organizations/${r.organizationId}`, `organizations/${r.organizationId}/memberships/${uid}`);
  const docs = await t.getAll(...names.map(p => db.doc(p)));
  const [actor, target, org, member] = docs.map(d => d.data());
  if (!actor || actor.uid !== uid || !completeProfile(actor) ||
      (r.kind === 'profile' ? !['active', 'pending'].includes(actor.accountStatus) : actor.accountStatus !== 'active'))
    fail('permission-denied', 'An eligible student account is required.');
  if (!target) fail('not-found', 'This resource no longer exists.');
  if (r.kind !== 'profile') {
    const manager = org?.managerUid === uid;
    // Existing platform administration can configure organizations, but does not grant event-editor access.
    const administrator = r.kind === 'organization' && actor.platformRole === 'platformAdmin';
    const officer = member?.uid === uid && member.organizationId === r.organizationId &&
      member.membershipStatus === 'active' && member.membershipRole === 'officer' && member.permissions?.manageEvents === true;
    if (org?.status !== 'active' || (!manager && !administrator && !(r.kind === 'event' && officer && target.createdBy === uid)))
      fail('permission-denied', 'You cannot manage this image.');
    if (r.kind === 'event' && (target.eventStatus !== 'draft' || target.archivedAt != null ||
        (target.approvalStatus === 'pending' && target.submittedAt != null)))
      fail('failed-precondition', 'Only an editable event draft can change its poster.');
  }
  return target;
}
export function imageBackend(db, env, clock = Date.now, fetchImpl = fetch) {
  async function cloud(path, options) {
    config(env);
    let response;
    try {
      response = await fetchImpl(`https://api.cloudinary.com/v1_1/${env.CLOUDINARY_CLOUD_NAME}/${path}`, {
        ...options, redirect: 'manual', signal: AbortSignal.timeout(20000),
      });
    } catch { throw new BackendError('images.cloudinary', 'transport-error'); }
    if (!response.ok) throw new BackendError('images.cloudinary', 'http-error', response.status);
    try { return await response.json(); } catch { throw new BackendError('images.cloudinary', 'invalid-response'); }
  }
  const adminHeaders = () => ({ Authorization: `Basic ${btoa(`${env.CLOUDINARY_API_KEY}:${env.CLOUDINARY_API_SECRET}`)}` });
  async function inspect(publicId) {
    return cloud(`resources/image/upload/${encodeURIComponent(publicId)}`, { headers: adminHeaders() });
  }
  function validateAsset(a, session) {
    const prefix = `https://res.cloudinary.com/${env.CLOUDINARY_CLOUD_NAME}/image/upload/`;
    if (a.public_id !== session.publicId || a.resource_type !== 'image' || a.type !== 'upload' ||
        !['jpg', 'png', 'webp'].includes(a.format) || !Number.isInteger(a.bytes) || a.bytes < 1 || a.bytes > MAX ||
        !Number.isInteger(a.width) || !Number.isInteger(a.height) || a.width < 1 || a.height < 1 ||
        a.width > 4096 || a.height > 4096 || a.pages > 1 ||
        typeof a.secure_url !== 'string' || !a.secure_url.startsWith(prefix) ||
        !a.secure_url.endsWith(`/${session.publicId}.${a.format}`) || a.secure_url.length > 2048)
      fail('invalid-argument', 'The uploaded asset is not a supported image.');
    return a;
  }
  async function session(uid, data, action) {
    if (!/^[a-f0-9]{64}$/.test(data.uploadId ?? '')) fail('invalid-argument', 'Invalid upload session.');
    return db.runTransaction(async t => {
      const [snap] = await t.getAll(db.doc(`_imageUploads/${data.uploadId}`));
      const s = snap.data();
      if (!s || s.uid !== uid) fail('permission-denied', 'Invalid upload session.');
      const r = resource(uid, s);
      const target = await authorize(db, t, uid, r);
      return action(t, s, r, target);
    });
  }
  const queue = (t, publicId) => {
    if (typeof publicId === 'string' && /^orglink\/(profiles|organizations|events)\/[a-f0-9]{64}$/.test(publicId))
      t.set(db.doc(`_imageCleanup/${publicId.split('/').at(-1)}`), { publicId, after: clock() + 60000, done: false });
  };
  return {
    // Upload tickets, rather than reusable Cloudinary signatures, leave the Worker.
    // This enforces the five-minute deadline, single use, byte cap and image endpoint.
    async sign({ auth, data }) {
      config(env);
      if (Object.keys(data).some(k => !['kind', 'organizationId', 'eventId'].includes(k)))
        fail('invalid-argument', 'Unexpected image parameters.');
      const uid = auth?.uid, r = resource(uid, data);
      const uploadId = hex(crypto.getRandomValues(new Uint8Array(32)));
      return db.runTransaction(async t => {
        const target = await authorize(db, t, uid, r);
        const [slot] = await t.getAll(db.doc(`_imageSlots/${r.path.replaceAll('/', '_')}`));
        if (slot.data()?.issuedAt > clock() - 10000) fail('resource-exhausted', 'Wait a few seconds before choosing another image.');
        const expiresAt = clock() + TTL;
        const publicId = `orglink/${r.folder}/${uploadId}`;
        t.create(db.doc(`_imageUploads/${uploadId}`), { ...r, uid, publicId, expiresAt,
          state: 'pending', revision: target.imageRevision ?? null, createdAt: clock() });
        t.set(db.doc(`_imageSlots/${r.path.replaceAll('/', '_')}`), { issuedAt: clock() });
        const signature = hex(await crypto.subtle.sign('HMAC', await ticketKey(env.CLOUDINARY_API_SECRET), ticketMessage(uid, uploadId, expiresAt)));
        return { uploadId, expiresAt, signature, maxBytes: MAX, uploadPath: '/images/upload' };
      });
    },
    async upload({ auth, data }) {
      if (Object.keys(data).some(k => !['uploadId', 'signature', 'file'].includes(k)) ||
          typeof data.file !== 'string' || data.file.length > Math.ceil(MAX / 3) * 4 ||
          !/^[A-Za-z0-9+/]*={0,2}$/.test(data.file)) fail('invalid-argument', 'Choose an image up to 5 MB.');
      let bytes;
      try { bytes = Uint8Array.from(atob(data.file), c => c.charCodeAt(0)); } catch { fail('invalid-argument', 'Invalid image file.'); }
      const png = bytes[0] === 137 && bytes[1] === 80 && bytes[2] === 78 && bytes[3] === 71;
      const jpg = bytes[0] === 255 && bytes[1] === 216 && bytes[2] === 255;
      const webp = new TextDecoder().decode(bytes.slice(0, 4)) === 'RIFF' && new TextDecoder().decode(bytes.slice(8, 12)) === 'WEBP';
      if (!bytes.length || bytes.length > MAX || !(png || jpg || webp)) fail('invalid-argument', 'Choose a JPEG, PNG or WebP image up to 5 MB.');
      const s = await session(auth?.uid, data, async (t, s) => {
        config(env);
        if (!/^[a-f0-9]{64}$/.test(data.signature ?? '') || !await crypto.subtle.verify('HMAC', await ticketKey(env.CLOUDINARY_API_SECRET),
          Uint8Array.from(data.signature.match(/../g), v => parseInt(v, 16)), ticketMessage(auth.uid, data.uploadId, s.expiresAt)))
          fail('permission-denied', 'Invalid upload signature.');
        if (s.expiresAt <= clock() || s.state !== 'pending') fail('failed-precondition', 'This upload expired or was already used. Choose the image again.');
        t.update(db.doc(`_imageUploads/${data.uploadId}`), { state: 'uploading' });
        return s;
      });
      const params = { public_id: s.publicId, asset_folder: `orglink/${s.folder}`, timestamp: String(Math.floor(clock() / 1000)),
        overwrite: 'false', allowed_formats: 'jpg,png,webp', transformation: 'c_limit,w_2048,h_2048' };
      const form = new FormData();
      for (const [k, v] of Object.entries(params)) form.set(k, v);
      form.set('api_key', env.CLOUDINARY_API_KEY);
      form.set('signature', await cloudinarySignature(params, env.CLOUDINARY_API_SECRET));
      form.set('file', new Blob([bytes], { type: png ? 'image/png' : jpg ? 'image/jpeg' : 'image/webp' }), 'image');
      validateAsset(await cloud('image/upload', { method: 'POST', body: form }), s);
      return { uploadId: data.uploadId, uploaded: true };
    },
    async finalize({ auth, data }) {
      if (Object.keys(data).some(k => k !== 'uploadId')) fail('invalid-argument', 'Unexpected asset reference.');
      const initial = await session(auth?.uid, data, (_t, s) => s);
      if (initial.state === 'complete') return { saved: true, duplicate: true };
      if (initial.state !== 'uploading' || initial.expiresAt <= clock()) fail('failed-precondition', 'This upload expired. Choose the image again.');
      const asset = validateAsset(await inspect(initial.publicId), initial);
      return session(auth.uid, data, (t, s, r, target) => {
        if (s.state === 'complete') return { saved: true, duplicate: true };
        if (s.state !== 'uploading' || s.expiresAt <= clock() || (target.imageRevision ?? null) !== s.revision)
          fail('conflict', 'The image changed or this upload expired. Refresh before trying again.');
        queue(t, target[r.publicIdField]);
        t.update(db.doc(r.path), { [r.field]: asset.secure_url, [r.publicIdField]: s.publicId,
          imageRevision: data.uploadId, updatedAt: Timestamp.fromMillis(clock()),
          ...(r.kind === 'event' ? { approvalStatus: 'pending', submittedAt: null } : {}) });
        t.update(db.doc(`_imageUploads/${data.uploadId}`), { state: 'complete' });
        return { saved: true };
      });
    },
    async remove({ auth, data }) {
      if (Object.keys(data).some(k => !['kind', 'organizationId', 'eventId', 'expectedURL'].includes(k)) ||
          !(data.expectedURL === null || typeof data.expectedURL === 'string')) fail('invalid-argument', 'Invalid image removal.');
      const r = resource(auth?.uid, data);
      return db.runTransaction(async t => {
        const target = await authorize(db, t, auth.uid, r);
        if ((target[r.field] ?? null) !== data.expectedURL) fail('conflict', 'The image changed. Refresh before removing it.');
        queue(t, target[r.publicIdField]);
        t.update(db.doc(r.path), { [r.field]: null, [r.publicIdField]: null,
          imageRevision: crypto.randomUUID(), updatedAt: Timestamp.fromMillis(clock()),
          ...(r.kind === 'event' ? { approvalStatus: 'pending', submittedAt: null } : {}) });
        return { removed: true };
      });
    },
    async cleanup() {
      // Bounded queues; retry failures on the next scheduled invocation. Never delete a pending/current asset.
      const rows = await db.query({ from: [{ collectionId: '_imageUploads' }],
        where: { fieldFilter: { field: { fieldPath: 'expiresAt' }, op: 'LESS_THAN', value: { integerValue: String(clock() - 3600000) } } }, limit: 50 });
      for (const row of rows) await db.runTransaction(async t => {
        const [snap] = await t.getAll(db.doc(`_imageUploads/${row.id}`));
        const s = snap.data();
        if (!s || s.state === 'cleaned' || s.expiresAt >= clock() - 3600000) return;
        if (s.state !== 'complete') queue(t, s.publicId);
        // Retain a tombstone for idempotency until operator-configured TTL deletes it.
        t.update(db.doc(`_imageUploads/${row.id}`), { state: 'cleaned', expiresAt: Number.MAX_SAFE_INTEGER,
          deleteAfter: Timestamp.fromMillis(clock() + 7 * 86400000) });
      });
      const pending = await db.query({ from: [{ collectionId: '_imageCleanup' }],
        where: { fieldFilter: { field: { fieldPath: 'after' }, op: 'LESS_THAN', value: { integerValue: String(clock()) } } }, limit: 50 });
      for (const item of pending) {
        if (!/^orglink\/(profiles|organizations|events)\/[a-f0-9]{64}$/.test(item.publicId)) continue;
        const params = { public_id: item.publicId, timestamp: String(Math.floor(clock() / 1000)), invalidate: 'true' };
        const form = new URLSearchParams({ ...params, api_key: env.CLOUDINARY_API_KEY,
          signature: await cloudinarySignature(params, env.CLOUDINARY_API_SECRET) });
        const result = await cloud('image/destroy', { method: 'POST', body: form });
        if (!['ok', 'not found'].includes(result.result)) throw new BackendError('images.cleanup', 'delete-failed');
        await db.runTransaction(async t => {
          t.update(db.doc(`_imageCleanup/${item.id}`), { done: true, after: Number.MAX_SAFE_INTEGER,
            deleteAfter: Timestamp.fromMillis(clock() + 7 * 86400000) });
        });
      }
    },
  };
}
