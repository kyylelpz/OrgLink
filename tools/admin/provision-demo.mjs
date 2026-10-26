import {resolve,relative,isAbsolute} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';

export function buildPlan(managerUid) {
  if(typeof managerUid!=='string' || !managerUid.trim() || managerUid.includes('/') || managerUid.length>128) throw new Error('Supply a valid demo manager UID.');
  return [
    ['demo-robotics','Demo Robotics Society','public','active'],
    ['demo-creatives','Demo Creative Guild','public','active'],
    ['demo-private','Demo Private Committee','private','active'],
    ['demo-inactive','Demo Archived Society','public','inactive'],
  ].map(([id,name,visibility,status])=>({organizationId:id,name,visibility,status,managerUid,
    description:'Synthetic organization for the OrgLink academic demonstration. No real student records are included.',
    logoURL:null,mission:'Learn together through demonstration projects.',vision:'An inclusive demonstration community.',
    goals:['Practice collaboration','Share technical and creative skills'],membershipRequirements:['Complete your OrgLink student profile'],
    approvalSettings:{acceptsRequests:status==='active' && visibility==='public',mode:'manual'},
    positions:['President','Vice President','Secretary','Committee Head','General Member'],
    publicOfficers:[{name:'Demo President',positionTitle:'President'}]}));
}
export async function main(args=process.argv.slice(2)) {
  const option=(key)=>{const index=args.indexOf(key);return index<0?undefined:args[index+1];};
  if(option('--project')!=='orglink-dev') throw new Error('This procedure supports only --project orglink-dev.');
  const managerUid=option('--manager-uid'); const plan=buildPlan(managerUid);
  if(!args.includes('--apply')) {
    console.log('DRY RUN. No Firebase calls or writes. Proposed synthetic organizations:');
    console.log(JSON.stringify(plan,null,2));return;
  }
  if(!args.includes('--confirm-demo-manager')) throw new Error('Confirm that the supplied UID is an authorized demonstration manager using --confirm-demo-manager.');
  const workspace=resolve(fileURLToPath(new URL('../..',import.meta.url)));
  if(process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    const location=relative(workspace,resolve(process.env.GOOGLE_APPLICATION_CREDENTIALS));
    if(!location.startsWith('..') && !isAbsolute(location)) throw new Error('Administrative credential files must be outside the repository.');
  }
  const emulator=args.includes('--emulator');
  if(emulator && !/^(127\.0\.0\.1|localhost):\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST??'')) throw new Error('--emulator requires a loopback FIRESTORE_EMULATOR_HOST.');
  if(!emulator && (process.env.FIRESTORE_EMULATOR_HOST || process.env.FIREBASE_AUTH_EMULATOR_HOST)) throw new Error('Unset emulator variables or explicitly use --emulator.');
  const {initializeApp,applicationDefault,deleteApp}=await import('firebase-admin/app');
  const {getFirestore,FieldValue}=await import('firebase-admin/firestore');
  const {getAuth}=await import('firebase-admin/auth');
  const app=initializeApp(emulator?{projectId:'orglink-dev'}:{projectId:'orglink-dev',credential:applicationDefault()});
  try {
    if(!emulator) await getAuth(app).getUser(managerUid);
    const store=getFirestore(app);
    await store.runTransaction(async transaction=>{
      const user=await transaction.get(store.doc(`users/${managerUid}`));
      if(!user.exists || user.data().accountStatus!=='active' || !user.data().fullName || !/^[A-Za-z0-9][A-Za-z0-9-]{2,29}$/.test(user.data().studentNumber??'') || !Number.isInteger(user.data().yearLevel) || user.data().yearLevel<1 || user.data().yearLevel>6 || !/^[A-Za-z0-9][A-Za-z0-9 -]{0,29}$/.test(user.data().section??'')) throw new Error('Complete Module 1 with an active synthetic demo profile before provisioning.');
      const refs=plan.flatMap(org=>[store.doc(`organizations/${org.organizationId}`),store.doc(`organizations/${org.organizationId}/memberships/${managerUid}`)]);
      const snapshots=await transaction.getAll(...refs);
      for(let index=0;index<plan.length;index++) {
        const org=plan[index],existing=snapshots[index*2];
        if(existing.exists && existing.data().managerUid!==managerUid) throw new Error('Existing sample organization has another manager. No manager transfer was performed.');
        if(!existing.exists) transaction.create(refs[index*2],{...org,createdAt:FieldValue.serverTimestamp(),updatedAt:FieldValue.serverTimestamp()});
        if(!snapshots[index*2+1].exists) transaction.create(refs[index*2+1],{uid:managerUid,organizationId:org.organizationId,
          membershipRole:'manager',membershipStatus:'active',positionTitle:'Organization Manager',permissions:{viewRoster:true},
          applicantName:'Demo Organization Manager',requestedAt:null,joinedAt:FieldValue.serverTimestamp(),
          updatedAt:FieldValue.serverTimestamp(),reviewedAt:null,reviewedBy:null});
      }
    });
    console.log('Synthetic organizations provisioned. Existing data was preserved. No platform roles were changed.');
  } finally { await deleteApp(app); }
}
if(process.argv[1] && import.meta.url===pathToFileURL(resolve(process.argv[1])).href) {
  main().catch(error=>{console.error(error.message);process.exitCode=1;});
}
