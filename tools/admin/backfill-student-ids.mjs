// Operator-only audit/backfill. Never rewrites users, UIDs or assigned Student IDs.
import {resolve,relative,isAbsolute} from 'node:path';
import {pathToFileURL,fileURLToPath} from 'node:url';
import {createInterface} from 'node:readline/promises';
import {validStudentId} from '../../workers/attendance/src/student_ids.js';
export function analyzeStudentIds(profiles,registry=[]) {
  const missing=[],invalid=[],duplicates=[],identityMismatches=[],candidates=[],groups=new Map();
  for(const p of profiles) {
    if(p.uid!==p.id){identityMismatches.push({uid:p.id});continue;}
    if(p.studentNumber===undefined || p.studentNumber===null || p.studentNumber===''){missing.push({uid:p.id});continue;}
    if(!validStudentId(p.studentNumber)){invalid.push({uid:p.id,value:p.studentNumber});continue;}
    const owners=groups.get(p.studentNumber)??[];owners.push(p);groups.set(p.studentNumber,owners);
  }
  for(const [studentId,owners] of groups) {
    if(owners.length!==1)duplicates.push({studentId,uids:owners.map(p=>p.id).sort()});
    else candidates.push({uid:owners[0].id,studentId,email:owners[0].email});
  }
  const mappings=new Map(registry.map(r=>[r.id,r]));
  const unclaimed=[],registryConflicts=[],staleRegistry=[];
  for(const c of candidates) {
    const r=mappings.get(c.studentId);
    if(!r)unclaimed.push({uid:c.uid,studentId:c.studentId});
    else if(r.uid!==c.uid || r.state!=='active')registryConflicts.push({uid:c.uid,studentId:c.studentId,state:r.state,ownerUid:r.uid});
  }
  const users=new Map(profiles.map(p=>[p.id,p]));
  for(const r of registry)if(!validStudentId(r.id) || !['active','retired'].includes(r.state)
    || (r.state==='active' && (users.get(r.uid)?.studentNumber!==r.id || users.get(r.uid)?.uid!==r.uid)))staleRegistry.push({studentId:r.id,uid:r.uid,state:r.state});
  return {missing,invalid,duplicates,identityMismatches,unclaimed,registryConflicts,staleRegistry,candidates};
}
export async function claimExistingStudentId({store,auth,candidate,timestamp}) {
  const {uid,studentId}=candidate;
  if(!validStudentId(studentId) || !uid || uid.includes('/'))throw Error('invalid-candidate');
  const identity=await auth.getUser(uid);
  if(identity.uid!==uid || typeof candidate.email!=='string' || identity.email?.toLowerCase()!==candidate.email.toLowerCase())throw Error('auth-identity-mismatch');
  return store.runTransaction(async t=>{
    const ref=store.doc(`users/${uid}`),registry=store.doc(`studentIds/${studentId}`);
    const [profile,claim]=await t.getAll(ref,registry);
    const matches=await t.get(store.collection('users').where('studentNumber','==',studentId).limit(2));
    if(profile.data()?.uid!==uid || profile.data()?.studentNumber!==studentId || profile.data()?.email!==candidate.email)throw Error('profile-changed');
    if(matches.docs.length!==1 || matches.docs[0].id!==uid)throw Error('duplicate-or-stale-profile');
    if(claim.exists) {
      if(claim.data().uid!==uid || claim.data().state!=='active')throw Error('registry-conflict');
      return {uid,studentId,result:'unchanged'};
    }
    t.create(registry,{uid,state:'active',createdAt:timestamp(),updatedAt:timestamp()});
    return {uid,studentId,result:'claimed'};
  });
}
async function all(collection,documentId) {
  const rows=[];let last;
  while(true) {
    let q=collection.orderBy(documentId).limit(200);if(last)q=q.startAfter(last);
    const page=await q.get();for(const d of page.docs)rows.push({...d.data(),id:d.id});
    if(page.size<200)break;last=page.docs.at(-1);
  }
  return rows;
}
export async function main(args=process.argv.slice(2)) {
  const option=key=>{const i=args.indexOf(key);return i<0?undefined:args[i+1];};
  if(option('--project')!=='orglink-dev')throw Error('Only --project orglink-dev is supported.');
  if(process.env.FIRESTORE_EMULATOR_HOST || process.env.FIREBASE_AUTH_EMULATOR_HOST)throw Error('Unset emulator variables for the operator audit. Tests use injected local stores.');
  const workspace=resolve(fileURLToPath(new URL('../..',import.meta.url)));
  if(process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    const location=relative(workspace,resolve(process.env.GOOGLE_APPLICATION_CREDENTIALS));
    if(!location.startsWith('..')&&!isAbsolute(location))throw Error('Keep Admin credentials outside the repository.');
  }
  const {initializeApp,applicationDefault,deleteApp}=await import('firebase-admin/app');
  const {getFirestore,FieldPath,FieldValue}=await import('firebase-admin/firestore');
  const {getAuth}=await import('firebase-admin/auth');
  const app=initializeApp({projectId:'orglink-dev',credential:applicationDefault()});
  try {
    const store=getFirestore(app),auth=getAuth(app),profiles=await all(store.collection('users'),FieldPath.documentId()),registry=await all(store.collection('studentIds'),FieldPath.documentId());
    const report=analyzeStudentIds(profiles,registry);
    console.log(JSON.stringify({profiles:profiles.length,registry:registry.length,...report,candidates:report.candidates.map(({uid,studentId})=>({uid,studentId}))},null,2));
    if(args.includes('--apply')) {
      if(!process.stdin.isTTY)throw Error('Apply requires interactive confirmation.');
      const prompt=createInterface({input:process.stdin,output:process.stdout});let confirmed;
      try{confirmed=(await prompt.question('Confirm direct ID writes are frozen. Type BACKFILL STUDENT IDS IN orglink-dev: '))==='BACKFILL STUDENT IDS IN orglink-dev';}finally{prompt.close();}
      if(!confirmed){console.log('Cancelled: no mappings written.');return;}
      const outcomes=[];
      for(const candidate of report.candidates) {
        try{outcomes.push(await claimExistingStudentId({store,auth,candidate,timestamp:()=>FieldValue.serverTimestamp()}));}
        catch{outcomes.push({uid:candidate.uid,studentId:candidate.studentId,result:'needs-manual-review'});}
      }
      console.log(JSON.stringify({outcomes},null,2));
    }else console.log('READ ONLY: no profile or registry writes. Correct conflicts using verified BulSU records, never generated IDs.');
    if(args.includes('--verify') && ['missing','invalid','duplicates','identityMismatches','unclaimed','registryConflicts','staleRegistry'].some(k=>report[k].length))process.exitCode=2;
  }finally{await deleteApp(app);}
}
if(process.argv[1]&&import.meta.url===pathToFileURL(resolve(process.argv[1])).href)main().catch(()=>{console.error('Student ID audit/backfill failed. Check project, credentials, confirmation and registry conflicts. No secret details are logged.');process.exitCode=1;});
