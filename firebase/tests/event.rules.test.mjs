import {readFileSync} from 'node:fs';
import {before,after,beforeEach,test} from 'node:test';
import assert from 'node:assert/strict';
import {initializeTestEnvironment,assertSucceeds,assertFails} from '@firebase/rules-unit-testing';
import {doc,collection,collectionGroup,getDoc,getDocs,setDoc,updateDoc,deleteDoc,query,where,serverTimestamp,Timestamp,runTransaction,writeBatch,increment} from 'firebase/firestore';
let env;
before(async()=>{env=await initializeTestEnvironment({projectId:'orglink-dev',firestore:{rules:readFileSync(new URL('../firebase.rules',import.meta.url),'utf8')}});});
after(async()=>{await env?.cleanup();});
const db=(uid='student')=>env.authenticatedContext(uid,{email:`${uid}@example.test`}).firestore();
const eventRef=(database,id='demo',org='public')=>doc(database,`organizations/${org}/events/${id}`);
const registrationRef=(database,uid='student',id='demo',org='public')=>doc(database,`organizations/${org}/events/${id}/registrations/${uid}`);
const event=(uid='manager',changes={})=>({eventId:'demo',organizationId:'public',title:'Demo Event',description:'Synthetic event',posterURL:null,
  startAt:Timestamp.fromMillis(Date.now()+7200000),endAt:Timestamp.fromMillis(Date.now()+10800000),venue:'Demo Hall',capacity:2,
  registrationDeadline:Timestamp.fromMillis(Date.now()+3600000),registrationCount:0,eventStatus:'draft',approvalStatus:'pending',createdBy:uid,
  createdAt:serverTimestamp(),updatedAt:serverTimestamp(),visibility:'public',submittedAt:null,reviewedAt:null,reviewedBy:null,
  publishedAt:null,cancelledAt:null,completedAt:null,archivedAt:null,...changes});
