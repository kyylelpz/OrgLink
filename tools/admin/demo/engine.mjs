import {randomBytes} from 'node:crypto';
import {buildDataset,hash,VERSION} from './dataset.mjs';
import {validateAsset} from './images.mjs';

export function newManifest(options={}) {
  const plan=buildDataset(options);
  return {version:VERSION,project:'orglink-dev',seed:plan.seed,anchor:plan.anchor,viewport:plan.viewport,owner:randomBytes(32).toString('hex'),state:'planned',accounts:{},documents:{},assets:{},operations:[]};
}
export function manifestPlan(m) {
  if(m.version!==VERSION||m.project!=='orglink-dev'||!/^[a-f0-9]{64}$/.test(m.owner??'')||!['planned','applying','complete','cleaning','cleaned'].includes(m.state))throw Error('Invalid or unsupported demo manifest.');
  const plan=buildDataset(m),paths=new Set(plan.docs.map(d=>d.path)),uids=new Set(plan.users.map(u=>u.uid));
  if(Object.keys(m.documents).some(p=>!paths.has(p))||Object.keys(m.accounts).some(uid=>!uids.has(uid))||Object.keys(m.assets).some(p=>!plan.images.some(i=>i.path===p)))throw Error('Manifest contains resources outside this dataset.');
  for(const [path,asset] of Object.entries(m.assets))if(asset.publicId!==publicId(m,path)||asset.folder!==plan.images.find(i=>i.path===path).folder)throw Error('Manifest asset identity changed.');
  return plan;
}
export const publicId=(m,path)=>`${manifestFolder(path)}/${hash(`${m.owner}:${path}`)}`;
function manifestFolder(path){return path.startsWith('users/')?'orglink/profiles':path.includes('/events/')?'orglink/events':'orglink/organizations';}
export const marker=m=>`OrgLink Demo ${m.owner}`;
export function ownsAccount(user,profile,m){
  return user.uid===profile.uid&&user.email===profile.email&&
    (user.customClaims?.orglinkDemoOwner===m.owner||user.displayName===marker(m));
}
export async function execute({mode,manifest:m,backend,images,prepare,save=async()=>{},progress=()=>{}}) {
  if(!['apply','cleanup'].includes(mode))throw Error('Use apply or cleanup.');
  const plan=manifestPlan(m);
  if(m.state==='cleaned'){if(mode==='cleanup')return;throw Error('Use a new seed and manifest after cleanup.');}
  if(mode==='apply'&&m.state==='cleaning')throw Error('Finish cleanup before creating another seed.');
  const record=async(operation,path)=>{m.operations.push({operation,path,at:new Date().toISOString()});await save(m);progress(operation,path);};
  await backend.claim(m,mode==='apply');
  // Preflight the entire dataset before creating/deleting anything. Transactions repeat checks.
  const ownedDocs=[],ownedProfiles=[];
  for(const doc of plan.docs){if(await backend.checkDocument(m,doc.path,mode==='cleanup'))ownedDocs.push(doc);}
  for(const profile of plan.users){const user=await backend.findAccount(profile);if(user&&!ownsAccount(user,profile,m)){if(mode==='apply'||m.accounts[profile.uid]==='created')throw Error(`Refusing unrelated Auth account: ${profile.uid}`);}else if(user||m.accounts[profile.uid]==='created')ownedProfiles.push(profile);}
  if(mode==='cleanup') {
    await backend.checkDescendants(m,ownedDocs.map(d=>d.path));
    for(const [path,spec] of Object.entries(m.assets)){
      const asset=await images.inspect(spec.publicId);if(asset)validateAsset(asset,{...spec,owner:m.owner,cloud:images.cloud});
      // A partial upload intent is also owned and recoverable even if upload metadata was not saved.
      if(!plan.images.some(i=>i.path===path))throw Error('Unknown image resource.');
    }
    m.state='cleaning';await save(m);
    // Remove deepest children first. No recursive delete or collection-wide delete is used.
    for(const doc of [...ownedDocs].sort((a,b)=>b.path.split('/').length-a.path.split('/').length)){
      await backend.deleteDocument(m,doc.path);m.documents[doc.path]='deleted';await record('delete-document',doc.path);
    }
    for(const spec of Object.values(m.assets)){await images.destroy(spec,m.owner);spec.deleted=true;await record('delete-image',spec.publicId);}
    for(const profile of ownedProfiles){await backend.deleteAccount(m,profile);m.accounts[profile.uid]='deleted';await record('delete-account',profile.uid);}
    await backend.release(m);m.state='cleaned';await record('cleanup-complete',m.seed);return;
  }
  m.state='applying';await save(m);
  for(const profile of plan.users){await backend.ensureAccount(m,profile);m.accounts[profile.uid]='created';await record('account',profile.uid);}
  for(const doc of plan.docs){await backend.ensureDocument(m,doc);m.documents[doc.path]='created';await record('document',doc.path);}
  for(const image of plan.images){
    let spec=m.assets[image.path];
    if(!spec){spec=m.assets[image.path]={publicId:publicId(m,image.path),folder:image.folder,state:'intent'};await record('image-intent',image.path);}
    let asset=await images.inspect(spec.publicId);
    if(asset){validateAsset(asset,{...spec,owner:m.owner,cloud:images.cloud});if(!spec.metadata)throw Error('Image exists without preparation provenance. Restore the original manifest.');}
    else{
      const prepared=await prepare(image);
      // Persist licenses and the upload intent BEFORE the network write.
      spec.metadata=prepared.metadata;await save(m);
      asset=await images.upload(spec,prepared.buffer,m.owner);
      validateAsset(asset,{...spec,owner:m.owner,cloud:images.cloud});
    }
    spec.state='verified';spec.secureURL=asset.secure_url;spec.assetId=asset.asset_id;await save(m);
    await backend.patchImage(m,image.path,{[image.field]:asset.secure_url,[image.publicIdField]:spec.publicId,imageRevision:spec.publicId.split('/').at(-1),updatedAt:new Date(m.anchor)});
    spec.state='attached';await record('image',image.path);
  }
  for(const profile of plan.users)await backend.enableAccount(m,profile);
  m.state='complete';await record('apply-complete',m.seed);
}
