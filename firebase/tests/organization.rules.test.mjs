import {readFileSync} from 'node:fs';
import {before,after,beforeEach,test} from 'node:test';
import assert from 'node:assert/strict';
import {initializeTestEnvironment,assertSucceeds,assertFails} from '@firebase/rules-unit-testing';
import {doc,collection,collectionGroup,getDoc,getDocs,setDoc,updateDoc,deleteDoc,query,where,
  serverTimestamp,Timestamp,runTransaction} from 'firebase/firestore';
let env;
before(async()=>{env=await initializeTestEnvironment({projectId:'orglink-dev',firestore:{rules:readFileSync(new URL('../firebase.rules',import.meta.url),'utf8')}});});
after(async()=>{await env?.cleanup();});
const db=(uid='student')=>env.authenticatedContext(uid,{email:`${uid}@example.test`}).firestore();
const profile=(uid,status='active')=>({uid,email:`${uid}@example.test`,fullName:`Demo ${uid}`,
  studentNumber:'DEMO-001',yearLevel:1,section:'A',photoURL:null,platformRole:'user',accountStatus:status});
const organization=(id='public',extra={})=>({organizationId:id,name:`Demo ${id}`,description:'Synthetic organization',
  visibility:'public',status:'active',managerUid:'manager',approvalSettings:{acceptsRequests:true},...extra});
const request=(uid='student',org='public')=>({uid,organizationId:org,membershipRole:'member',membershipStatus:'pending',
  applicantName:`Demo ${uid}`,positionTitle:null,permissions:{},requestedAt:serverTimestamp(),joinedAt:null,
  updatedAt:serverTimestamp(),reviewedAt:null,reviewedBy:null});
const ref=(database,uid='student',org='public')=>doc(database,`organizations/${org}/memberships/${uid}`);
const decision=(status='active')=>({membershipStatus:status,joinedAt:status==='active'?serverTimestamp():null,
  reviewedAt:serverTimestamp(),reviewedBy:'manager',updatedAt:serverTimestamp()});