async function seed(path,data){await env.withSecurityRulesDisabled(async context=>{await setDoc(doc(context.firestore(),path),data);});}
async function published(changes={}){await seed('organizations/public/events/demo',event('manager',{eventStatus:'published',approvalStatus:'approved',...changes}));}
async function transition(database,action){const data={updatedAt:serverTimestamp()};
  if(action==='submit')Object.assign(data,{approvalStatus:'pending',submittedAt:serverTimestamp()});
  if(action==='approve'||action==='reject')Object.assign(data,{approvalStatus:action==='approve'?'approved':'rejected',reviewedAt:serverTimestamp(),reviewedBy:database.app.options.appId??'manager'});
  if(action==='publish')Object.assign(data,{eventStatus:'published',publishedAt:serverTimestamp()});
  return updateDoc(eventRef(database),data);
}
async function register(database,uid,{withdraw=false,id='demo',org='public'}={}) {
  return runTransaction(database,async transaction=>{
    const target=eventRef(database,id,org),record=registrationRef(database,uid,id,org);
    const current=await transaction.get(target),existing=await transaction.get(record);const data=current.data();
    const profile=withdraw?null:await transaction.get(doc(database,`users/${uid}`));
    if(withdraw){transaction.update(record,{registrationStatus:'cancelled',updatedAt:serverTimestamp()});}
    else if(existing.exists()){transaction.update(record,{registrationStatus:'registered',updatedAt:serverTimestamp()});}
    else transaction.set(record,{uid,eventId:id,organizationId:org,registrationStatus:'registered',registeredAt:serverTimestamp(),updatedAt:serverTimestamp()});
    if(!withdraw)transaction.set(doc(database,`organizations/${org}/events/${id}/participantIdentities/${uid}`),{uid,fullName:profile.data().fullName,updatedAt:serverTimestamp()});
    transaction.update(target,{registrationCount:data.registrationCount+(withdraw?-1:1),updatedAt:serverTimestamp()});
  });
}
beforeEach(async()=>{
  await env.clearFirestore();
  for(const uid of ['student','other','third','manager','officer','ordinaryOfficer','suspended']) {
    await seed(`users/${uid}`,{uid,email:`${uid}@example.test`,fullName:`Demo ${uid}`,studentNumber:'DEMO-001',yearLevel:1,section:'A',platformRole:'user',accountStatus:uid==='suspended'?'suspended':'active'});
  }
  await seed('organizations/public',{organizationId:'public',name:'Demo Organization',visibility:'public',status:'active',managerUid:'manager',approvalSettings:{acceptsRequests:true}});
  await seed('organizations/other',{organizationId:'other',name:'Other',visibility:'public',status:'active',managerUid:'other',approvalSettings:{acceptsRequests:true}});
  for(const uid of ['officer','ordinaryOfficer'])await seed(`organizations/public/memberships/${uid}`,{uid,organizationId:'public',membershipStatus:'active',membershipRole:'officer',permissions:uid==='officer'?{manageEvents:true}:{}});
});
test('manager creates draft, submits, self-approves and publishes',async()=>{
  const database=db('manager');await assertSucceeds(setDoc(eventRef(database),event()));
  await assertSucceeds(updateDoc(eventRef(database),{submittedAt:serverTimestamp(),approvalStatus:'pending',updatedAt:serverTimestamp()}));
  await assertSucceeds(updateDoc(eventRef(database),{approvalStatus:'approved',reviewedAt:serverTimestamp(),reviewedBy:'manager',updatedAt:serverTimestamp()}));
  await assertSucceeds(transition(database,'publish'));
  assert.equal((await getDoc(eventRef(database))).data().eventStatus,'published');
});
test('assigned active event officer creates and edits only own drafts; manager reviews',async()=>{
  const database=db('officer');await assertSucceeds(setDoc(eventRef(database),event('officer')));
  await assertSucceeds(getDocs(query(collection(database,'organizations/public/events'),where('createdBy','==','officer'))));
  await assertFails(getDocs(collection(database,'organizations/public/events')));
  await assertSucceeds(updateDoc(eventRef(database),{title:'Revised',approvalStatus:'pending',submittedAt:null,updatedAt:serverTimestamp()}));
  await assertSucceeds(transition(database,'submit'));
  await assertFails(updateDoc(eventRef(database),{title:'Change while pending',updatedAt:serverTimestamp()}));
  await assertFails(updateDoc(eventRef(database),{approvalStatus:'approved',reviewedBy:'officer',reviewedAt:serverTimestamp(),updatedAt:serverTimestamp()}));
  await assertSucceeds(updateDoc(eventRef(db('manager')),{approvalStatus:'rejected',reviewedBy:'manager',reviewedAt:serverTimestamp(),updatedAt:serverTimestamp()}));
  await assertSucceeds(updateDoc(eventRef(database),{description:'Revision after rejection',approvalStatus:'pending',submittedAt:null,updatedAt:serverTimestamp()}));
  await assertSucceeds(transition(database,'submit'));
  await assertSucceeds(updateDoc(eventRef(db('manager')),{approvalStatus:'approved',reviewedBy:'manager',reviewedAt:serverTimestamp(),updatedAt:serverTimestamp()}));
  await assertFails(transition(database,'publish'));await assertSucceeds(transition(db('manager'),'publish'));
});
test('members, unassigned officers, wrong-org managers and suspended users cannot create or approve',async()=>{
  for(const uid of ['student','ordinaryOfficer','other','suspended'])await assertFails(setDoc(eventRef(db(uid)),event(uid)));
  await seed('users/student',{uid:'student',fullName:'Demo Student',studentNumber:'DEMO-001',yearLevel:1,section:'A',platformRole:'platformAdmin',accountStatus:'active'});
  await assertFails(setDoc(eventRef(db()),event('student')));
  await seed('organizations/public/events/demo',event('officer',{submittedAt:Timestamp.now()}));
  for(const uid of ['student','officer','other'])await assertFails(updateDoc(eventRef(db(uid)),{approvalStatus:'approved',reviewedBy:uid,reviewedAt:serverTimestamp(),updatedAt:serverTimestamp()}));
});
for(const [label,changes] of Object.entries({title:{title:''},date:{endAt:Timestamp.fromMillis(0)},deadline:{registrationDeadline:Timestamp.fromMillis(0)},capacity:{capacity:0},count:{registrationCount:1},
  identity:{createdBy:'student'},path:{organizationId:'other'},status:{eventStatus:'published'},approval:{approvalStatus:'approved'},review:{reviewedBy:'manager'},created:{createdAt:Timestamp.fromMillis(0)},extra:{attended:true}})) {
  test(`reject invalid or forged event creation: ${label}`,async()=>{await assertFails(setDoc(eventRef(db('manager')),event('manager',changes)));});
}
test('officer cannot edit another organizer or escalate permissions through event fields',async()=>{
  await seed('organizations/public/events/demo',event('manager'));
  await assertFails(updateDoc(eventRef(db('officer')),{title:'Other event',updatedAt:serverTimestamp()}));
  await assertFails(updateDoc(eventRef(db('manager')),{createdBy:'officer',updatedAt:serverTimestamp()}));
  await assertFails(updateDoc(eventRef(db('manager')),{registrationCount:5,updatedAt:serverTimestamp()}));
  await assertFails(deleteDoc(eventRef(db('manager'))));
});
test('unsubmitted draft cannot be approved; unapproved event cannot be published',async()=>{
  await setDoc(eventRef(db('manager')),event());
  await assertFails(updateDoc(eventRef(db('manager')),{approvalStatus:'approved',reviewedBy:'manager',reviewedAt:serverTimestamp(),updatedAt:serverTimestamp()}));
  await assertFails(transition(db('manager'),'publish'));
});
test('public discovery excludes drafts and member-only events unless authorized',async()=>{
  await published();await seed('organizations/public/events/private',event('manager',{eventId:'private',visibility:'private',eventStatus:'published',approvalStatus:'approved'}));
  await seed('organizations/public/events/draft',event('manager',{eventId:'draft'}));
  await assertSucceeds(getDocs(query(collection(db(),'organizations/public/events'),where('eventStatus','in',['published','completed']),where('approvalStatus','==','approved'),where('visibility','==','public'))));
  await assertFails(getDoc(eventRef(db(),'private')));await assertFails(getDoc(eventRef(db(),'draft')));
  await assertFails(getDocs(collection(db(),'organizations/public/events')));
  await assertSucceeds(getDocs(collection(db('manager'),'organizations/public/events')));
  await assertFails(getDoc(eventRef(env.unauthenticatedContext().firestore())));
});
test('only active members can see and register for members-only events',async()=>{
  await published({visibility:'private'});
  for(const status of ['pending','rejected','removed']) {
    await seed('organizations/public/memberships/student',{uid:'student',membershipStatus:status,membershipRole:'member',permissions:{}});
    await assertFails(getDoc(eventRef(db())));await assertFails(register(db(),'student'));
  }
  await seed('organizations/public/memberships/student',{uid:'student',membershipStatus:'active',membershipRole:'member',permissions:{}});
  await assertSucceeds(getDoc(eventRef(db())));await assertSucceeds(register(db(),'student'));
});
test('atomic registration, withdrawal and re-registration preserve original timestamps',async()=>{
  const database=db();await published();await assertSucceeds(register(database,'student'));
  const original=(await getDoc(registrationRef(database))).data().registeredAt;
  await assertFails(register(database,'student'));
  await assertSucceeds(register(database,'student',{withdraw:true}));
  assert.equal((await getDoc(eventRef(database))).data().registrationCount,0);
  assert.equal((await getDoc(registrationRef(database))).data().registrationStatus,'cancelled');
  await assertSucceeds(register(database,'student'));
  assert.ok((await getDoc(registrationRef(database))).data().registeredAt.isEqual(original));
  await assertFails(deleteDoc(registrationRef(database)));
});
test('concurrent registration attempts cannot exceed capacity',async()=>{
  await published({capacity:1});
  const results=await Promise.allSettled(['student','other','third'].map(uid=>register(db(uid),uid)));
  assert.equal(results.filter(result=>result.status==='fulfilled').length,1);
  assert.equal((await getDoc(eventRef(db('manager')))).data().registrationCount,1);
  const snapshot=await getDocs(collection(db('manager'),'organizations/public/events/demo/registrations'));assert.equal(snapshot.size,1);
});
test('registration records and counters cannot be forged separately, even by managers',async()=>{
  await published();
  const record={uid:'student',eventId:'demo',organizationId:'public',registrationStatus:'registered',registeredAt:serverTimestamp(),updatedAt:serverTimestamp()};
  await assertFails(setDoc(registrationRef(db()),record));
  for(const uid of ['student','manager'])await assertFails(updateDoc(eventRef(db(uid)),{registrationCount:1,updatedAt:serverTimestamp()}));
  const database=db(),batch=writeBatch(database);
  batch.set(registrationRef(database),record);batch.set(doc(database,'organizations/public/events/demo/participantIdentities/student'),{uid:'student',fullName:'Demo student',updatedAt:serverTimestamp()});batch.update(eventRef(database),{registrationCount:2,updatedAt:serverTimestamp()});await assertFails(batch.commit());
  await assertFails(register(db('other'),'student'));
});
test('deadlines, event starts, cancellation and suspended accounts block registrations',async()=>{
  for(const changes of [{registrationDeadline:Timestamp.fromMillis(0)},{startAt:Timestamp.fromMillis(0)},
    {eventStatus:'cancelled'},{eventStatus:'draft'},{approvalStatus:'rejected'}]) {
    await published(changes);await assertFails(register(db(),'student'));
  }
  await published();await assertFails(register(db('suspended'),'suspended'));
  await assertSucceeds(register(db(),'student'));
  await seed('organizations/public/events/demo',event('manager',{eventStatus:'published',approvalStatus:'approved',registrationCount:1,registrationDeadline:Timestamp.fromMillis(0)}));
  await assertFails(register(db(),'student',{withdraw:true}));
});
test('My Events is own-UID only; organizers can see participants without private profiles',async()=>{
  await published();await register(db(),'student');
  await assertSucceeds(getDocs(query(collectionGroup(db(),'registrations'),where('uid','==','student'))));
  await assertFails(getDocs(query(collectionGroup(db('other'),'registrations'),where('uid','==','student'))));
  await assertFails(getDocs(collection(db(),'organizations/public/events/demo/registrations')));
  await assertSucceeds(getDocs(collection(db('manager'),'organizations/public/events/demo/registrations')));
  await assertFails(getDocs(collection(db('officer'),'organizations/public/events/demo/registrations')));
  await seed('organizations/public/events/demo',event('officer',{eventStatus:'published',approvalStatus:'approved',registrationCount:1}));
  await assertSucceeds(getDocs(collection(db('officer'),'organizations/public/events/demo/registrations')));
  await assertFails(getDoc(doc(db('manager'),'users/student')));
  await assertFails(getDoc(registrationRef(db('other'))));
});
test('published content immutable; manager cancels and cannot reopen, complete early or archive drafts',async()=>{
  await published();await register(db(),'student');
  await assertFails(updateDoc(eventRef(db('manager')),{title:'Changed published content',updatedAt:serverTimestamp()}));
  await assertFails(updateDoc(eventRef(db('manager')),{eventStatus:'completed',completedAt:serverTimestamp(),updatedAt:serverTimestamp()}));
  await assertFails(updateDoc(eventRef(db('officer')),{eventStatus:'cancelled',cancelledAt:serverTimestamp(),updatedAt:serverTimestamp()}));
  await assertSucceeds(updateDoc(eventRef(db('manager')),{eventStatus:'cancelled',cancelledAt:serverTimestamp(),updatedAt:serverTimestamp()}));
  await assertSucceeds(getDoc(eventRef(db())));
  await assertFails(transition(db('manager'),'publish'));
  await assertSucceeds(register(db(),'student',{withdraw:true}));
  await assertSucceeds(updateDoc(eventRef(db('manager')),{archivedAt:serverTimestamp(),updatedAt:serverTimestamp()}));
  await assertFails(register(db('other'),'other'));
});
test('completed after end and archived metadata retain completed lifecycle value',async()=>{
  await published({endAt:Timestamp.fromMillis(0)});
  await assertSucceeds(updateDoc(eventRef(db('manager')),{eventStatus:'completed',completedAt:serverTimestamp(),updatedAt:serverTimestamp()}));
  await assertSucceeds(updateDoc(eventRef(db('manager')),{archivedAt:serverTimestamp(),updatedAt:serverTimestamp()}));
  assert.equal((await getDoc(eventRef(db('manager')))).data().eventStatus,'completed');
});

