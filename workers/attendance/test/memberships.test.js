import {test} from 'node:test';
import assert from 'node:assert/strict';
import {MemoryDb} from './support/memory_db.js';
import {membershipBackend} from '../src/memberships.js';
import {attendanceBackend} from '../src/attendance.js';
import {createHandler} from '../src/index.js';
const memberPath='organizations/org/memberships/student';
const profile=uid=>({uid,email:`${uid}@example.test`,fullName:'Demo Student',studentNumber:'2026000001',yearLevel:1,section:'A',accountStatus:'active',platformRole:'user'});
function fixture(){
  const db=new MemoryDb();for(const uid of ['manager','student','officer','admin'])db.seed(`users/${uid}`,{...profile(uid),platformRole:uid==='admin'?'platformAdmin':'user'});
  db.seed('organizations/org',{organizationId:'org',status:'active',managerUid:'manager'});
  db.seed(memberPath,{uid:'student',organizationId:'org',membershipStatus:'active',membershipRole:'member',positionTitle:null,permissions:{},applicantName:'Demo Student',joinedAt:{milliseconds:100}});
  const api=membershipBackend(db,()=>1700000000000);
  const request=(extra={})=>({organizationId:'org',participantUid:'student',operation:'role',role:'officer',positionTitle:'President',version:db.v(memberPath),requestId:'request_membership_0001',...extra});
  const as=(data,uid='manager')=>({auth:{uid},data});
  return {db,api,request,as};
}
test('only eligible assigned managers can preview or mutate, including no platform-admin bypass',async()=>{
  const {db,api,request,as}=fixture();
  for(const uid of ['student','officer','admin','missing']){
    await assert.rejects(api.preview(as({organizationId:'org',participantUid:'student'},uid)),e=>e.code==='permission-denied');
    await assert.rejects(api.mutate(as(request(),uid)),e=>e.code==='permission-denied');
  }
  db.seed('users/manager',{...profile('manager'),accountStatus:'disabled'});
  await assert.rejects(api.mutate(as(request())),e=>e.code==='permission-denied');
});
test('role promotion, position reassignment, permission changes and demotion use existing fields',async()=>{
  const {db,api,request,as}=fixture();
  const preview=await api.preview(as({organizationId:'org',participantUid:'student'}));assert.equal(preview.version,db.v(memberPath));assert.equal(preview.membership.joinedAt,100);
  await api.mutate(as(request()));assert.equal(db.get(memberPath).membershipRole,'officer');assert.equal(db.get(memberPath).positionTitle,'President');assert.deepEqual(db.get(memberPath).permissions,{manageEvents:false,manageAttendance:false,viewRoster:false});
  await api.mutate(as({organizationId:'org',participantUid:'student',operation:'permissions',permissions:{manageEvents:true,manageAttendance:true,viewRoster:true},version:db.v(memberPath),requestId:'permission_request_0002'}));
  await api.mutate(as(request({positionTitle:'Treasurer',requestId:'position_request_0003'})));assert.equal(db.get(memberPath).permissions.manageAttendance,true);
  await api.mutate(as(request({role:'member',positionTitle:null,requestId:'demotion_request_0004'})));assert.deepEqual(db.get(memberPath).permissions,{});assert.equal(db.get(memberPath).positionTitle,null);
  await assert.rejects(attendanceBackend(db).correct({auth:{uid:'student'},data:{organizationId:'org',eventId:'event',operation:'preview',participantUid:'officer'}}),e=>e.code==='permission-denied');
  assert.equal(db.get('users/student').platformRole,'user');
  const audits=[...db.records].filter(([path])=>path.includes('/membershipAudits/'));assert.equal(audits.length,4);
  assert.equal(audits[0][1].value.actorUid,'manager');assert.equal(audits[0][1].value.before.membershipRole,'member');assert.equal(audits[0][1].value.after.membershipRole,'officer');
});
test('ending membership preserves history, registration and attendance and clears all capabilities',async()=>{
  const {db,api,as}=fixture();db.seed(memberPath,{...db.get(memberPath),membershipRole:'officer',positionTitle:'Secretary',permissions:{manageEvents:true,manageAttendance:true,viewRoster:true}});
  const registration='organizations/org/events/event/registrations/student',attendance='organizations/org/events/event/attendance/student';db.seed(registration,{uid:'student',registrationStatus:'registered'});db.seed(attendance,{attendanceStatus:'present'});
  await api.mutate(as({organizationId:'org',participantUid:'student',operation:'end',reason:'Graduating member',version:db.v(memberPath),requestId:'end_request_000001'}));
  const m=db.get(memberPath);assert.equal(m.membershipStatus,'removed');assert.equal(m.membershipRole,'officer');assert.equal(m.positionTitle,'Secretary');assert.equal(m.endedBy,'manager');assert.equal(m.endReason,'Graduating member');assert.deepEqual(m.joinedAt,{milliseconds:100});assert.deepEqual(m.permissions,{});
  assert.equal(db.get(registration).registrationStatus,'registered');assert.equal(db.get(attendance).attendanceStatus,'present');
  await assert.rejects(attendanceBackend(db).correct({auth:{uid:'student'},data:{organizationId:'org',eventId:'event',operation:'preview',participantUid:'officer'}}),e=>e.code==='permission-denied');
});
test('self, authoritative manager and manager-labelled memberships are always protected',async()=>{
  const {db,api,request,as}=fixture();
  for(const uid of ['manager','student']){
    if(uid==='student')db.seed(memberPath,{...db.get(memberPath),membershipRole:'manager'});
    else db.seed('organizations/org/memberships/manager',{...db.get(memberPath),uid:'manager'});
    for(const operation of ['role','end'])await assert.rejects(api.mutate(as(operation==='role'?request({participantUid:uid}):{organizationId:'org',participantUid:uid,operation,version:db.v(`organizations/org/memberships/${uid}`),requestId:'protect_request_001'})),e=>e.code==='permission-denied');
  }
  assert.equal(db.get('organizations/org').managerUid,'manager');
});
test('stale versions, concurrent writes, foreign organizations and manager transfer fail safely',async()=>{
  const {db,api,request,as}=fixture(),command=request();
  const results=await Promise.allSettled([api.mutate(as(command)),api.mutate(as({...command,positionTitle:'Secretary',requestId:'competing_request_02'}))]);assert.equal(results.filter(r=>r.status==='fulfilled').length,1);assert.equal(results.find(r=>r.status==='rejected').reason.code,'conflict');
  await assert.rejects(api.mutate(as(request({organizationId:'other'}))),e=>e.code==='permission-denied');
  db.seed('organizations/org',{...db.get('organizations/org'),managerUid:'officer'});await assert.rejects(api.mutate(as(command)),e=>e.code==='permission-denied');
});
test('identical replay is idempotent, changed replay is denied, audit failure rolls back',async()=>{
  const {db,api,request,as}=fixture(),command=request();await api.mutate(as(command));assert.equal((await api.mutate(as(command))).duplicate,true);
  await assert.rejects(api.mutate(as({...command,positionTitle:'Treasurer'})),e=>e.code==='conflict');
  const before=structuredClone(db.get(memberPath)),run=db.runTransaction.bind(db);db.runTransaction=fn=>run(t=>fn({...t,create:()=>{throw Error('Audit unavailable');}}));
  await assert.rejects(api.mutate(as(request({requestId:'audit_failure_0001'}))));assert.deepEqual(db.get(memberPath),before);
});
test('forged roles, capabilities, UID fields and inactive targets are rejected',async()=>{
  const {db,api,request,as}=fixture();
  for(const patch of [{role:'manager'},{role:'platformAdmin'},{platformRole:'platformAdmin'},{uid:'admin'},{positionTitle:''}])await assert.rejects(api.mutate(as(request(patch))),e=>e.code==='invalid-argument');
  for(const permissions of [{platformAdmin:true},{manageMemberships:true},{manageEvents:'yes'}])await assert.rejects(api.mutate(as({organizationId:'org',participantUid:'student',operation:'permissions',permissions,version:db.v(memberPath),requestId:'forged_permission_001'})),e=>e.code==='invalid-argument');
  db.seed(memberPath,{...db.get(memberPath),membershipStatus:'removed'});await assert.rejects(api.mutate(as(request())),e=>e.code==='failed-precondition');
});
test('membership HTTP endpoints preserve method and ID-token enforcement',async()=>{
  const handler=createHandler();for(const route of ['preview','mutate']){
    assert.equal((await handler(new Request(`https://worker/memberships/${route}`),{})).status,405);
    assert.equal((await handler(new Request(`https://worker/memberships/${route}`,{method:'POST',headers:{'Content-Type':'application/json'},body:'{}'}),{})).status,401);
  }
});
