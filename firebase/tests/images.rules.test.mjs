import { readFileSync } from 'node:fs';
import { before, after, test } from 'node:test';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, setDoc, updateDoc, serverTimestamp, Timestamp } from 'firebase/firestore';
let env;
const profile = uid => ({ uid, email: `${uid}@example.test`, fullName: 'Synthetic Student', studentNumber: '2026000001', yearLevel: 1, section: 'A', accountStatus: 'active', platformRole: 'user', photoURL: null });
before(async () => {
  env = await initializeTestEnvironment({ projectId: 'orglink-dev', firestore: { rules: readFileSync(new URL('../firebase.rules', import.meta.url), 'utf8') } });
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async c => {
    const db = c.firestore();
    for (const uid of ['student', 'manager', 'officer', 'admin']) await setDoc(doc(db, `users/${uid}`), { ...profile(uid), platformRole: uid === 'admin' ? 'platformAdmin' : 'user' });
    await setDoc(doc(db, 'organizations/org'), { organizationId: 'org', status: 'active', visibility: 'public', managerUid: 'manager', logoURL: null });
    await setDoc(doc(db, 'organizations/org/memberships/officer'), { uid: 'officer', organizationId: 'org', membershipRole: 'officer', membershipStatus: 'active', permissions: { manageEvents: true } });
    await setDoc(doc(db, 'organizations/org/events/event'), draft());
  });
});
after(async () => { await env?.cleanup(); });
const database = uid => env.authenticatedContext(uid).firestore();
function draft() {
  return { eventId: 'event', organizationId: 'org', title: 'Synthetic Event', description: 'Synthetic description', posterURL: null,
    startAt: Timestamp.fromMillis(Date.now() + 7200000), endAt: Timestamp.fromMillis(Date.now() + 10800000), venue: 'Synthetic Hall', capacity: 10,
    registrationDeadline: Timestamp.fromMillis(Date.now() + 3600000), registrationCount: 0, eventStatus: 'draft', approvalStatus: 'pending', createdBy: 'officer',
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(), visibility: 'public', submittedAt: null, reviewedAt: null, reviewedBy: null,
    publishedAt: null, cancelledAt: null, completedAt: null, archivedAt: null };
}
test('owners and platform admins cannot directly assign profile URLs/public IDs/revisions', async () => {
  for (const uid of ['student', 'admin']) for (const patch of [{ photoURL: 'https://attacker.test/a.png' }, { photoPublicId: 'forged' }, { imageRevision: 'forged' }])
    await assertFails(updateDoc(doc(database(uid), `users/${uid}`), { ...patch, updatedAt: serverTimestamp() }));
  await assertSucceeds(updateDoc(doc(database('student'), 'users/student'), { fullName: 'McDonald de la Cruz', updatedAt: serverTimestamp() }));
});
test('managers, officers and platform admins cannot assign logos or write upload/cleanup queues', async () => {
  for (const uid of ['student', 'manager', 'officer', 'admin']) {
    await assertFails(updateDoc(doc(database(uid), 'organizations/org'), { logoURL: 'https://attacker.test/a.png', logoPublicId: 'forged' }));
    for (const collection of ['_imageUploads', '_imageSlots', '_imageCleanup']) await assertFails(setDoc(doc(database(uid), `${collection}/forged`), { uid, state: 'complete' }));
  }
});
test('event editors cannot assign poster URLs/public IDs/revisions; ordinary edits still work', async () => {
  for (const uid of ['manager', 'officer']) {
    for (const patch of [{ posterURL: 'https://res.cloudinary.com/forged/image/upload/test.png' }, { posterPublicId: 'forged' }, { imageRevision: 'forged' }])
      await assertFails(updateDoc(doc(database(uid), 'organizations/org/events/event'), { ...patch, updatedAt: serverTimestamp() }));
  }
  await assertSucceeds(updateDoc(doc(database('officer'), 'organizations/org/events/event'), { title: 'IEEE iOS Event', updatedAt: serverTimestamp() }));
});
test('creating a draft with an unverified poster is denied', async () => {
  const db = database('officer');
  await assertFails(setDoc(doc(db, 'organizations/org/events/forged'), { ...draft(), eventId: 'forged', posterURL: 'https://attacker.test/a.png' }));
  await assertSucceeds(setDoc(doc(db, 'organizations/org/events/valid'), { ...draft(), eventId: 'valid' }));
});
