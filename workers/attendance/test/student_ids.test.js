import {test} from 'node:test';
import assert from 'node:assert/strict';
import {profileBackend,resolveStudentId,validStudentId} from '../src/student_ids.js';
import {adminBackend} from '../src/admin.js';
import {MemoryDb} from './support/memory_db.js';
const details=(studentNumber='2026000001')=>({fullName:'McDonald de la Cruz',studentNumber,yearLevel:6,section:'A',college:'College of Engineering',program:'Bachelor of Science in Computer Engineering'});
const request=(uid='student',sid='2026000001')=>({auth:{uid,email:`${uid}@example.edu`},data:{details:details(sid)}});
const seed=(db,uid,sid,status='active',role='user')=>{db.seed('users/'+uid,{...details(sid),uid,email:`${uid}@example.edu`,platformRole:role,accountStatus:status});db.seed('studentIds/'+sid,{uid,state:'active'});};
test('strict string format, leading sequence zeros, assigned year and pending defaults',async()=>{
  for(const value of [null,2026000001,'202600001','20260000011','2026-00001','2026 00001','2026a00001',' 2026000001','2026000001 ','2026000001\n',String.fromCharCode(...Array(10).fill(0xff11))]){
    assert.equal(validStudentId(value),false);const db=new MemoryDb();await assert.rejects(profileBackend(db).save(request('student',value)),e=>e.code==='invalid-argument');assert.equal(db.records.size,0);
  }
  const db=new MemoryDb(),api=profileBackend(db);await api.save(request());await api.save(request());
  assert.equal(db.get('users/student').studentNumber,'2026000001');assert.equal(db.get('users/student').yearLevel,6);
  assert.equal(db.get('users/student').accountStatus,'pending');assert.equal(db.get('users/student').platformRole,'user');
  assert.equal(db.get('studentIds/2026000001').uid,'student');assert.equal([...db.records.keys()].filter(k=>k.startsWith('activityLogs/')).length,1);
});
test('concurrent different UIDs cannot claim the same ID or leave a losing profile',async()=>{
  const db=new MemoryDb(),api=profileBackend(db);const results=await Promise.allSettled([api.save(request('first')),api.save(request('second'))]);
  assert.equal(results.filter(r=>r.status==='fulfilled').length,1);assert.equal(results.find(r=>r.status==='rejected').reason.code,'already-exists');
  assert.equal([...db.records.keys()].filter(k=>k.startsWith('users/')).length,1);
});
test('changes preserve profile privileges/history and reserve retired IDs against theft',async()=>{
  const db=new MemoryDb();seed(db,'student','2026000001','active','platformAdmin');seed(db,'other','2026000002');db.seed('organizations/org/events/event/attendance/student',{kept:true});
  await assert.rejects(profileBackend(db).save(request('student','2026000002')),e=>e.code==='already-exists');
  assert.equal(db.get('users/student').studentNumber,'2026000001');await profileBackend(db).save(request('student','2026000003'));
  assert.equal(db.get('users/student').platformRole,'platformAdmin');assert.equal(db.get('users/student').accountStatus,'active');
  assert.equal(db.get('studentIds/2026000001').state,'retired');assert.equal(db.get('organizations/org/events/event/attendance/student').kept,true);
  await assert.rejects(profileBackend(db).save(request('intruder','2026000001')),e=>e.code==='already-exists');
  await profileBackend(db).save(request('student','2026000001'));assert.equal(db.get('studentIds/2026000001').state,'active');
});
test('audit failure leaves no orphaned claim, partial ID change or profile',async()=>{
  const db=new MemoryDb();db.failAudit=true;await assert.rejects(profileBackend(db).save(request()));assert.equal(db.records.size,0);
  db.failAudit=false;seed(db,'student','2026000001');db.failAudit=true;await assert.rejects(profileBackend(db).save(request('student','2026000002')));
  assert.equal(db.get('users/student').studentNumber,'2026000001');assert.equal(db.get('studentIds/2026000001').state,'active');assert.equal(db.get('studentIds/2026000002'),undefined);
});
test('legacy ownership blocks stealing before backfill; ambiguous registry cannot resolve a manager',async()=>{
  const db=new MemoryDb();db.seed('users/legacy',{...details(),uid:'legacy'});
  await assert.rejects(profileBackend(db).save(request()),e=>e.code==='already-exists');
  db.seed('users/duplicate',{...details(),uid:'duplicate'});db.seed('studentIds/2026000001',{uid:'legacy',state:'active'});
  await assert.rejects(db.runTransaction(t=>resolveStudentId(t,db,'2026000001')),e=>e.code==='failed-precondition');
});
test('client role/UID/status payloads and mismatched existing identities cannot overwrite profiles',async()=>{
  const db=new MemoryDb(),api=profileBackend(db);
  for(const extra of [{uid:'victim'},{platformRole:'platformAdmin'},{accountStatus:'active'}])await assert.rejects(api.save({...request(),data:{details:{...details(),...extra}}}),e=>e.code==='invalid-argument');
  seed(db,'student','2026000001');const r=request();r.auth.email='someone@example.edu';await assert.rejects(api.save(r),e=>e.code==='permission-denied');
});
test('protected manager resolution checks eligible account, stale profile/registry and refuses UID assignment',async()=>{
  const db=new MemoryDb();seed(db,'admin','2026000010','active','platformAdmin');seed(db,'manager','2026000001');const api=adminBackend(db);
  const lookup={auth:{uid:'admin'},data:{studentId:'2026000001'}};
  await assert.rejects(api.manager({...lookup,auth:{uid:'manager'}}),e=>e.code==='permission-denied');
  const p=await api.manager(lookup);assert.equal(p.eligible,true);assert.equal(p.studentId,'2026000001');
  const changes={name:'IEEE iOS Society',visibility:'private',status:'active',managerStudentId:p.studentId,managerProfileVersion:p.version,managerRegistryVersion:p.registryVersion};
  const req={auth:{uid:'admin'},data:{operation:'createOrganization',targetId:'org',requestId:'create_test_001',changes}};
  await assert.rejects(api.mutate({...req,data:{...req.data,changes:{...changes,managerUid:'attacker'}}}),e=>e.code==='invalid-argument');
  db.seed('users/manager',{...db.get('users/manager'),fullName:'Changed Name'});await assert.rejects(api.mutate(req),e=>e.code==='conflict');
  req.data.changes.managerProfileVersion=db.v('users/manager');db.seed('studentIds/2026000001',{uid:'manager',state:'active'});await assert.rejects(api.mutate(req),e=>e.code==='conflict');
  req.data.changes.managerRegistryVersion=db.v('studentIds/2026000001');await api.mutate(req);assert.equal(db.get('organizations/org').managerUid,'manager');
  db.seed('users/manager',{...db.get('users/manager'),accountStatus:'disabled'});const disabled=await api.manager(lookup);assert.equal(disabled.eligible,false);
  await assert.rejects(api.mutate({...req,data:{...req.data,targetId:'other',requestId:'create_test_002',changes:{...changes,managerProfileVersion:disabled.version}}}),e=>e.code==='failed-precondition');
});
test('missing, invalid, retired, stale and duplicated manager mappings fail closed',async()=>{
  const db=new MemoryDb();seed(db,'admin','2026000010','active','platformAdmin');const api=adminBackend(db);const lookup={auth:{uid:'admin'},data:{studentId:'2026000001'}};
  await assert.rejects(api.manager(lookup));await assert.rejects(api.manager({...lookup,data:{studentId:'bad'}}));
  seed(db,'manager','2026000001');for(const mapping of [{uid:'manager',state:'retired'},{uid:'missing',state:'active'}]){db.seed('studentIds/2026000001',mapping);await assert.rejects(api.manager(lookup));}
});
