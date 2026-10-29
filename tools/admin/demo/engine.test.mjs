import test from 'node:test';
import assert from 'node:assert/strict';
import {newManifest,manifestPlan,execute,publicId} from './engine.mjs';
import {firebaseBackend} from './firebase.mjs';

function harness(){
  const records=new Map(),accounts=new Map(),assets=new Map(),stats={creates:0,uploads:0,prepared:0,deletes:0};
  const snap=path=>({exists:records.has(path),ref:ref(path),data:()=>structuredClone(records.get(path))});
  const collection=path=>({doc:id=>ref(`${path}/${id}`),get:async()=>({docs:[...records.keys()].filter(p=>p.startsWith(path+'/')&&p.split('/').length===path.split('/').length+1).map(snap)}),where:(field,op,values)=>({get:async()=>({docs:[...records.entries()].filter(([p,d])=>p.startsWith(path+'/')&&p.split('/').length===path.split('/').length+1&&values.includes(d[field])).map(([p])=>snap(p))})})});
  const ref=path=>({path,collection:name=>collection(`${path}/${name}`),delete:async()=>records.delete(path),listCollections:async()=>[...new Set([...records.keys()].filter(p=>p.startsWith(path+'/')).map(p=>p.slice(0,path.length+1+p.slice(path.length+1).split('/')[0].length)))].map(collection)});
  const store={doc:ref,collection,runTransaction:async callback=>{
    const writes=[];let writing=false;const read=path=>{assert.equal(writing,false,'Firestore requires reads before writes');return snap(path);};
    const result=await callback({get:async r=>read(r.path),getAll:async(...refs)=>refs.map(r=>read(r.path)),create:(r,d)=>{writing=true;assert.equal(records.has(r.path),false);writes.push(()=>records.set(r.path,structuredClone(d)));},set:(r,d)=>{writing=true;writes.push(()=>records.set(r.path,structuredClone(d)));},update:(r,d)=>{writing=true;writes.push(()=>records.set(r.path,{...records.get(r.path),...structuredClone(d)}));},delete:r=>{writing=true;writes.push(()=>records.delete(r.path));}});writes.forEach(w=>w());return result;
  }};
  const missing=()=>Object.assign(Error('missing'),{code:'auth/user-not-found'});
  const auth={getUser:async uid=>{if(!accounts.has(uid))throw missing();return structuredClone(accounts.get(uid));},getUserByEmail:async email=>{const u=[...accounts.values()].find(u=>u.email===email);if(!u)throw missing();return structuredClone(u);},createUser:async data=>{stats.creates++;accounts.set(data.uid,{...structuredClone(data),password:undefined});return accounts.get(data.uid);},updateUser:async(uid,patch)=>accounts.set(uid,{...accounts.get(uid),...patch}),setCustomUserClaims:async(uid,claims)=>{accounts.get(uid).customClaims=claims;},deleteUser:async uid=>{stats.deletes++;accounts.delete(uid);}};
  const images={cloud:'test-cloud',inspect:async id=>assets.get(id)??null,upload:async(spec,buffer,owner)=>{stats.uploads++;const a={public_id:spec.publicId,asset_folder:spec.folder,context:{custom:{orglink_demo_owner:owner}},resource_type:'image',type:'upload',format:'png',bytes:buffer.length,width:768,height:768,secure_url:`https://res.cloudinary.com/test-cloud/image/upload/v1/${spec.publicId}.png`,asset_id:'asset-'+stats.uploads};assets.set(spec.publicId,a);return a;},destroy:async spec=>assets.delete(spec.publicId)};
  const prepare=async()=>{stats.prepared++;return {buffer:Buffer.from('synthetic mock PNG'),metadata:{sourceUrl:null,license:'CC0-1.0',attribution:'OrgLink test fixture'}};};
  const m=newManifest({anchor:'2026-10-29T06:00:00Z'}),backend=firebaseBackend({store,auth});
  return {records,accounts,assets,stats,images,backend,prepare,m,run:(mode='apply',extra={})=>execute({mode,manifest:m,backend,images,prepare,...extra})};
}
test('full mocked provisioning is idempotent, uses existing schemas and final image fields',async()=>{
  const h=harness();await h.run();assert.equal(h.m.state,'complete');assert.equal(h.accounts.size,20);assert.equal(h.assets.size,45);
  const p=manifestPlan(h.m);for(const i of p.images){const d=h.records.get(i.path);assert.equal(d[i.publicIdField],publicId(h.m,i.path));assert.ok(d[i.field].startsWith('https://res.cloudinary.com/'));assert.match(d.imageRevision,/^[a-f0-9]{64}$/);}
  assert.equal([...h.accounts.values()].filter(u=>!u.disabled).length,17);
  await h.run();assert.equal(h.stats.creates,20);assert.equal(h.stats.uploads,45);assert.equal(h.stats.prepared,45);
  assert.equal([...h.accounts.values()].some(u=>u.customClaims.platformAdmin),false);
});
test('partial uploaded asset is resumed from saved intent and never uploaded twice',async()=>{
  const h=harness(),upload=h.images.upload;let failed=false;h.images.upload=async(...args)=>{const result=await upload(...args);if(!failed){failed=true;throw Error('lost upload response');}return result;};
  await assert.rejects(h.run());assert.equal(h.assets.size,1);assert.ok(Object.values(h.m.assets)[0].metadata);await h.run();assert.equal(h.stats.uploads,45);assert.equal(h.stats.prepared,45);assert.equal(h.m.state,'complete');
});
test('cleanup removes only owned records/assets/accounts and is safely repeatable',async()=>{
  const h=harness();await h.run();h.records.set('users/real-student',{uid:'real-student',fullName:'Existing Student'});h.accounts.set('real-student',{uid:'real-student'});h.assets.set('foreign',{public_id:'foreign'});
  await h.run('cleanup');assert.equal(h.m.state,'cleaned');assert.deepEqual([...h.records.keys()],['users/real-student']);assert.deepEqual([...h.accounts.keys()],['real-student']);assert.deepEqual([...h.assets.keys()],['foreign']);await h.run('cleanup');assert.equal(h.stats.deletes,20);
});
test('cleanup resumes after a partial deletion without recreating removed resources',async()=>{
  const h=harness();await h.run();let n=0;await assert.rejects(h.run('cleanup',{save:async()=>{if(++n===8)throw Error('disk unavailable');}}));assert.equal(h.m.state,'cleaning');await assert.rejects(h.run());await h.run('cleanup');assert.equal(h.records.size,0);assert.equal(h.accounts.size,0);assert.equal(h.assets.size,0);
});
test('colliding Auth UID, email and Firestore resources are never overwritten',async()=>{
  for(const collision of ['auth','email','document','registry']){const h=harness(),p=manifestPlan(h.m),u=p.users[0];if(collision==='auth')h.accounts.set(u.uid,{uid:u.uid,email:u.email,displayName:u.fullName});if(collision==='email')h.accounts.set('someone-else',{uid:'someone-else',email:u.email});if(collision==='document')h.records.set(`users/${u.uid}`,{uid:u.uid,fullName:'Real data'});if(collision==='registry')h.records.set(`studentIds/${u.studentNumber}`,{uid:'real-owner'});await assert.rejects(h.run());assert.equal(h.stats.creates,0);assert.equal(h.stats.uploads,0);assert.ok([...h.records.values()].some(d=>d.fullName==='Real data'||d.uid==='real-owner')||h.accounts.size===1);}
});
test('modified records, foreign descendants and external manager assignments block all cleanup',async()=>{
  for(const change of ['profile','child','external-manager']){const h=harness();await h.run();const p=manifestPlan(h.m);if(change==='profile')h.records.get(`users/${p.users[0].uid}`).platformRole='platformAdmin';if(change==='child')h.records.set(`organizations/${p.organizations[0].organizationId}/events/real-event`,{title:'Existing event'});if(change==='external-manager')h.records.set('organizations/real-org',{managerUid:p.users[0].uid});const size=h.records.size;await assert.rejects(h.run('cleanup'));assert.equal(h.records.size,size);assert.equal(h.stats.deletes,0);assert.equal(h.assets.size,45);}
});
test('foreign Cloudinary owner prevents cleanup before Firestore or Auth deletion',async()=>{
  const h=harness();await h.run();[...h.assets.values()][0].context.custom.orglink_demo_owner='foreign';const size=h.records.size;await assert.rejects(h.run('cleanup'));assert.equal(h.records.size,size);assert.equal(h.accounts.size,20);
});
test('cleanup after a pre-existing collision removes only its ownership root',async()=>{
  const h=harness(),u=manifestPlan(h.m).users[0];h.records.set(`users/${u.uid}`,{uid:u.uid,fullName:'Real data'});h.accounts.set(u.uid,{uid:u.uid,email:u.email,displayName:'Real data'});await assert.rejects(h.run());await h.run('cleanup');assert.equal(h.m.state,'cleaned');assert.deepEqual([...h.records.keys()],[`users/${u.uid}`]);assert.equal(h.accounts.get(u.uid).displayName,'Real data');assert.equal(h.stats.deletes,0);
});
test('ownership marker recovers Auth creation interrupted before custom claims are saved',async()=>{
  const h=harness(),u=manifestPlan(h.m).users[0];h.accounts.set(u.uid,{uid:u.uid,email:u.email,displayName:`OrgLink Demo ${h.m.owner}`,disabled:true,emailVerified:true});await h.run();assert.equal(h.stats.creates,19);assert.equal(h.accounts.get(u.uid).displayName,u.fullName);assert.equal(h.accounts.get(u.uid).customClaims.orglinkDemoOwner,h.m.owner);
});
test('foreign manifests, arbitrary paths and altered public IDs cannot claim or clean a seed',async()=>{
  const h=harness();await h.run();const m2=newManifest({anchor:h.m.anchor});await assert.rejects(execute({mode:'cleanup',manifest:m2,backend:h.backend,images:h.images}));assert.equal(h.accounts.size,20);
  for(const key of ['documents','accounts','assets']){const m=structuredClone(h.m);m[key]['foreign/resource']={};assert.throws(()=>manifestPlan(m));}
  const m=structuredClone(h.m);Object.values(m.assets)[0].publicId='orglink/profiles/'+'f'.repeat(64);assert.throws(()=>manifestPlan(m));
});
