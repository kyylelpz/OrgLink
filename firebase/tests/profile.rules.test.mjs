import assert from 'node:assert/strict';
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
  platformRole: 'user', accountStatus: 'pending', college:'College of Engineering', program:'Bachelor of Science in Computer Engineering', createdAt: serverTimestamp(), updatedAt: serverTimestamp()});
async function seed(overrides = {}) {
  await env.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(), 'users/alice'), {...profile(), ...overrides});
  });
}
test('direct profile creation is denied; owner can read a trusted-created pending profile', async () => {
  const ref = doc(db(), 'users/alice');
  await assertFails(setDoc(ref, profile()));
  await seed();
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
  {platformRole: 'platformAdmin'}, {platformRole: 'officer'}, {accountStatus: 'active'},
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
    fullName: 'Alice Updated', yearLevel: 2, section: 'B', updatedAt: serverTimestamp(),
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


test('optional academics accept new and legacy profiles without privilege changes', async () => {
  const ref = doc(db(), 'users/alice');
  await seed();
  await assertSucceeds(updateDoc(ref, {section:'B', updatedAt:serverTimestamp()}));
  const data = (await getDoc(ref)).data();
  assert.equal(data.college, 'College of Engineering');
  assert.equal(data.program, 'Bachelor of Science in Computer Engineering');
  assert.equal(data.platformRole, 'user');
  await assertFails(updateDoc(ref, {program:'Valid Program', platformRole:'platformAdmin', updatedAt:serverTimestamp()}));
});

test('legacy profiles may add optional academics or leave them blank', async () => {
  await seed();
  const ref = doc(db(), 'users/alice');
  await assertSucceeds(updateDoc(ref, {college:'College of Engineering', program:'Bachelor of Science in Computer Engineering', updatedAt:serverTimestamp()}));
  await assertFails(updateDoc(ref, {college:'', program:'', updatedAt:serverTimestamp()}));
  await assertFails(updateDoc(doc(db('bob'), 'users/alice'), {college:'Other', updatedAt:serverTimestamp()}));
});
for (const value of [null, 42, 'x', 'a'.repeat(161), '  ', 'College\nName']) {
  test(`reject invalid academic ${JSON.stringify(value)}`, async () => {
    await seed();
    await assertFails(updateDoc(doc(db(), 'users/alice'), {college:value, updatedAt:serverTimestamp()}));
  });
}

for (const verified of [false, true]) {
  test(`password identity verification=${verified} gates profile creation without approval bypass`, async () => {
    const password = env.authenticatedContext('alice', {email:'alice@example.edu', email_verified:verified, firebase:{sign_in_provider:'password'}}).firestore();
    const ref = doc(password, 'users/alice');
    await assertFails(setDoc(ref, profile()));
    await assertFails(setDoc(ref, {...profile(), accountStatus:'active'}));
    await env.withSecurityRulesDisabled(async c => setDoc(doc(c.firestore(), 'users/alice'), {...profile(),accountStatus:'active'}));
    await (verified ? assertSucceeds : assertFails)(updateDoc(ref, {section:'B',updatedAt:serverTimestamp()}));
    await env.withSecurityRulesDisabled(async c => setDoc(doc(c.firestore(),'organizations/example'),{status:'active',visibility:'public',managerUid:'manager'}));
    await (verified ? assertSucceeds : assertFails)(getDoc(doc(password,'organizations/example')));
  });
}
test('pending account cannot access organizations and cannot approve itself', async () => {
  await seed();
  await assertFails(getDoc(doc(db(),'organizations/missing')));
  await assertFails(updateDoc(doc(db(),'users/alice'),{accountStatus:'active',updatedAt:serverTimestamp()}));
});
test('legacy academic values remain readable and unchanged until an explicit controlled replacement', async () => {
  await seed({college:'IEEE College',program:'iOS Research',accountStatus:'active'});
  const ref=doc(db(),'users/alice');
  await assertSucceeds(updateDoc(ref,{section:'B',updatedAt:serverTimestamp()}));
  assert.equal((await getDoc(ref)).data().program,'iOS Research');
  await assertFails(updateDoc(ref,{program:'Unlisted Program',updatedAt:serverTimestamp()}));
  await assertSucceeds(updateDoc(ref,{college:'College of Engineering',program:'Bachelor of Science in Civil Engineering',updatedAt:serverTimestamp()}));
});

test('direct Student ID changes and registry enumeration/claims are denied even to a platform admin',async()=>{
  await seed({platformRole:'platformAdmin',accountStatus:'active'});
  await assertFails(updateDoc(doc(db(),'users/alice'),{studentNumber:'2026000001',updatedAt:serverTimestamp()}));
  await assertFails(setDoc(doc(db(),'studentIds/2026000001'),{uid:'alice',state:'active'}));
  await assertFails(getDoc(doc(db(),'studentIds/2026000001')));
});
