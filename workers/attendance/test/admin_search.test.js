import {test} from 'node:test';
import assert from 'node:assert/strict';
import {MemoryDb} from './support/memory_db.js';
import {adminBackend} from '../src/admin.js';
import {createDirectorySearchCache,SEARCH_LIMIT,SEARCH_TTL} from '../src/admin_search.js';
const profile=(uid,name='Demo Student')=>({uid,email:`${uid}@School.EDU`,fullName:name,studentNumber:'2026000123',yearLevel:1,section:'A',platformRole:'user',accountStatus:'active'});
function fixture(){
  let now=100000,scans=0;
  const db=new MemoryDb();db.seed('users/admin',{...profile('admin','Platform Administrator'),platformRole:'platformAdmin'});
  const run=db.runTransaction.bind(db);const queries=[];
  db.runTransaction=fn=>run(t=>fn({...t,query:q=>{scans++;queries.push(q);return t.query(q);}}));
  const cache=createDirectorySearchCache(()=>now),api=adminBackend(db,()=>now,cache);
  const list=(data,uid='admin')=>api.list({auth:{uid},data:{collection:'users',field:'fullName',...data}});
  return {db,api,list,queries,scans:()=>scans,advance:()=>now+=SEARCH_TTL+1};
}
test('case-insensitive literal substrings find first, middle, surname, full name, email and Student ID',async()=>{
  const {db,list}=fixture();
  db.seed('users/anna',profile('anna','Anna Louise de la Cruz'));
  db.seed('users/miguel',profile('miguel','de la Cruz Miguel Santos'));
  db.seed('users/diego',profile('diego','Diego Martinez Cruz Jr'));
  for(const query of ['  cRuZ  ','annA','LOUI','ANNA LOUISE DE LA CRUZ']){
    const results=await list({search:query});assert.ok(results.items.some(r=>r.id==='anna'));
    if(query.trim().toLowerCase()==='cruz')assert.equal(results.items.length,3);
  }
  assert.equal((await list({field:'email',search:'ANNA@SCHO'})).items[0].email,'anna@School.EDU');
  assert.equal((await list({field:'studentNumber',search:' 00012 '})).items.length,4);
  assert.equal((await list({field:'__name__',search:'ANN'})).items[0].id,'anna');
  assert.equal((await list({search:'missing value'})).items.length,0);
});
test('organization names and document identifiers support partial case-insensitive search',async()=>{
  const {db,list}=fixture();db.seed('users/manager',profile('manager'));
  db.seed('organizations/org-Robotics-001',{organizationId:'org-Robotics-001',name:'University Robotics Guild',managerUid:'manager'});
  for(const [field,search] of [['name','ROBOT'],['name','guild'],['__name__','BOTICS-0']]){
    const result=await list({collection:'organizations',field,search});assert.equal(result.items[0].name,'University Robotics Guild');
  }
});
test('search covers records beyond the loaded page and paginates 25/25/20 without duplicates',async()=>{
  const {db,list,scans}=fixture();for(let i=0;i<70;i++)db.seed(`users/person-${i}`,profile(`person-${i}`,`${i%2?'ANNA':'Anna'} Cruz ${String(i).padStart(3,'0')}`));
  const first=await list({search:'CRUZ'}),second=await list({search:'cruz',cursor:first.nextCursor}),third=await list({search:'cRuZ',cursor:second.nextCursor});
  assert.deepEqual([first.items.length,second.items.length,third.items.length],[25,25,20]);assert.equal(third.nextCursor,null);
  assert.equal(new Set([...first.items,...second.items,...third.items].map(r=>r.id)).size,70);
  assert.equal((await list({search:'069'})).items[0].id,'person-69');assert.equal(scans(),1);
});
test('empty/whitespace queries use the original bounded directory query and cursor',async()=>{
  const {db,list,queries}=fixture();for(let i=0;i<30;i++)db.seed(`users/${i}`,profile(`${i}`,`Person ${i}`));
  const first=await list({field:'email',search:'   '}),second=await list({search:'',cursor:first.nextCursor});
  assert.equal(first.items.length,25);assert.equal(second.items.length,6);assert.equal(queries[0].limit,26);assert.equal(queries[0].orderBy[0].field.fieldPath,'fullName');
});
test('bounded cache shares different searches; explicit refresh, expiry and admin mutations invalidate it',async()=>{
  const {db,api,list,scans,advance}=fixture();db.seed('users/anna',profile('anna','Anna Cruz'));
  await list({search:'cruz'});await list({field:'email',search:'SCHOOL'});assert.equal(scans(),1);
  db.seed('users/new',profile('new','Fresh Student'));assert.equal((await list({search:'fresh'})).items.length,0);
  assert.equal((await list({search:'fresh',refresh:true})).items.length,1);assert.equal(scans(),2);
  advance();await list({search:'cruz'});assert.equal(scans(),3);
  await api.mutate({auth:{uid:'admin'},data:{operation:'accountStatus',targetId:'anna',version:db.v('users/anna'),action:'deactivate',requestId:'search_invalidate_01'}});
  assert.equal((await list({search:'cruz'})).items[0].canReactivate,true);assert.equal(scans(),4);
  assert.equal([...db.records.keys()].filter(p=>p.startsWith('activityLogs/')).length,1);
});
test('authorization is checked on every warm-cache request and unauthorized refresh cannot scan',async()=>{
  const {db,list,scans}=fixture();db.seed('users/student',profile('student','Student Cruz'));await list({search:'cruz'});
  await assert.rejects(list({search:'cruz',refresh:true},'student'),e=>e.code==='permission-denied');
  db.seed('users/admin',{...db.get('users/admin'),accountStatus:'disabled'});await assert.rejects(list({search:'cruz'}),e=>e.code==='permission-denied');assert.equal(scans(),1);
});
test('oversized directories fail explicitly and cache the bounded probe instead of incomplete matching',async()=>{
  const {db,list,queries,scans}=fixture();for(let i=0;i<SEARCH_LIMIT;i++)db.seed(`users/${i}`,profile(String(i),'Cruz'));
  await assert.rejects(list({search:'cruz'}),e=>e.code==='resource-exhausted');
  await assert.rejects(list({search:'another'}),e=>e.code==='resource-exhausted');assert.equal(scans(),1);assert.equal(queries[0].limit,SEARCH_LIMIT+1);
  assert.equal((await list({search:''})).items.length,25);
});
test('cache coalesces concurrent misses, isolates namespaces and never retains a failed load',async()=>{
  const cache=createDirectorySearchCache();let calls=0;
  const load=async()=>{calls++;return ['record'];};await Promise.all([cache.get('users',load),cache.get('users',load)]);assert.equal(calls,1);
  await cache.get('organizations',load);assert.equal(calls,2);
  await assert.rejects(cache.get('failure',async()=>{throw Error('network');}));
  assert.deepEqual(await cache.get('failure',load),['record']);
});
test('manager assignment still requires exact valid Student ID and rejects partial directory queries',async()=>{
  const {api}=fixture();await assert.rejects(api.manager({auth:{uid:'admin'},data:{studentId:'00012'}}),e=>e.code==='invalid-argument');
});
