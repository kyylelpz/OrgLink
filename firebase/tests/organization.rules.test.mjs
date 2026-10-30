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
test('no client can create organizations, assign managers, grant roles or delete another membership',async()=>{
  for(const uid of ['student','manager']) {
    await assertFails(setDoc(doc(db(uid),'organizations/new'),organization('new')));
    await assertFails(updateDoc(doc(db(uid),'organizations/public'),{managerUid:uid}));
    await assertFails(updateDoc(doc(db(uid),'organizations/public'),{description:'Edited'}));
    await assertFails(deleteDoc(ref(db(uid),'officer')));
  }
});

test('owner can cancel a pending request and submit a fresh request',async()=>{
  await assertSucceeds(setDoc(ref(db()),request()));
  await assertSucceeds(deleteDoc(ref(db())));
  assert.equal((await getDoc(ref(db()))).exists(),false);
  await assertSucceeds(setDoc(ref(db()),request()));
  assert.equal((await getDoc(ref(db()))).data().membershipStatus,'pending');
});
test('other students, managers, officers and anonymous users cannot cancel another request',async()=>{
  await setDoc(ref(db()),request());
  for(const uid of ['other','manager','officer'])await assertFails(deleteDoc(ref(db(uid))));
  await assertFails(deleteDoc(ref(env.unauthenticatedContext().firestore())));
  assert.equal((await getDoc(ref(db()))).data().membershipStatus,'pending');
});
for(const status of ['active','rejected','removed']) {
  test(`owner cannot delete a ${status} membership`,async()=>{
    await adminWrite('organizations/public/memberships/student',{...request(),membershipStatus:status});
    await assertFails(deleteDoc(ref(db())));
  });
}
test('ineligible and unverified owners cannot cancel pending requests',async()=>{
  await adminWrite('organizations/public/memberships/suspended',request('suspended'));
  await assertFails(deleteDoc(ref(db('suspended'),'suspended')));
  await adminWrite('organizations/public/memberships/student',request());
  const unverified=env.authenticatedContext('student',{email:'student@example.test',email_verified:false,firebase:{sign_in_provider:'password'}}).firestore();
  await assertFails(deleteDoc(ref(unverified)));
});
test('cancellation cannot delete privileged or reviewed pending records',async()=>{
  for(const patch of [{membershipRole:'officer'},{permissions:{manageEvents:true}},{joinedAt:Timestamp.now()},{reviewedAt:Timestamp.now()},{reviewedBy:'manager'},{uid:'other'},{organizationId:'other'}]) {
    await adminWrite('organizations/public/memberships/student',{...request(),...patch});
    await assertFails(deleteDoc(ref(db())));
  }
});
test('owner may cancel even after the organization stops accepting requests',async()=>{
  await setDoc(ref(db()),request());
  await adminWrite('organizations/public',organization('public',{approvalSettings:{acceptsRequests:false}}));
  await assertSucceeds(deleteDoc(ref(db())));
});
test('concurrent manager review and cancellation never delete an approved membership',async()=>{
  await setDoc(ref(db()),request());
  const cancel=()=>runTransaction(db(),async t=>{
    const snapshot=await t.get(ref(db()));
    if(!snapshot.exists())return;
    if(snapshot.data().membershipStatus!=='pending')throw Error('No longer pending');
    t.delete(ref(db()));
  });
  const [cancelled,reviewed]=await Promise.allSettled([cancel(),updateDoc(ref(db('manager')),decision('active'))]);
  const final=await getDoc(ref(db()));
  if(final.exists()) {
    assert.equal(final.data().membershipStatus,'active');
    assert.equal(reviewed.status,'fulfilled');
    assert.equal(cancelled.status,'rejected');
  } else {
    assert.equal(cancelled.status,'fulfilled');
    assert.equal(reviewed.status,'rejected');
  }
});
test('published event summaries remain readable; malformed event and registration writes are denied',async()=>{
  await adminWrite('organizations/public/events/live',{title:'Demo event',visibility:'public',eventStatus:'published',approvalStatus:'approved',startAt:Timestamp.now()});
  await adminWrite('organizations/public/events/draft',{title:'Draft',eventStatus:'draft',approvalStatus:'pending'});
  await assertSucceeds(getDocs(query(collection(db(),'organizations/public/events'),where('eventStatus','==','published'),where('approvalStatus','==','approved'),where('visibility','==','public'))));
  await assertFails(getDoc(doc(db(),'organizations/public/events/draft')));
  await assertFails(setDoc(doc(db('manager'),'organizations/public/events/new'),{title:'Event'}));
  await assertFails(setDoc(doc(db(),'organizations/public/events/live/registrations/student'),{uid:'student'}));
});

