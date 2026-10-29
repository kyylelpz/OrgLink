import {test} from 'node:test';
import assert from 'node:assert/strict';
import {provisionAdministrator,main} from './provision-platform-admin.mjs';
function fixture(){
  let data={uid:'operator-target',email:'synthetic@example.edu',emailVerified:true,accountStatus:'pending',platformRole:'user',fullName:'Synthetic Student',studentNumber:'2026-001',yearLevel:1,section:'A',custom:'keep'},version=1;
  const logs=[];let writes=0;
  const snapshot=()=>({data:()=>({...data}),updateTime:{isEqual:v=>v.number===version,number:version}});
  const ref={get:async()=>snapshot()};
  const store={doc:path=>path.startsWith('users/')?ref:path,runTransaction:async fn=>fn({get:async()=>snapshot(),update:(_,changes)=>{data={...data,...changes};version++;writes++;},create:(path,log)=>logs.push({path,log})})};
  const identity={uid:'operator-target',email:'synthetic@example.edu',emailVerified:true,disabled:false};
  const auth={getUser:async()=>({...identity}),getUserByEmail:async()=>({...identity})};
  return {args:{auth,store,uid:identity.uid,email:identity.email,timestamp:()=> 'server-timestamp'},identity,logs,get data(){return data;},get writes(){return writes;}};
}
test('dry run and declined confirmation grant nothing',async()=>{for(const confirm of [async()=>false]){const f=fixture();assert.equal((await provisionAdministrator({...f.args,confirm})).applied,false);assert.equal(f.writes,0);assert.equal(f.logs.length,0);}});
test('confirmed provisioning preserves profile and is idempotent with an audit',async()=>{
  const f=fixture(),args={...f.args,confirm:async plan=>{assert.equal(plan.toRole,'platformAdmin');assert.ok(['pending','active'].includes(plan.fromStatus));return true;}};
  await provisionAdministrator(args);assert.equal(f.data.platformRole,'platformAdmin');assert.equal(f.data.accountStatus,'active');assert.equal(f.data.custom,'keep');assert.equal(f.logs.length,1);
  assert.equal((await provisionAdministrator(args)).alreadyProvisioned,true);assert.equal(f.writes,1);assert.equal(f.logs.length,1);
});
test('UID/email mismatch, disabled/unverified Auth and another project cannot grant admin',async()=>{
  for(const patch of [{uid:'different'},{email:'different@example.edu'},{emailVerified:false},{disabled:true}]){const f=fixture();Object.assign(f.identity,patch);await assert.rejects(provisionAdministrator({...f.args,confirm:async()=>true}));assert.equal(f.writes,0);}
  await assert.rejects(main(['--project','other','--uid','target','--email','synthetic@example.edu']));
});

test('profile changes between operator review and commit require a new confirmation',async()=>{
  const f=fixture();
  await assert.rejects(provisionAdministrator({...f.args,confirm:async()=>{
    await f.args.store.runTransaction(async t=>t.update(f.args.store.doc('users/operator-target'),{fullName:'Changed During Review'}));
    return true;
  }}),/changed after confirmation/);
  assert.equal(f.data.platformRole,'user');assert.equal(f.logs.length,0);
});