async function adminWrite(path,data){await env.withSecurityRulesDisabled(async context=>{await setDoc(doc(context.firestore(),path),data);});}
beforeEach(async()=>{
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async context=>{
    const database=context.firestore();
    for(const uid of ['student','manager','other','officer','suspended']) await setDoc(doc(database,`users/${uid}`),profile(uid,uid==='suspended'?'suspended':'active'));
    for(const org of [organization(),organization('private',{visibility:'private'}),organization('inactive',{status:'inactive'}),
      organization('closed',{approvalSettings:{acceptsRequests:false}}),organization('other',{managerUid:'other'})]) {
      await setDoc(doc(database,`organizations/${org.organizationId}`),org);
    }
    await setDoc(ref(database,'officer'),{...request('officer'),membershipStatus:'active',membershipRole:'officer',permissions:{manageMemberships:true}});
  });
});
test('eligible students can query only public active organizations',async()=>{
  const database=db();
  const snapshot=await assertSucceeds(getDocs(query(collection(database,'organizations'),where('visibility','==','public'),where('status','==','active'))));
  assert.equal(snapshot.size,3);
  await assertFails(getDocs(collection(database,'organizations')));
  await assertFails(getDoc(doc(database,'organizations/private')));
  await assertFails(getDoc(doc(database,'organizations/inactive')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),'organizations/public')));
});
test('assigned managers can query their organizations including private and inactive',async()=>{
  const snapshot=await assertSucceeds(getDocs(query(collection(db('manager'),'organizations'),where('managerUid','==','manager'))));
  assert.equal(snapshot.size,4);
});
test('request-to-approval flow uses UID path, member defaults and real transactions',async()=>{
  await assertSucceeds(setDoc(ref(db()),request()));
  await assertSucceeds(getDoc(ref(db())));
  await assertSucceeds(getDocs(query(collection(db('manager'),'organizations/public/memberships'),where('membershipStatus','==','pending'))));
  const managerDatabase=db('manager');
  await assertSucceeds(runTransaction(managerDatabase,async transaction=>{
    const target=ref(managerDatabase); const existing=await transaction.get(target);
    assert.equal(existing.data().membershipStatus,'pending'); transaction.update(target,decision());
  }));
  const mine=await getDoc(ref(db())); assert.equal(mine.data().membershipStatus,'active');
  assert.equal(mine.data().membershipRole,'member'); assert.ok(mine.data().joinedAt instanceof Timestamp);
  assert.ok(mine.data().requestedAt instanceof Timestamp); assert.equal(mine.data().reviewedBy,'manager');
  await assertSucceeds(getDocs(query(collectionGroup(db(),'memberships'),where('uid','==','student'))));
});
test('rejected and removed records cannot be replaced or reapplied',async()=>{
  await setDoc(ref(db()),request()); await updateDoc(ref(db('manager')),decision('rejected'));
  await assertFails(setDoc(ref(db()),request())); await assertFails(deleteDoc(ref(db())));
  await adminWrite('organizations/closed/memberships/student',{...request(),organizationId:'closed',membershipStatus:'removed'});
  await assertFails(setDoc(ref(db(),'student','closed'),request('student','closed')));
});
test('pending and active requests cannot be duplicated or reset',async()=>{
  await setDoc(ref(db()),request());
  await assertFails(setDoc(ref(db()),request()));
  await updateDoc(ref(db('manager')),decision());
  await assertFails(setDoc(ref(db()),request()));
  await assertFails(updateDoc(ref(db('manager')),decision('rejected')));
});
for(const [label,changes] of Object.entries({role:{membershipRole:'manager'},officer:{membershipRole:'officer'},
  promotion:{membershipStatus:'active'},permissions:{permissions:{viewRoster:true}},position:{positionTitle:'President'},
  identity:{uid:'other'},organization:{organizationId:'other'},name:{applicantName:'Forged Name'},
  joined:{joinedAt:serverTimestamp()},created:{requestedAt:Timestamp.fromMillis(0)},extra:{email:'private@example.test'}})) {
  test(`reject forged membership creation: ${label}`,async()=>{
    await assertFails(setDoc(ref(db()),{...request(),...changes}));
  });
}
test('missing fields, another UID and ineligible accounts cannot submit',async()=>{
  const missing=request();delete missing.permissions;
  await assertFails(setDoc(ref(db()),missing));
  await assertFails(setDoc(ref(db(),'other'),request('other')));
  await assertFails(setDoc(ref(db('suspended'),'suspended'),request('suspended')));
  await adminWrite('users/student',{...profile('student'),studentNumber:''});
  await assertFails(setDoc(ref(db()),request()));
});
for(const id of ['private','inactive','closed']) {
  test(`cannot request ${id} organizations`,async()=>{await assertFails(setDoc(ref(db(),'student',id),request('student',id)));});
}
test('own membership collection-group access does not expose other students',async()=>{
  await setDoc(ref(db()),request()); await setDoc(ref(db(),'student','other'),request('student','other'));
  const mine=await assertSucceeds(getDocs(query(collectionGroup(db(),'memberships'),where('uid','==','student'))));
  assert.equal(mine.size,2);
  await assertFails(getDocs(collectionGroup(db(),'memberships')));
  await assertFails(getDocs(query(collectionGroup(db(),'memberships'),where('uid','==','officer'))));
  await assertFails(getDoc(ref(db(),'officer')));
});
test('only assigned manager can review; officer permissions and platform role are insufficient',async()=>{
  await setDoc(ref(db()),request());
  for(const uid of ['student','other','officer']) await assertFails(updateDoc(ref(db(uid)),{...decision(),reviewedBy:uid}));
  await adminWrite('users/officer',{...profile('officer'),platformRole:'platformAdmin'});
  await assertFails(updateDoc(ref(db('officer')),{...decision(),reviewedBy:'officer'}));
  await assertFails(getDocs(query(collection(db('officer'),'organizations/public/memberships'),where('membershipStatus','==','pending'))));
  await assertFails(getDoc(doc(db('manager'),'users/student')));
});
test('manager cannot review own pending membership or alter protected fields',async()=>{
  await adminWrite('organizations/public/memberships/manager',request('manager'));
  await assertFails(updateDoc(ref(db('manager'),'manager'),decision()));
  await setDoc(ref(db()),request());
  for(const changes of [{membershipRole:'officer'},{permissions:{viewRoster:true}},{positionTitle:'President'},
    {uid:'other'},{organizationId:'other'},{applicantName:'Edited'},{requestedAt:serverTimestamp()},
    {reviewedBy:'other'},{reviewedAt:Timestamp.fromMillis(0)},{joinedAt:null},{membershipStatus:'removed'}]) {
    await assertFails(updateDoc(ref(db('manager')),{...decision(),...changes}));
  }
});
test('suspended managers cannot review and decisions cannot race into a second outcome',async()=>{
  await setDoc(ref(db()),request());
  await adminWrite('users/manager',profile('manager','suspended'));
  await assertFails(updateDoc(ref(db('manager')),decision()));
  await adminWrite('users/manager',profile('manager'));
  const results=await Promise.allSettled([updateDoc(ref(db('manager')),decision()),updateDoc(ref(db('manager')),decision('rejected'))]);
  assert.equal(results.filter(result=>result.status==='fulfilled').length,1);
});
test('roster readers need an explicit permission and can query only active records',async()=>{
  await setDoc(ref(db()),request());
  await assertFails(getDocs(query(collection(db('officer'),'organizations/public/memberships'),where('membershipStatus','==','active'))));
  await adminWrite('organizations/public/memberships/officer',{...request('officer'),membershipStatus:'active',membershipRole:'officer',permissions:{viewRoster:true}});
  await assertSucceeds(getDocs(query(collection(db('officer'),'organizations/public/memberships'),where('membershipStatus','==','active'))));
  await assertFails(getDocs(query(collection(db('officer'),'organizations/public/memberships'),where('membershipStatus','==','pending'))));
  await assertFails(getDoc(ref(db('officer'))));
});
test('active members can open private details but outsiders cannot',async()=>{
  await adminWrite('organizations/private/memberships/student',{...request(),organizationId:'private',membershipStatus:'active'});
  await assertSucceeds(getDoc(doc(db(),'organizations/private')));
  await assertFails(getDoc(doc(db('officer'),'organizations/private')));
});
test('no client can create organizations, assign managers, grant roles or delete memberships',async()=>{
  for(const uid of ['student','manager']) {
    await assertFails(setDoc(doc(db(uid),'organizations/new'),organization('new')));
    await assertFails(updateDoc(doc(db(uid),'organizations/public'),{managerUid:uid}));
    await assertFails(updateDoc(doc(db(uid),'organizations/public'),{description:'Edited'}));
    await assertFails(deleteDoc(ref(db(uid),'officer')));
  }
});
test('only approved published event summaries are readable and event writes remain denied',async()=>{
  await adminWrite('organizations/public/events/live',{title:'Demo event',eventStatus:'published',approvalStatus:'approved',startAt:Timestamp.now()});
  await adminWrite('organizations/public/events/draft',{title:'Draft',eventStatus:'draft',approvalStatus:'pending'});
  await assertSucceeds(getDocs(query(collection(db(),'organizations/public/events'),where('eventStatus','==','published'),where('approvalStatus','==','approved'))));
  await assertFails(getDoc(doc(db(),'organizations/public/events/draft')));
  await assertFails(setDoc(doc(db('manager'),'organizations/public/events/new'),{title:'Event'}));
  await assertFails(setDoc(doc(db(),'organizations/public/events/live/registrations/student'),{uid:'student'}));
});
