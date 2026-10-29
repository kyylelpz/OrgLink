import {test,before} from 'node:test';
import assert from 'node:assert/strict';
import {adminBackend} from '../src/admin.js';
import {createHandler} from '../src/index.js';
import {encode} from '../src/firestore.js';
import {tokenFixture} from './token-fixture.js';
export const profile=(uid,status='active',role='user')=>({uid,email:`${uid}@example.edu`,fullName:'Synthetic Student',studentNumber:'2026-001',yearLevel:1,section:'A',accountStatus:status,platformRole:role});
export class MemoryDb {
  records=new Map();version=0;tail=Promise.resolve();failAudit=false;
  doc(path){return path;}
  seed(path,value){this.records.set(path,{value:structuredClone(value),version:`v${++this.version}`});}
  get(path){return this.records.get(path)?.value;}
  v(path){return this.records.get(path)?.version;}
  async runTransaction(fn){
    const previous=this.tail;let release;this.tail=new Promise(resolve=>release=resolve);await previous;
    const writes=[];
    const query=async q=>{
      const collection=q.from[0].collectionId;
      let rows=[...this.records].filter(([p])=>p.startsWith(collection+'/')&&p.split('/').length===2)
        .map(([p,r])=>({...structuredClone(r.value),id:p.split('/').at(-1),version:r.version}));
      const value=(row,field)=>field==='__name__'?`${collection}/${row.id}`:row[field];
      const matches=(row,f)=>{if(f.compositeFilter)return f.compositeFilter.filters.every(x=>matches(row,x));
        const x=f.fieldFilter,a=value(row,x.field.fieldPath),b=x.value.stringValue??x.value.referenceValue;
        return x.op==='EQUAL'?a===b:x.op==='GREATER_THAN_OR_EQUAL'?a>=b:a<b;};
      if(q.where)rows=rows.filter(row=>matches(row,q.where));
      const orders=q.orderBy??[];
      rows=rows.filter(row=>orders.every(o=>value(row,o.field.fieldPath)!==undefined));
      rows.sort((a,b)=>{for(const o of orders){const x=value(a,o.field.fieldPath),y=value(b,o.field.fieldPath);if(x!==y)return x<y?-1:1;}return 0;});
      if(q.startAt) rows=rows.filter(row=>{for(let i=0;i<orders.length;i++){const a=value(row,orders[i].field.fieldPath),b=q.startAt.values[i].stringValue??q.startAt.values[i].referenceValue;if(a!==b)return a>b;}return false;});
      return rows.slice(0,q.limit??rows.length);
    };
    const t={getAll:async(...paths)=>paths.map(path=>({data:()=>structuredClone(this.get(path)),updateTime:this.v(path)})),query,
      count:async q=>(await query(q)).length,
      create:(path,data)=>{if(this.get(path))throw Error('Already exists');if(this.failAudit&&path.startsWith('activityLogs/'))throw Error('Audit failed');writes.push([path,data]);},
      update:(path,data)=>writes.push([path,{...this.get(path),...data}]),set:(path,data)=>writes.push([path,data])};
    try{const result=await fn(t);for(const [path,data] of writes)this.seed(path,data);return result;}finally{release();}
  }
}
function fixture(){const db=new MemoryDb();db.seed('users/admin',profile('admin','active','platformAdmin'));db.seed('users/student',profile('student','pending'));db.seed('users/manager',profile('manager'));return {db,api:adminBackend(db,()=>1700000000000)};}
const command=(db,extra={})=>({requestId:'request_0001',operation:'accountStatus',targetId:'student',version:db.v('users/student'),action:'approve',...extra});
const as=(uid,data)=>({auth:{uid},data});
const denied=e=>e.code==='permission-denied';
test('ordinary users, organization managers, pending/inactive admins and forged role bodies cannot invoke platform operations',async()=>{
  const {db,api}=fixture();db.seed('organizations/org',{organizationId:'org',managerUid:'manager'});
  for(const uid of ['student','manager','missing'])for(const call of [()=>api.stats(as(uid,{})),()=>api.list(as(uid,{collection:'users'})),()=>api.mutate(as(uid,command(db)))])await assert.rejects(call,denied);
  for(const status of ['pending','disabled','suspended']){db.seed('users/admin',profile('admin',status,'platformAdmin'));await assert.rejects(api.stats(as('admin',{})),denied);}
  assert.equal(db.get('users/student').accountStatus,'pending');assert.equal([...db.records.keys()].filter(k=>k.startsWith('activityLogs/')).length,0);
});
test('approval preserves UID, email, profile, role and unrelated data; audit and idempotent replay are atomic',async()=>{
  const {db,api}=fixture();db.seed('users/student',{...db.get('users/student'),college:'Stored College',custom:'keep'});const before=structuredClone(db.get('users/student')),data=command(db);
  await api.mutate(as('admin',data));const after=db.get('users/student');
  for(const k of Object.keys(before))if(k!=='accountStatus')assert.deepEqual(after[k],before[k]);assert.equal(after.accountStatus,'active');
  assert.equal((await api.mutate(as('admin',data))).duplicate,true);
  const audits=[...db.records.keys()].filter(k=>k.startsWith('activityLogs/'));assert.equal(audits.length,1);
  const log=db.get(audits[0]);assert.equal(log.actorUid,'admin');assert.equal(log.before.accountStatus,'pending');assert.equal(log.after.accountStatus,'active');
  await assert.rejects(api.mutate(as('admin',{...data,action:'reject'})),e=>e.code==='conflict');
});
test('self and other administrator deactivation, role payloads and stale versions are denied',async()=>{
  const {db,api}=fixture();db.seed('users/otherAdmin',profile('otherAdmin','active','platformAdmin'));
  for(const uid of ['admin','otherAdmin'])await assert.rejects(api.mutate(as('admin',command(db,{targetId:uid,version:db.v('users/'+uid),action:'deactivate'}))),denied);
  await assert.rejects(api.mutate(as('admin',command(db,{platformRole:'platformAdmin'}))),e=>e.code==='invalid-argument');
  await assert.rejects(api.mutate(as('admin',command(db,{version:'stale'}))),e=>e.code==='conflict');
  db.failAudit=true;await assert.rejects(api.mutate(as('admin',command(db))));assert.equal(db.get('users/student').accountStatus,'pending');
});
test('pending rejection and active deactivation preserve identity; incomplete approval is denied',async()=>{
  const {db,api}=fixture();await api.mutate(as('admin',command(db,{action:'reject'})));assert.equal(db.get('users/student').accountStatus,'rejected');
  await api.mutate(as('admin',command(db,{targetId:'manager',version:db.v('users/manager'),requestId:'request_0002',action:'deactivate'})));assert.equal(db.get('users/manager').accountStatus,'disabled');
  db.seed('users/student',{...profile('student','pending'),section:''});await assert.rejects(api.mutate(as('admin',command(db,{requestId:'request_0003'}))),e=>e.code==='failed-precondition');
});
test('competing approval/rejection has exactly one winner and one audit',async()=>{
  const {db,api}=fixture(),data=command(db);const results=await Promise.allSettled([api.mutate(as('admin',data)),api.mutate(as('admin',{...data,requestId:'request_0002',action:'reject'}))]);
  assert.equal(results.filter(r=>r.status==='fulfilled').length,1);assert.equal(results.find(r=>r.status==='rejected').reason.code,'conflict');
  assert.equal([...db.records.keys()].filter(k=>k.startsWith('activityLogs/')).length,1);
});
test('organization create/edit/reassign retains children and membership data and checks expected ownership',async()=>{
  const {db,api}=fixture();const create={requestId:'create_0001',operation:'createOrganization',targetId:'org',changes:{name:'IEEE iOS Society',managerUid:'manager',visibility:'private',status:'active',acceptsRequests:false}};
  await api.mutate(as('admin',create));assert.equal(db.get('organizations/org').name,'IEEE iOS Society');assert.equal(db.get('organizations/org').approvalSettings.mode,'manual');
  assert.equal((await api.mutate(as('admin',create))).duplicate,true);
  db.seed('organizations/org/events/event',{title:'keep'});db.seed('organizations/org/memberships/manager',{membershipRole:'manager',membershipStatus:'active'});
  db.seed('users/newManager',profile('newManager'));
  const update={requestId:'update_0001',operation:'updateOrganization',targetId:'org',version:db.v('organizations/org'),expectedManagerUid:'manager',changes:{managerUid:'newManager',description:'Updated'}};
  await api.mutate(as('admin',update));assert.equal(db.get('organizations/org').managerUid,'newManager');assert.equal(db.get('organizations/org').name,'IEEE iOS Society');
  assert.equal(db.get('organizations/org/events/event').title,'keep');assert.equal(db.get('organizations/org/memberships/manager').membershipRole,'manager');
  await assert.rejects(api.mutate(as('admin',{...update,requestId:'update_0002',version:db.v('organizations/org')})),e=>e.code==='conflict');
  await assert.rejects(api.mutate(as('admin',{...create,requestId:'create_0002'})),e=>e.code==='already-exists');
});
test('ineligible manager, arbitrary fields, invalid logo/protocol and oversized text cannot write',async()=>{
  const {db,api}=fixture();
  for(const changes of [{managerUid:'student'},{managerUid:'missing'},{platformRole:'platformAdmin'},{logoURL:'http://example.edu/logo'},{name:'x'.repeat(101)},{status:'deleted'}]){
    await assert.rejects(api.mutate(as('admin',{requestId:'create_0001',operation:'createOrganization',targetId:'org',changes:{name:'Society',managerUid:'manager',visibility:'public',status:'active',...changes}})));
    assert.equal(db.get('organizations/org'),undefined);
  }
});
test('real counts, ordered cursor pages, prefix/exact searches and allowlisted collections',async()=>{
  const {db,api}=fixture();for(let i=0;i<30;i++)db.seed('users/member'+i,{...profile('member'+i),fullName:'Prefix Student '+String(i).padStart(2,'0')});
  const stats=await api.stats(as('admin',{}));assert.deepEqual(stats,{users:33,pending:1,organizations:0});
  const first=await api.list(as('admin',{collection:'users',field:'fullName',search:'Prefix'}));assert.equal(first.items.length,25);assert.ok(first.nextCursor);
  const second=await api.list(as('admin',{collection:'users',field:'fullName',search:'Prefix',cursor:first.nextCursor}));assert.equal(second.items.length,5);assert.equal(second.nextCursor,null);
  assert.equal(new Set([...first.items,...second.items].map(x=>x.id)).size,30);
  assert.equal((await api.list(as('admin',{collection:'users',field:'email',search:'manager@example.edu'}))).items[0].id,'manager');
  await assert.rejects(api.list(as('admin',{collection:'activityLogs'})),e=>e.code==='invalid-argument');
});
let tokens;before(async()=>{tokens=await tokenFixture();});
test('HTTP boundary verifies Firebase signature and ignores a forged platformAdmin claim',async()=>{
  let calls=0;const handler=createHandler({fetchImpl:async(url,options)=>{
    if(String(url).includes('/jwk/'))return tokens.fetchKeys(url,options);
    calls++;if(String(url).endsWith(':beginTransaction'))return Response.json({transaction:'test-only'});
    if(String(url).endsWith(':batchGet'))return Response.json([{found:{name:'projects/orglink-dev/databases/(default)/documents/users/manager',fields:encode(profile('manager')).mapValue.fields,updateTime:'v1'}}]);
    return Response.json({});
  }});
  const env={FIRESTORE_EMULATOR_HOST:'127.0.0.1:8589'};
  assert.equal((await handler(new Request('https://example.test/admin/stats',{method:'POST',headers:{'Content-Type':'application/json'},body:'{}'}),env)).status,401);
  assert.equal(calls,0);
  for(const [path,data] of [['/admin/stats',{}],['/admin/mutate',{operation:'accountStatus',action:'reactivate',targetId:'student',version:'v1',requestId:'request_0001'}]]) {
    const result=await handler(new Request('https://example.test'+path,{method:'POST',headers:{'Content-Type':'application/json',Authorization:`Bearer ${await tokens.sign('manager',{platformRole:'platformAdmin',email:'ignored@example.edu'})}`},body:JSON.stringify(data)}),env);
    assert.equal(result.status,403);assert.equal((await result.json()).error.code,'permission-denied');
  }
});

