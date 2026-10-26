import {readFileSync} from 'node:fs';
import {before, after, beforeEach, test} from 'node:test';
import {initializeTestEnvironment, assertSucceeds, assertFails} from '@firebase/rules-unit-testing';
import {doc, collection, getDoc, getDocs, setDoc, updateDoc, deleteDoc, serverTimestamp, Timestamp} from 'firebase/firestore';

let env;
before(async () => {
  env = await initializeTestEnvironment({projectId: 'orglink-dev', firestore: {
    rules: readFileSync(new URL('../firebase.rules', import.meta.url), 'utf8'),
  }});
});
after(async () => { await env?.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); });
const db = (uid = 'alice') => env.authenticatedContext(uid, {email: `${uid}@example.edu`}).firestore();
const profile = () => ({uid: 'alice', email: 'alice@example.edu', fullName: 'Alice Student',
  studentNumber: '2026-001', yearLevel: 1, section: 'A', photoURL: null,
  platformRole: 'user', accountStatus: 'active', createdAt: serverTimestamp(), updatedAt: serverTimestamp()});
async function seed(overrides = {}) {
  await env.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(), 'users/alice'), {...profile(), ...overrides});
  });
}
test('owner can create active user profile and read it', async () => {
  const ref = doc(db(), 'users/alice');
  await assertSucceeds(setDoc(ref, profile()));
  await assertSucceeds(getDoc(ref));
});
test('unauthenticated and other students cannot read private profiles', async () => {
  await seed();
  await assertFails(getDoc(doc(db('bob'), 'users/alice')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'users/alice')));
  await assertFails(getDocs(collection(db(), 'users')));
});
test('cannot create a profile for another UID', async () => {
  await assertFails(setDoc(doc(db('bob'), 'users/alice'), profile()));
});
for (const override of [
  {platformRole: 'platformAdmin'}, {platformRole: 'officer'}, {accountStatus: 'pending'},
  {uid: 'bob'}, {email: 'bob@example.edu'}, {fullName: ''}, {fullName: '    '},
  {studentNumber: '!'}, {yearLevel: 0}, {yearLevel: 7}, {yearLevel: 1.5},
  {section: ''}, {extra: true}, {createdAt: Timestamp.fromMillis(0)},
  {updatedAt: Timestamp.fromMillis(0)}, {photoURL: 123},
]) {
  test(`reject invalid creation ${JSON.stringify(override)}`, async () => {
    await assertFails(setDoc(doc(db(), 'users/alice'), {...profile(), ...override}));
  });
}
test('required fields cannot be omitted', async () => {
  const data = profile(); delete data.platformRole;
  await assertFails(setDoc(doc(db(), 'users/alice'), data));
});
test('owner can edit permitted fields with server timestamp', async () => {
  await seed({platformRole: 'platformAdmin', accountStatus: 'suspended'});
  await assertSucceeds(updateDoc(doc(db(), 'users/alice'), {
    fullName: 'Alice Updated', studentNumber: '2026-002', yearLevel: 2, section: 'B', updatedAt: serverTimestamp(),
  }));
});
for (const change of [{platformRole:'platformAdmin'}, {accountStatus:'suspended'},
  {uid:'bob'}, {email:'bob@example.edu'}, {photoURL:'changed'}, {createdAt:Timestamp.fromMillis(0)}, {extra:true}]) {
  test(`reject protected field update ${JSON.stringify(change)}`, async () => {
    await seed();
    await assertFails(updateDoc(doc(db(), 'users/alice'), {...change, updatedAt:serverTimestamp()}));
  });
}
test('a suspended account cannot reactivate itself', async () => {
  await seed({accountStatus:'suspended'});
  await assertFails(updateDoc(doc(db(), 'users/alice'), {accountStatus:'active', updatedAt:serverTimestamp()}));
});
test('reject invalid edits, client timestamps, deletes and unrelated collections', async () => {
  await seed();
  await assertFails(updateDoc(doc(db(), 'users/alice'), {yearLevel:9, updatedAt:serverTimestamp()}));
  await assertFails(updateDoc(doc(db(), 'users/alice'), {fullName:'New Name', updatedAt:Timestamp.fromMillis(0)}));
  await assertFails(updateDoc(doc(db('bob'), 'users/alice'), {fullName:'New Name', updatedAt:serverTimestamp()}));
  await assertFails(deleteDoc(doc(db(), 'users/alice')));
  await assertFails(setDoc(doc(db(), 'organizations/test'), {name:'test'}));
  await assertFails(getDoc(doc(db(), 'organizations/test')));
});
