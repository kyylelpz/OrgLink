import {hash} from './dataset.mjs';
import {marker,ownsAccount} from './engine.mjs';

// Canonical hashing treats SDK Timestamps and fixture Dates identically.
export function canonical(value){
  if(value instanceof Date)return value.toISOString();
  if(value&&typeof value.toDate==='function')return value.toDate().toISOString();
  if(Array.isArray(value))return value.map(canonical);
  if(value&&typeof value==='object')return Object.fromEntries(Object.keys(value).sort().map(k=>[k,canonical(value[k])]));
  return value;
}
export const digest=value=>hash(canonical(value));
export function firebaseBackend({store,auth}) {
  const root=m=>store.doc(`_demoSeeds/${m.seed}`), ledger=(m,path)=>root(m).collection('resources').doc(hash(path));
  async function check(t,m,path,cleanup=false){
    const [doc,claim]=await t.getAll(store.doc(path),ledger(m,path)),c=claim.data();
    if(cleanup&&!claim.exists)return {doc,claim};
    if(doc.exists&&(!claim.exists||c.owner!==m.owner||c.path!==path||c.hash!==digest(doc.data())))throw Error(`Refusing unowned or modified Firestore document: ${path}`);
    if(claim.exists&&(c.owner!==m.owner||c.path!==path))throw Error('Resource ownership conflict.');
    if(!doc.exists&&claim.exists&&!c.deleted)throw Error(`Owned document was removed outside the seeder: ${path}`);
    return {doc,claim};
  }
  async function findAccount(profile){
    let byUid=null,byEmail=null;
    try{byUid=await auth.getUser(profile.uid);}catch(e){if(e.code!=='auth/user-not-found')throw e;}
    try{byEmail=await auth.getUserByEmail(profile.email);}catch(e){if(e.code!=='auth/user-not-found')throw e;}
    if(byEmail&&byEmail.uid!==profile.uid)return byEmail;
    return byUid??byEmail;
  }
  async function owned(m,p){const user=await findAccount(p);if(user&&!ownsAccount(user,p,m))throw Error(`Refusing unowned Auth account: ${p.uid}`);return user;}
  return {
    async claim(m,create){await store.runTransaction(async t=>{const ref=root(m),snap=await t.get(ref);if(snap.exists){const saved=snap.data();if(saved.owner!==m.owner||saved.version!==m.version||saved.anchor!==m.anchor||saved.viewport!==m.viewport||saved.project!==m.project)throw Error('Seed name belongs to a different or changed manifest.');}else if(create)t.create(ref,{owner:m.owner,version:m.version,anchor:m.anchor,viewport:m.viewport,project:m.project});else if(m.state!=='cleaning')throw Error('Remote ownership record missing.');});},
    checkDocument:(m,path,cleanup=false)=>store.runTransaction(async t=>(await check(t,m,path,cleanup)).claim.exists),findAccount,
    async ensureDocument(m,{path,data}){await store.runTransaction(async t=>{const {doc}=await check(t,m,path);if(doc.exists)return;t.create(store.doc(path),data);t.set(ledger(m,path),{owner:m.owner,path,hash:digest(data),deleted:false});});},
    async patchImage(m,path,patch){await store.runTransaction(async t=>{const {doc}=await check(t,m,path);if(!doc.exists)throw Error('Image target missing.');const data={...doc.data(),...patch};t.update(store.doc(path),patch);t.set(ledger(m,path),{owner:m.owner,path,hash:digest(data),deleted:false});});},
    async deleteDocument(m,path){await store.runTransaction(async t=>{const {doc,claim}=await check(t,m,path);if(!claim.exists)return;if(doc.exists)t.delete(store.doc(path));t.set(ledger(m,path),{...claim.data(),deleted:true});});},
    async checkDescendants(m,paths){const ownedPaths=new Set(paths);for(const path of paths){for(const col of await store.doc(path).listCollections()){for(const doc of (await col.get()).docs){if(!ownedPaths.has(doc.ref.path))throw Error(`Foreign child document blocks cleanup: ${doc.ref.path}`);}}}
      // Prevent removing a manager or reserved ID now referenced by a non-demo organization.
      const uids=paths.filter(p=>p.startsWith('users/')).map(p=>p.slice(6));
      for(let i=0;i<uids.length;i+=10)for(const doc of (await store.collection('organizations').where('managerUid','in',uids.slice(i,i+10)).get()).docs)if(!ownedPaths.has(doc.ref.path))throw Error('A non-demo organization references a demo manager.');
    },
    async ensureAccount(m,p){let user=await owned(m,p);if(!user){try{user=await auth.createUser({uid:p.uid,email:p.email,password:process.env.ORGLINK_DEMO_PASSWORD,displayName:marker(m),emailVerified:true,disabled:true});}catch(e){if(!['auth/uid-already-exists','auth/email-already-exists'].includes(e.code))throw e;user=await owned(m,p);if(!user)throw e;}}
      if(user.customClaims?.orglinkDemoOwner!==m.owner){await auth.setCustomUserClaims(p.uid,{...user.customClaims,orglinkDemoOwner:m.owner});}
      if(user.displayName!==p.fullName)await auth.updateUser(p.uid,{displayName:p.fullName});
    },
    async enableAccount(m,p){if(!await owned(m,p))throw Error('Demo account missing.');await auth.updateUser(p.uid,{disabled:!['active','pending'].includes(p.accountStatus)});},
    async deleteAccount(m,p){if(await owned(m,p))await auth.deleteUser(p.uid);},
    async release(m){const refs=(await root(m).collection('resources').get()).docs;for(const doc of refs){if(doc.data().owner!==m.owner||!doc.data().deleted)throw Error('Unfinished resources block ownership release.');await doc.ref.delete();}await root(m).delete();},
  };
}
