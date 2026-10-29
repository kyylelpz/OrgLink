import test from 'node:test';
import assert from 'node:assert/strict';
import {buildDataset,summary} from './dataset.mjs';
import {completeProfile} from '../../../workers/attendance/src/admin.js';
import {parseArgs,main} from '../seed-demo.mjs';
import {mkdtemp,readFile,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {canonical,digest} from './firebase.mjs';
const now=new Date('2026-10-29T06:00:00Z'),p=buildDataset({anchor:now.toISOString()});
const docs=new Map(p.docs.map(d=>[d.path,d.data]));
test('deterministic dataset matches requested counts and unique IDs',()=>{
  assert.deepEqual(buildDataset({anchor:now.toISOString()}),p);
  assert.deepEqual(summary(p),{project:'orglink-dev',seed:'campus-demo',anchor:now.toISOString(),accounts:20,organizations:5,memberships:36,officers:8,events:20,eventDistribution:{past:6,ongoing:2,upcoming:8,other:4},registrations:42,attendance:20,images:45,posterDimensions:[1380,736]});
  assert.equal(new Set(p.docs.map(d=>d.path)).size,p.docs.length);
  assert.equal(new Set(p.users.map(u=>u.studentNumber)).size,20);
  for(const u of p.users){assert.match(u.studentNumber,/^\d{10}$/);assert.ok(completeProfile(u));assert.equal(u.platformRole,'user');assert.equal(docs.get(`studentIds/${u.studentNumber}`).uid,u.uid);assert.ok(u.email.endsWith('@orglink.example'));}
  assert.equal(new Set(p.users.map(u=>u.accountStatus)).size,5);
});
test('managers/officers, memberships and private-event eligibility are consistent',()=>{
  for(const org of p.organizations){const manager=p.users.find(u=>u.uid===org.managerUid);assert.equal(manager.accountStatus,'active');assert.equal(docs.get(`organizations/${org.organizationId}/memberships/${manager.uid}`).membershipRole,'manager');}
  for(const {path,data:m} of p.docs.filter(d=>d.path.includes('/memberships/'))){assert.ok(docs.has(`users/${m.uid}`));assert.ok(docs.has(`organizations/${m.organizationId}`));assert.ok(path.endsWith('/'+m.uid));if(m.membershipRole==='officer'){assert.equal(m.membershipStatus,'active');assert.equal(m.permissions.manageAttendance,true);assert.equal(typeof m.permissions.manageEvents,'boolean');}}
});
test('relative dates and historical lifecycle transitions are internally valid',()=>{
  for(const {data:e,category} of p.events){assert.ok(e.createdAt<e.startAt);assert.ok(e.startAt<e.endAt);assert.ok(e.registrationDeadline<=e.startAt);assert.ok(e.capacity>=e.registrationCount);assert.equal(e.archivedAt,null);assert.ok(e.visibility==='private'||e.visibility==='public');
    const creator=docs.get(`organizations/${e.organizationId}/memberships/${e.createdBy}`);assert.equal(creator.membershipStatus,'active');assert.ok(creator.membershipRole==='manager'||creator.membershipRole==='officer'&&creator.permissions.manageEvents===true);
    if(category==='past'){assert.equal(e.eventStatus,'completed');assert.ok(e.endAt<now);assert.ok(e.completedAt>=e.endAt);}
    if(category==='ongoing'){assert.equal(e.eventStatus,'published');assert.ok(e.startAt<=now&&e.endAt>now);}
    if(category==='upcoming'){assert.equal(e.eventStatus,'published');assert.ok(e.startAt>now);assert.ok(e.registrationDeadline>now);}
    if(['published','completed'].includes(e.eventStatus)){assert.equal(e.approvalStatus,'approved');assert.ok(e.submittedAt<=e.reviewedAt&&e.reviewedAt<=e.publishedAt&&e.publishedAt<e.startAt);}
  }
  assert.deepEqual(p.events.slice(16).map(e=>[e.data.eventStatus,e.data.approvalStatus,!!e.data.submittedAt]),[['draft','pending',false],['draft','pending',true],['draft','rejected',true],['cancelled','approved',true]]);
  const later=buildDataset({anchor:new Date(+now+86400000).toISOString()});assert.equal(+later.events[0].data.startAt-+p.events[0].data.startAt,86400000);
});
test('registrations, withdrawals, participant identities and attendance satisfy relationships',()=>{
  for(const {path,data:e} of p.events){const registrations=p.docs.filter(d=>d.path.startsWith(path+'/registrations/')).map(d=>d.data);assert.equal(e.registrationCount,registrations.filter(r=>r.registrationStatus==='registered').length);
    for(const r of registrations){assert.equal(r.eventId,e.eventId);assert.equal(r.organizationId,e.organizationId);const user=docs.get('users/'+r.uid);assert.equal(user.accountStatus,'active');assert.ok(r.registeredAt<e.registrationDeadline);assert.ok(r.registeredAt>=e.publishedAt);assert.equal(docs.get(path+'/participantIdentities/'+r.uid).fullName,user.fullName);if(e.visibility==='private')assert.equal(docs.get(`organizations/${e.organizationId}/memberships/${r.uid}`).membershipStatus,'active');}
    for(const {data:a} of p.docs.filter(d=>d.path.startsWith(path+'/attendance/'))){assert.equal(docs.get(path+'/registrations/'+a.uid).registrationStatus,'registered');assert.ok(a.verifiedAt>=e.startAt&&a.verifiedAt<e.endAt&&a.verifiedAt<=now);assert.equal(a.verificationMethod,'manual');assert.equal(a.verifiedBy,docs.get('organizations/'+e.organizationId).managerUid);assert.notEqual(a.uid,a.verifiedBy);assert.ok(['completed','published'].includes(e.eventStatus));assert.equal(e.approvalStatus,'approved');}
  }
  assert.ok(p.docs.every(d=>!d.path.includes('qr')&&!d.path.includes('activityLogs')&&!d.path.includes('Corrections')));
});
test('image plans match existing responsive detail slot and square avatars/logos',()=>{
  for(const i of p.images){assert.ok(docs.has(i.path));if(i.folder==='orglink/events')assert.equal(i.width/i.height,(393-48)/184);else assert.equal(i.width,i.height);}
  assert.equal(buildDataset({viewport:1200}).images.at(-1).width,3648);
});
test('CLI rejects unsafe project, modes, duplicate and unknown flags',()=>{
  const base=['apply','--project','orglink-dev'];assert.throws(()=>parseArgs(base));assert.throws(()=>parseArgs(['cleanup','--project','orglink-dev','--confirm-project','orglink-dev']));
  for(const args of [['dry-run','--project','production'],['--apply'],['dry-run','--project','orglink-dev','--force','true'],['dry-run','--project','orglink-dev','--project','orglink-dev']])assert.throws(()=>parseArgs(args));
  assert.equal(parseArgs([...base,'--confirm-project','orglink-dev']).mode,'apply');assert.equal(parseArgs(['dry-run','--project','orglink-dev']).seed,'campus-demo');
});
test('Firestore canonical hashes preserve timestamps and key order independence',()=>{assert.equal(digest({b:1,a:now}),digest({a:{toDate:()=>now},b:1}));assert.deepEqual(canonical([now]),[now.toISOString()]);});
test('dry-run CLI does not fetch, initialize services or create manifest/lock files',async()=>{
  const dir=await mkdtemp(join(tmpdir(),'orglink-dry-run-')),path=join(dir,'manifest.json'),log=console.log,fetchImpl=globalThis.fetch;let output;
  try{globalThis.fetch=()=>{throw Error('Dry run must stay offline');};console.log=value=>{output=value;};await main(['dry-run','--project','orglink-dev','--manifest',path,'--now',now.toISOString()]);const result=JSON.parse(output);assert.equal(result.externalWrites,false);assert.equal(result.summary.accounts,20);assert.equal(result.images.length,45);await assert.rejects(readFile(path),{code:'ENOENT'});await assert.rejects(readFile(path+'.lock'),{code:'ENOENT'});}finally{console.log=log;globalThis.fetch=fetchImpl;await rm(dir,{recursive:true,force:true});}
});
