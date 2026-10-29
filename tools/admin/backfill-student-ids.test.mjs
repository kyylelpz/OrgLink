import {test} from 'node:test';
import assert from 'node:assert/strict';
import {analyzeStudentIds,claimExistingStudentId,main} from './backfill-student-ids.mjs';
import {MemoryDb} from '../../workers/attendance/test/support/memory_db.js';
const profile=(id,sid)=>({id,uid:id,email:`${id}@example.edu`,studentNumber:sid});
function fixture(){
  const db=new MemoryDb();db.seed('users/student',profile('student','2026000001'));
  const store={doc:p=>p,collection:()=>({where:(_,__,value)=>({limit:()=>value})}),runTransaction:fn=>db.runTransaction(t=>fn({...t,get:async sid=>({docs:(await t.query({from:[{collectionId:'users'}],where:{fieldFilter:{field:{fieldPath:'studentNumber'},op:'EQUAL',value:{stringValue:sid}}},limit:2})).map(r=>({id:r.id}))})}))};
  const auth={getUser:async uid=>({uid,email:`${uid}@example.edu`})};return {db,store,auth};
}
test('audit detects missing/invalid/integer/duplicate IDs, UID mismatches and stale/conflicting registry without normalization',()=>{
  const report=analyzeStudentIds([profile('a','2026000001'),profile('b','2026000001'),profile('c','2026-001'),profile('d',2026000002),profile('e',null),{...profile('f','2026000003'),uid:'wrong'},profile('g','2026000004')],
    [{id:'2026000004',uid:'other',state:'active'},{id:'2026000099',uid:'missing',state:'active'}]);
  assert.equal(report.duplicates.length,1);assert.deepEqual(report.duplicates[0].uids,['a','b']);assert.equal(report.invalid.length,2);assert.equal(report.missing.length,1);assert.equal(report.identityMismatches.length,1);assert.equal(report.registryConflicts.length,1);assert.equal(report.staleRegistry.length,2);
});
test('backfill is idempotent, validates Auth identity and never edits the stored Student ID or profile',async()=>{
  const f=fixture(),candidate={uid:'student',email:'student@example.edu',studentId:'2026000001'};
  const before=structuredClone(f.db.get('users/student'));
  assert.equal((await claimExistingStudentId({...f,candidate,timestamp:()=> 'server-time'})).result,'claimed');
  assert.equal((await claimExistingStudentId({...f,candidate,timestamp:()=> 'server-time'})).result,'unchanged');assert.deepEqual(f.db.get('users/student'),before);assert.equal(f.db.get('studentIds/2026000001').uid,'student');
  await assert.rejects(claimExistingStudentId({...f,candidate,auth:{getUser:async()=>({uid:'other',email:'student@example.edu'})},timestamp:()=>0}));
});
test('conflicts, duplicates and profile changes since the audit are reported instead of overwritten',async()=>{
  for(const mode of ['conflict','duplicate','changed']){
    const f=fixture(),candidate={uid:'student',email:'student@example.edu',studentId:'2026000001'};
    if(mode==='conflict')f.db.seed('studentIds/2026000001',{uid:'other',state:'active'});
    if(mode==='duplicate')f.db.seed('users/other',profile('other','2026000001'));
    if(mode==='changed')f.db.seed('users/student',profile('student','2026000002'));
    await assert.rejects(claimExistingStudentId({...f,candidate,timestamp:()=>0}));
    if(mode!=='conflict')assert.equal(f.db.get('studentIds/2026000001'),undefined);else assert.equal(f.db.get('studentIds/2026000001').uid,'other');
  }
});
test('operator command refuses another project before loading credentials',async()=>{await assert.rejects(main(['--project','other']));});
