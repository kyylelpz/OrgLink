// Operator-only entry point. No invocation from Flutter or the public Worker.
import {resolve,relative,isAbsolute} from 'node:path';
import {pathToFileURL,fileURLToPath} from 'node:url';
import {createInterface} from 'node:readline/promises';
import {completeProfile,validId} from '../../workers/attendance/src/admin.js';
export async function provisionAdministrator({auth,store,uid,email,confirm,timestamp}) {
  if (!validId(uid) || typeof email !== 'string' || !email.includes('@')) throw Error('Supply the independently verified UID and email.');
  async function verify() {
    const byUid = await auth.getUser(uid), byEmail = await auth.getUserByEmail(email);
    if (byEmail.uid !== uid || byUid.uid !== uid || byUid.email?.toLowerCase() !== email.toLowerCase()
      || !byUid.emailVerified || byUid.disabled) throw Error('Auth UID/email must match an enabled verified account.');
    return byUid;
  }
  await verify();
  const ref=store.doc(`users/${uid}`), snapshot=await ref.get(), profile=snapshot.data();
  function allowed(p) {
    if (p?.uid !== uid || p.email?.toLowerCase() !== email.toLowerCase() || !completeProfile(p)
      || !['user','platformAdmin'].includes(p.platformRole) || !['pending','active'].includes(p.accountStatus))
      throw Error('Complete the matching student profile first. Suspended/disabled/rejected or unknown accounts require separate review.');
  }
  allowed(profile);
  const plan={uid,email,fromRole:profile.platformRole,fromStatus:profile.accountStatus,
    toRole:'platformAdmin',toStatus:'active',project:'orglink-dev'};
  // A dry run verifies identity and prints the plan, but never grants privileges.
  if (!await confirm(plan)) return {applied:false,plan};
  await verify();
  return store.runTransaction(async t=>{
    const current=await t.get(ref); const value=current.data(); allowed(value);
    if (value.platformRole==='platformAdmin' && value.accountStatus==='active') return {applied:false,alreadyProvisioned:true};
    if (!current.updateTime.isEqual(snapshot.updateTime)) throw Error('Profile changed after confirmation. Review and run again.');
    t.update(ref,{platformRole:'platformAdmin',accountStatus:'active',updatedAt:timestamp()});
    t.create(store.doc(`activityLogs/provision-platform-admin-${uid}`),{
      source:'operator-provisioning',actorUid:null,operation:'provisionPlatformAdmin',targetPath:`users/${uid}`,
      before:{platformRole:value.platformRole,accountStatus:value.accountStatus},
      after:{platformRole:'platformAdmin',accountStatus:'active'},createdAt:timestamp(),
    });
    return {applied:true,uid};
  });
}
export async function main(args=process.argv.slice(2)) {
  const option=key=>{const i=args.indexOf(key); return i<0?undefined:args[i+1];};
  if (option('--project') !== 'orglink-dev') throw Error('Only --project orglink-dev is supported.');
  if (process.env.FIRESTORE_EMULATOR_HOST || process.env.FIREBASE_AUTH_EMULATOR_HOST)
    throw Error('Unset emulator environment variables. This operator command verifies the existing development Auth identity.');
  const uid=option('--uid'),email=option('--email');
  if (!validId(uid) || !email) throw Error('Supply --uid and --email.');
  const workspace=resolve(fileURLToPath(new URL('../..',import.meta.url)));
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    const location=relative(workspace,resolve(process.env.GOOGLE_APPLICATION_CREDENTIALS));
    if (!location.startsWith('..') && !isAbsolute(location)) throw Error('Administrative credentials must be outside the repository.');
  }
  const {initializeApp,applicationDefault,deleteApp}=await import('firebase-admin/app');
  const {getFirestore,FieldValue}=await import('firebase-admin/firestore');
  const {getAuth}=await import('firebase-admin/auth');
  const app=initializeApp({projectId:'orglink-dev',credential:applicationDefault()});
  try {
    const result=await provisionAdministrator({auth:getAuth(app),store:getFirestore(app),uid,email,timestamp:()=>FieldValue.serverTimestamp(),
      confirm:async plan=>{
        console.log(JSON.stringify(plan,null,2));
        if (!args.includes('--apply')) { console.log('DRY RUN: no writes.'); return false; }
        if (!process.stdin.isTTY) throw Error('--apply requires interactive operator confirmation.');
        const prompt=createInterface({input:process.stdin,output:process.stdout});
        try { return (await prompt.question(`Type GRANT platformAdmin TO ${uid} AND ACTIVATE to confirm: `))===`GRANT platformAdmin TO ${uid} AND ACTIVATE`; }
        finally { prompt.close(); }
      }});
    console.log(JSON.stringify(result));
  } finally { await deleteApp(app); }
}
if(process.argv[1] && import.meta.url===pathToFileURL(resolve(process.argv[1])).href)
  main().catch(()=>{console.error('Provisioning failed. Verify credentials, identity, profile and concurrent changes; no secret details are logged.');process.exitCode=1;});