test('withdrawal can release a private reservation without disclosing event content',async()=>{
  await published({visibility:'private'});
  await seed('organizations/public/memberships/student',{uid:'student',membershipStatus:'active',membershipRole:'member',permissions:{}});
  await register(db(),'student');
  await seed('organizations/public/memberships/student',{uid:'student',membershipStatus:'removed',membershipRole:'member',permissions:{}});
  const database=db();await assertFails(getDoc(eventRef(database)));
  const batch=writeBatch(database);batch.update(registrationRef(database),{registrationStatus:'cancelled',updatedAt:serverTimestamp()});
  batch.update(eventRef(database),{registrationCount:increment(-1),updatedAt:serverTimestamp()});await assertSucceeds(batch.commit());
  assert.equal((await getDoc(eventRef(db('manager')))).data().registrationCount,0);
});

test('concurrent withdrawal batches release a reserved slot exactly once',async()=>{
  await published({capacity:1});await register(db(),'student');
  const database=db();
  const withdraw=()=>{const batch=writeBatch(database);
    batch.update(registrationRef(database),{registrationStatus:'cancelled',updatedAt:serverTimestamp()});
    batch.update(eventRef(database),{registrationCount:increment(-1),updatedAt:serverTimestamp()});return batch.commit();};
  const results=await Promise.allSettled([withdraw(),withdraw()]);
  assert.equal(results.filter(result=>result.status==='fulfilled').length,1);
  assert.equal((await getDoc(eventRef(database))).data().registrationCount,0);
});