test('role, permission and termination writes require the trusted membership backend',async()=>{
  await adminWrite('organizations/public/memberships/student',{...request(),membershipStatus:'active'});
  for(const uid of ['student','manager','officer'])for(const changes of [
    {membershipRole:'officer',positionTitle:'President'},
    {permissions:{manageEvents:true,manageAttendance:true,viewRoster:true}},
    {membershipStatus:'removed',endedBy:uid,endedAt:serverTimestamp()},
  ])await assertFails(updateDoc(ref(db(uid)),changes));
});
const reapply=()=>({membershipStatus:'pending',membershipRole:'member',positionTitle:null,permissions:{},applicantName:'Demo student',requestedAt:serverTimestamp(),joinedAt:null,updatedAt:serverTimestamp(),reviewedAt:null,reviewedBy:null});
test('ended membership reuses its UID document for a permission-free request and preserves end metadata',async()=>{
  await adminWrite('organizations/public/memberships/student',{...request(),membershipStatus:'removed',membershipRole:'officer',permissions:{manageEvents:true},positionTitle:'President',endedBy:'manager',endReason:'Completed service',endedAt:Timestamp.fromMillis(1000)});
  await assertSucceeds(updateDoc(ref(db()),reapply()));
  const value=(await getDoc(ref(db()))).data();assert.equal(value.membershipRole,'member');assert.deepEqual(value.permissions,{});assert.equal(value.endedBy,'manager');assert.equal(value.endReason,'Completed service');
  await assertSucceeds(updateDoc(ref(db('manager')),decision('active')));
  assert.equal((await getDoc(ref(db()))).data().membershipStatus,'active');
});
test('reapplication cannot forge role, history, identity or skip pending approval',async()=>{
  for(const changes of [{membershipStatus:'active'},{membershipRole:'officer'},{permissions:{viewRoster:true}},{uid:'other'},{endedBy:'student'},{endReason:'forged'},{reviewedBy:'manager'}]){
    await adminWrite('organizations/public/memberships/student',{...request(),membershipStatus:'removed',endedBy:'manager',endReason:'original'});
    await assertFails(updateDoc(ref(db()),{...reapply(),...changes}));
  }
  for(const status of ['active','pending','rejected']){
    await adminWrite('organizations/public/memberships/student',{...request(),membershipStatus:status});
    await assertFails(updateDoc(ref(db()),reapply()));
  }
  await adminWrite('organizations/public/memberships/student',{...request(),membershipStatus:'removed'});
  await assertFails(updateDoc(ref(db('other')),reapply()));
});
test('former roster is manager-only; active roster permission does not expose former members',async()=>{
  await adminWrite('organizations/public/memberships/student',{...request(),membershipStatus:'removed'});
  await adminWrite('organizations/public/memberships/officer',{...request('officer'),membershipStatus:'active',permissions:{viewRoster:true}});
  const former=database=>query(collection(database,'organizations/public/memberships'),where('membershipStatus','==','removed'));
  assert.equal((await assertSucceeds(getDocs(former(db('manager'))))).size,1);
  await assertFails(getDocs(former(db('officer'))));
  await assertSucceeds(getDoc(ref(db())));
});
