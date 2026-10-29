import assert from 'node:assert/strict';
import {test} from 'node:test';
import {readFileSync} from 'node:fs';
import {initializeTestEnvironment, assertSucceeds, assertFails} from '@firebase/rules-unit-testing';
import {initializeApp, deleteApp} from 'firebase/app';
import {getAuth, connectAuthEmulator, createUserWithEmailAndPassword, sendEmailVerification, applyActionCode,
  reload, signOut, signInWithEmailAndPassword, sendPasswordResetEmail, verifyPasswordResetCode, confirmPasswordReset,
  reauthenticateWithCredential, linkWithCredential, GoogleAuthProvider, signInWithCredential, EmailAuthProvider} from 'firebase/auth';
import {getFirestore, connectFirestoreEmulator, doc, setDoc, getDoc, updateDoc, serverTimestamp} from 'firebase/firestore';

const available = !!process.env.FIREBASE_AUTH_EMULATOR_HOST && !!process.env.FIRESTORE_EMULATOR_HOST;
const projectId = 'orglink-dev';
test('Auth emulator: verification + pending approval + reset preserve UID and protected data', {skip: !available}, async t => {
  // Both endpoints are explicitly bound to local emulators before any SDK request.
  const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
  const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST;
  assert.match(authHost, /^(127\.0\.0\.1|localhost):\d+$/);
  assert.match(firestoreHost, /^(127\.0\.0\.1|localhost):\d+$/);
  const env = await initializeTestEnvironment({projectId, firestore:{rules:readFileSync(new URL('../firebase.rules',import.meta.url),'utf8')}});
  const app = initializeApp({projectId, apiKey:'emulator-test-key', authDomain:`${projectId}.firebaseapp.com`}, 'email-auth-integration');
  const auth=getAuth(app); connectAuthEmulator(auth, `http://${authHost}`, {disableWarnings:true});
  const db=getFirestore(app); const [host,port]=firestoreHost.split(':'); connectFirestoreEmulator(db,host,Number(port));
  const email=`email-${Date.now()}@example.edu`, password='SyntheticTest123!';
  async function codeFor(type, address=email) {
    const response=await fetch(`http://${authHost}/emulator/v1/projects/${projectId}/oobCodes`);
    assert.equal(response.status,200);
    const {oobCodes}=await response.json();
    const code=oobCodes.filter(entry=>entry.email===address && entry.requestType===type).at(-1)?.oobCode;
    assert.ok(code); return code;
  }
  try {
    const {user}=await createUserWithEmailAndPassword(auth,email,password); const uid=user.uid;
    const ref=doc(db,'users',uid);
    const profile={uid,email,fullName:'Synthetic Email Student', studentNumber:'2026-123',yearLevel:1,section:'A',
      college:'College of Engineering',program:'Bachelor of Science in Computer Engineering',photoURL:null,
      platformRole:'user',accountStatus:'pending',createdAt:serverTimestamp(),updatedAt:serverTimestamp()};
    await assertFails(setDoc(ref,profile)); // Unverified auth alone cannot create a profile.
    await sendEmailVerification(user);
    await applyActionCode(auth,await codeFor('VERIFY_EMAIL')); await reload(user); await user.getIdToken(true);
    assert.equal(user.emailVerified,true);
    await assertSucceeds(setDoc(ref,profile));
    await assertFails(updateDoc(ref,{accountStatus:'active',updatedAt:serverTimestamp()}));
    await assertFails(setDoc(doc(db,'users','different-uid'),{...profile,uid:'different-uid'}));
    await env.withSecurityRulesDisabled(async context=>setDoc(doc(context.firestore(),'organizations','email-public'),
      {name:'Synthetic Organization',status:'active',visibility:'public',managerUid:'manager'}));
    await assertFails(getDoc(doc(db,'organizations','email-public'))); // Verified is still pending.
    await env.withSecurityRulesDisabled(async context=>updateDoc(doc(context.firestore(),'users',uid),{accountStatus:'active'}));
    await assertSucceeds(getDoc(doc(db,'organizations','email-public')));
    await signOut(auth);
    await assert.rejects(createUserWithEmailAndPassword(auth,email,password));
    const signed=await signInWithEmailAndPassword(auth,email,password); assert.equal(signed.user.uid,uid);
    const unchanged=(await getDoc(ref)).data(); assert.equal(unchanged.accountStatus,'active'); assert.equal(unchanged.platformRole,'user');
    await signOut(auth); await sendPasswordResetEmail(auth,email);
    const reset=await codeFor('PASSWORD_RESET');
    assert.equal(await verifyPasswordResetCode(auth,reset),email);
    await confirmPasswordReset(auth,reset,'ChangedSynthetic456!');
    await assert.rejects(verifyPasswordResetCode(auth,reset));
    await assert.rejects(signInWithEmailAndPassword(auth,email,password));
    const again=await signInWithEmailAndPassword(auth,email,'ChangedSynthetic456!'); assert.equal(again.user.uid,uid);
    assert.equal((await getDoc(ref)).data().accountStatus,'active');
    // firebase-tools currently checks EMAIL_EXISTS before honoring the linking UID in signUp.
    // Keep this assertion visible as TODO; Dart tests cover production SDK call ordering and failure safety.
    await t.test('Google password linking keeps its UID', {
      todo: 'Installed Auth emulator rejects linking a password to the same existing Google email; verify on Android.'
    }, async () => {
    // An explicit password link to a Google-authenticated UID keeps that identity and data.
    await signOut(auth);
    const googleEmail=`google-${Date.now()}@example.edu`;
    const google=await signInWithCredential(auth, GoogleAuthProvider.credential(JSON.stringify({sub:`synthetic-google-${Date.now()}`,email:googleEmail,email_verified:true})));
    const googleUid=google.user.uid;
    assert.equal(google.user.email,googleEmail);
    assert.notEqual(googleUid,uid);
    await reauthenticateWithCredential(google.user,GoogleAuthProvider.credential(JSON.stringify({sub:`${google.user.providerData[0].uid}`,email:googleEmail,email_verified:true})));
    await linkWithCredential(google.user,EmailAuthProvider.credential(googleEmail,password));
    assert.equal(auth.currentUser.uid,googleUid);
    await signOut(auth);
    assert.equal((await signInWithEmailAndPassword(auth,googleEmail,password)).user.uid,googleUid);
    });
  } finally { await signOut(auth); await deleteApp(app); await env.cleanup(); }
});