const identityRef=(database,uid='student')=>doc(database,`organizations/public/events/demo/participantIdentities/${uid}`);
const identityData=(uid='student',name=`Demo ${uid}`)=>({uid,fullName:name,updatedAt:serverTimestamp()});
test('manager and assigned event officer can read names; students and unrelated managers cannot',async()=>{
  await published();await register(db(),'student');
  assert.equal((await assertSucceeds(getDoc(identityRef(db('manager'))))).data().fullName,'Demo student');
  await assertSucceeds(getDocs(collection(db('manager'),'organizations/public/events/demo/participantIdentities')));
  for(const uid of ['student','other','ordinaryOfficer','officer'])await assertFails(getDoc(identityRef(db(uid))));
  await assertFails(getDocs(collectionGroup(db('manager'),'participantIdentities')));
  await assertFails(getDoc(doc(db('manager'),'users/student')));
  await seed('organizations/public/events/demo',event('officer',{eventStatus:'published',approvalStatus:'approved',registrationCount:1}));
  await assertSucceeds(getDoc(identityRef(db('officer'))));
  await assertSucceeds(getDocs(collection(db('officer'),'organizations/public/events/demo/participantIdentities')));
});
test('identity requires own existing registration and exact private-profile name',async()=>{
  await published();await assertFails(setDoc(identityRef(db()),identityData()));
  await register(db(),'student');
  await assertFails(setDoc(identityRef(db()),identityData('student','Forged name')));
  await assertFails(setDoc(identityRef(db('other')),identityData()));
  await assertFails(setDoc(identityRef(db('manager')),identityData()));
  await assertFails(setDoc(identityRef(db()),{...identityData(),uid:'other'}));
  await assertFails(setDoc(identityRef(db()),{...identityData(),email:'private@example.test'}));
  await assertFails(setDoc(identityRef(db()),{...identityData(),updatedAt:Timestamp.fromMillis(0)}));
  await assertFails(deleteDoc(identityRef(db())));
  await assertFails(getDoc(identityRef(env.unauthenticatedContext().firestore())));
});
test('identity remains after withdrawal and can be refreshed from an updated own profile',async()=>{
  await published();await register(db(),'student');
  const registeredAt=(await getDoc(registrationRef(db()))).data().registeredAt;
  await register(db(),'student',{withdraw:true});
  assert.equal((await getDoc(identityRef(db('manager')))).data().fullName,'Demo student');
  await updateDoc(doc(db(),'users/student'),{fullName:'Updated Student Name',updatedAt:serverTimestamp()});
  await assertFails(setDoc(identityRef(db()),identityData()));
  await assertSucceeds(setDoc(identityRef(db()),identityData('student','Updated Student Name')));
  assert.equal((await getDoc(identityRef(db('manager')))).data().fullName,'Updated Student Name');
  assert.equal((await getDoc(eventRef(db('manager')))).data().registrationCount,0);
  assert.equal((await getDoc(registrationRef(db()))).data().registrationStatus,'cancelled');
  assert.ok((await getDoc(registrationRef(db()))).data().registeredAt.isEqual(registeredAt));
});
test('legacy registrations can withdraw without projection and owners can safely backfill it',async()=>{
  await published({registrationCount:1});
  await seed('organizations/public/events/demo/registrations/student',{uid:'student',eventId:'demo',organizationId:'public',registrationStatus:'registered',registeredAt:Timestamp.now(),updatedAt:Timestamp.now()});
  assert.equal((await getDoc(identityRef(db('manager')))).exists(),false);
  await register(db(),'student',{withdraw:true});
  await assertSucceeds(setDoc(identityRef(db()),identityData()));
  assert.equal((await getDoc(eventRef(db('manager')))).data().registrationCount,0);
});
test('registration without matching identity is denied and counter/record roll back atomically',async()=>{
  await published();const database=db(),batch=writeBatch(database);
  batch.set(registrationRef(database),{uid:'student',eventId:'demo',organizationId:'public',registrationStatus:'registered',registeredAt:serverTimestamp(),updatedAt:serverTimestamp()});
  batch.update(eventRef(database),{registrationCount:1,updatedAt:serverTimestamp()});
  await assertFails(batch.commit());
  assert.equal((await getDoc(registrationRef(database))).exists(),false);
  assert.equal((await getDoc(eventRef(database))).data().registrationCount,0);
});