test('malformed typed student identity cannot be approved or assigned as manager',async()=>{
  for(const patch of [{studentNumber:2026001},{section:1},{email:''}]){
    const {db,api}=fixture();db.seed('users/student',{...profile('student','pending'),...patch});
    await assert.rejects(api.mutate(as('admin',command(db))),e=>e.code==='failed-precondition');
    db.seed('users/manager',{...profile('manager'),...patch});
    await assert.rejects(api.mutate(as('admin',{requestId:'invalid_0001',operation:'createOrganization',targetId:'invalid-org',changes:{name:'Society',managerUid:'manager',visibility:'public',status:'active'}})),e=>e.code==='failed-precondition');
  }
});

test('reactivation preserves identity/profile/history, refresh eligibility and exactly one audit on replay',async()=>{
  const {db,api}=fixture();db.seed('users/student',{...profile('student','disabled'),college:'Stored College',custom:'keep'});
  const paths=['organizations/org/memberships/student','organizations/org/events/event','organizations/org/events/event/attendance/student'];
  for(const path of paths)db.seed(path,{existing:'keep'});
  const before=structuredClone(db.get('users/student'));
  const page=await api.list(as('admin',{collection:'users',field:'__name__',search:'student'}));assert.equal(page.items[0].canReactivate,true);
  const data=command(db,{action:'reactivate'});await api.mutate(as('admin',data));
  const after=db.get('users/student');assert.equal(after.accountStatus,'active');
  for(const k of Object.keys(before))if(k!=='accountStatus')assert.deepEqual(after[k],before[k]);
  for(const path of paths)assert.deepEqual(db.get(path),{existing:'keep'});
  assert.equal((await api.mutate(as('admin',data))).duplicate,true);
  const logs=[...db.records].filter(([k])=>k.startsWith('activityLogs/'));assert.equal(logs.length,1);
  const log=logs[0][1].value;assert.equal(log.actorUid,'admin');assert.equal(log.request.action,'reactivate');
  assert.deepEqual(log.before,{accountStatus:'disabled'});assert.deepEqual(log.after,{accountStatus:'active'});assert.ok(log.createdAt);
  assert.equal((await api.list(as('admin',{collection:'users',field:'__name__',search:'student'}))).items[0].canReactivate,false);
});
test('reactivation denies ordinary users/managers, inactive administrators, self and other administrators',async()=>{
  const {db,api}=fixture();db.seed('users/student',profile('student','disabled'));const data=command(db,{action:'reactivate'});
  for(const uid of ['student','manager','missing'])await assert.rejects(api.mutate(as(uid,data)),denied);
  db.seed('users/otherAdmin',profile('otherAdmin','disabled','platformAdmin'));
  for(const uid of ['admin','otherAdmin'])await assert.rejects(api.mutate(as('admin',{...data,targetId:uid,version:db.v('users/'+uid)})),denied);
  db.seed('users/admin',profile('admin','disabled','platformAdmin'));await assert.rejects(api.mutate(as('admin',data)),denied);
  assert.equal(db.get('users/student').accountStatus,'disabled');assert.equal([...db.records.keys()].filter(k=>k.startsWith('activityLogs/')).length,0);
});
test('rejected, non-disabled and incomplete/malformed accounts are not eligible for reactivation',async()=>{
  for(const patch of [{accountStatus:'rejected'},{accountStatus:'pending'},{accountStatus:'active'},{accountStatus:'suspended'},{section:''},{studentNumber:2026001},{email:''}]){
    const {db,api}=fixture();db.seed('users/student',{...profile('student','disabled'),...patch});
    const listed=await api.list(as('admin',{collection:'users',field:'__name__',search:'student'}));assert.equal(listed.items[0].canReactivate,false);
    await assert.rejects(api.mutate(as('admin',command(db,{action:'reactivate'}))),e=>e.code==='failed-precondition');
    assert.equal([...db.records.keys()].filter(k=>k.startsWith('activityLogs/')).length,0);
  }
});
test('reactivation checks stale versions and rolls back when audit creation fails',async()=>{
  const {db,api}=fixture();db.seed('users/student',profile('student','disabled'));
  await assert.rejects(api.mutate(as('admin',command(db,{action:'reactivate',version:'stale'}))),e=>e.code==='conflict');
  db.failAudit=true;await assert.rejects(api.mutate(as('admin',command(db,{action:'reactivate'}))));
  assert.equal(db.get('users/student').accountStatus,'disabled');assert.equal([...db.records.keys()].filter(k=>k.startsWith('activityLogs/')).length,0);
});
test('competing reactivation requests commit only once',async()=>{
  const {db,api}=fixture();db.seed('users/student',profile('student','disabled'));const data=command(db,{action:'reactivate'});
  const results=await Promise.allSettled([api.mutate(as('admin',data)),api.mutate(as('admin',{...data,requestId:'reactivate_0002'}))]);
  assert.equal(results.filter(r=>r.status==='fulfilled').length,1);assert.equal(results.find(r=>r.status==='rejected').reason.code,'conflict');
  assert.equal([...db.records.keys()].filter(k=>k.startsWith('activityLogs/')).length,1);
});
