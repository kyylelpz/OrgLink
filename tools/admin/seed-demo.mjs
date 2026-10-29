// Development operator CLI. Merely importing this module performs no I/O.
import {readFile,writeFile,mkdir,rename,open,unlink} from 'node:fs/promises';
import {resolve,dirname,relative,isAbsolute,join} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {buildDataset,summary} from './demo/dataset.mjs';
import {newManifest,manifestPlan,execute} from './demo/engine.mjs';
import {cloudinaryClient,prepareImage,LICENSES} from './demo/images.mjs';
import {firebaseBackend} from './demo/firebase.mjs';

export function parseArgs(args){
  const [mode,...rest]=args,options={mode};
  if(!['dry-run','apply','cleanup'].includes(mode))throw Error('Choose dry-run, apply or cleanup.');
  const allowed=new Set(['project','confirm-project','seed','manifest','now','viewport']);
  for(let i=0;i<rest.length;i+=2){const key=rest[i]?.replace(/^--/,'');if(!rest[i]?.startsWith('--')||!allowed.has(key)||options[key]!==undefined||!rest[i+1]||rest[i+1].startsWith('--'))throw Error('Invalid or duplicate command option.');options[key]=rest[i+1];}
  if(options.project!=='orglink-dev')throw Error('Only --project orglink-dev is supported.');
  if(mode!=='dry-run'&&options['confirm-project']!=='orglink-dev')throw Error('Writes require --confirm-project orglink-dev.');
  if(mode==='cleanup'&&!options.manifest)throw Error('Cleanup requires the original --manifest.');
  options.seed??='campus-demo';if(options.viewport!==undefined)options.viewport=Number(options.viewport);
  buildDataset({seed:options.seed,anchor:options.now,viewport:options.viewport});return options;
}
export async function main(args=process.argv.slice(2)){
  const o=parseArgs(args),workspace=resolve(fileURLToPath(new URL('../..',import.meta.url)));
  const manifestPath=resolve(o.manifest??join(workspace,'.orglink-demo',`${o.seed}.json`));
  let m;try{m=JSON.parse(await readFile(manifestPath,'utf8'));manifestPlan(m);if(m.seed!==o.seed)throw Error('Use the seed name recorded in the manifest.');if(o.now&&new Date(o.now).toISOString()!==m.anchor||o.viewport!==undefined&&o.viewport!==m.viewport)throw Error('An existing manifest freezes its original date and dimensions.');}catch(e){if(e.code!=='ENOENT')throw e;if(o.mode==='cleanup')throw Error('Cleanup needs an existing manifest.');m=newManifest({seed:o.seed,anchor:o.now,viewport:o.viewport});}
  const plan=manifestPlan(m);
  if(o.mode==='dry-run'){
    console.log(JSON.stringify({mode:'dry-run',externalWrites:false,summary:summary(plan),accounts:plan.users,organizations:plan.organizations,events:plan.events,memberships:plan.docs.filter(d=>d.path.includes('/memberships/')),registrations:plan.docs.filter(d=>d.path.includes('/registrations/')),attendance:plan.docs.filter(d=>d.path.includes('/attendance/')),images:plan.images.map(i=>({...i,source:i.folder.endsWith('profiles')?'Original synthetic avatar':`https://raw.githubusercontent.com/lucide-icons/lucide/0.468.0/icons/${i.icon}.svg`,licenses:i.folder.endsWith('profiles')?['CC0-1.0']:LICENSES.map(l=>l.spdx)}))},null,2));return;
  }
  if(process.env.FIRESTORE_EMULATOR_HOST||process.env.FIREBASE_AUTH_EMULATOR_HOST)throw Error('This development-project CLI does not accept emulator environment variables. Unit tests use injected adapters.');
  if(o.mode==='apply'&&(typeof process.env.ORGLINK_DEMO_PASSWORD!=='string'||process.env.ORGLINK_DEMO_PASSWORD.length<12))throw Error('Set ORGLINK_DEMO_PASSWORD to at least 12 characters; it is never printed or saved.');
  if(process.env.GOOGLE_APPLICATION_CREDENTIALS){const path=resolve(process.env.GOOGLE_APPLICATION_CREDENTIALS),location=relative(workspace,path);if(!location.startsWith('..')&&!isAbsolute(location))throw Error('Keep administrative credential files outside the repository.');const credential=JSON.parse(await readFile(path,'utf8'));if(credential.project_id!=='orglink-dev')throw Error('Use credentials for the configured development project only.');}
  const images=cloudinaryClient(process.env);
  await mkdir(dirname(manifestPath),{recursive:true});
  // Exclusive process lock; a crash leaves it in place intentionally (see recovery docs).
  const lockPath=`${manifestPath}.lock`,lock=await open(lockPath,'wx',0o600);
  let app;
  try{
    // Re-read under lock: another invocation may have completed after the initial read.
    try{const latest=JSON.parse(await readFile(manifestPath,'utf8'));if(latest.owner!==m.owner||JSON.stringify(latest)!==JSON.stringify(m))throw Error('Manifest changed; rerun the command.');}catch(e){if(e.code!=='ENOENT')throw e;}
    const save=async value=>{const temporary=`${manifestPath}.tmp`;await writeFile(temporary,JSON.stringify(value,null,2)+'\n',{mode:0o600});await rename(temporary,manifestPath);};
    await save(m);
    const {initializeApp,applicationDefault,deleteApp}=await import('firebase-admin/app');
    const {getFirestore}=await import('firebase-admin/firestore'),{getAuth}=await import('firebase-admin/auth');
    app=initializeApp({projectId:'orglink-dev',credential:applicationDefault()},`demo-${m.owner.slice(0,12)}`);
    try{let count=0;await execute({mode:o.mode,manifest:m,backend:firebaseBackend({store:getFirestore(app),auth:getAuth(app)}),images,prepare:spec=>prepareImage(spec,{cache:join(dirname(manifestPath),'cache')}),save,progress:operation=>{if(++count%20===0||operation.endsWith('complete'))console.log(`${count} operations checkpointed (${operation}).`);}});}finally{await deleteApp(app);app=null;}
    console.log(`${o.mode} finished for ${m.seed}. Manifest: ${manifestPath}`);
  }finally{await lock.close();await unlink(lockPath);}
}
if(process.argv[1]&&import.meta.url===pathToFileURL(resolve(process.argv[1])).href)main().catch(()=>{console.error('Seeder stopped. No secrets or provider response bodies are logged. Check the project confirmation, configuration, manifest/lock and troubleshooting guide in docs/demo-seeder.md; completed operations remain checkpointed.');process.exitCode=1;});
