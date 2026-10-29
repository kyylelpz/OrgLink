import { AttendanceError } from './attendance.js';
import { Timestamp } from './firestore.js';
export const validStudentId = value => typeof value === 'string' && value.length === 10 && /^[0-9]{10}$/.test(value);
const fail = (code,message) => {throw new AttendanceError(code,message);};
export const matchingStudents = (t,sid) => t.query({from:[{collectionId:'users'}],where:{fieldFilter:{field:{fieldPath:'studentNumber'},op:'EQUAL',value:{stringValue:sid}}},limit:2});
export async function resolveStudentId(t,db,sid) {
  if(!validStudentId(sid))fail('invalid-argument','Enter a Student ID with exactly 10 numeric digits.');
  const [claim]=await t.getAll(db.doc(`studentIds/${sid}`));
  const mapping=claim.data();
  if(!mapping || mapping.state!=='active' || typeof mapping.uid!=='string' || !mapping.uid || mapping.uid.includes('/'))
    fail('failed-precondition','This Student ID has no active verified registry mapping. Contact the platform administrator.');
  const matches=await matchingStudents(t,sid);
  if(matches.length!==1 || matches[0].id!==mapping.uid || matches[0].uid!==mapping.uid)
    fail('failed-precondition','This Student ID mapping is ambiguous or stale and needs operator review.');
  const [profile]=await t.getAll(db.doc(`users/${mapping.uid}`));
  if(profile.data()?.studentNumber!==sid || profile.data()?.uid!==mapping.uid)
    fail('conflict','The student profile changed. Resolve the Student ID again.');
  return {uid:mapping.uid,profile:profile.data(),version:profile.updateTime,registryVersion:claim.updateTime};
}
const programs=['Civil','Computer','Electrical','Electronics','Industrial','Manufacturing','Mechanical','Mechatronics'].map(name=>`Bachelor of Science in ${name} Engineering`);
function validate(details) {
  const allowed=['fullName','studentNumber','yearLevel','section','college','program'];
  if(!details || typeof details!=='object' || Array.isArray(details) || Object.keys(details).some(k=>!allowed.includes(k)))fail('invalid-argument','Submit only student profile fields.');
  if(!validStudentId(details.studentNumber))fail('invalid-argument','Enter a Student ID with exactly 10 numeric digits.');
  if(typeof details.fullName!=='string' || details.fullName.trim().length<2 || details.fullName.trim().length>100
    || !Number.isInteger(details.yearLevel) || details.yearLevel<1 || details.yearLevel>6
    || typeof details.section!=='string' || !/^[A-Za-z0-9][A-Za-z0-9 -]{0,29}$/.test(details.section.trim())
    || details.college!=='College of Engineering' || !programs.includes(details.program))
    fail('invalid-argument','Complete all student details with valid information.');
  return {...details,fullName:details.fullName.trim(),section:details.section.trim()};
}
export function profileBackend(db,clock=Date.now) {
  return {save:async({auth,data})=>{
    if(!auth?.uid || typeof auth.email!=='string' || !auth.email.trim())fail('unauthenticated','Sign in again before saving your profile.');
    if(!data || Object.keys(data).some(k=>!['details'].includes(k)))fail('invalid-argument','Invalid profile request.');
    const details=validate(data.details),uid=auth.uid,sid=details.studentNumber;
    return db.runTransaction(async t=>{
      const profilePath=db.doc(`users/${uid}`),claimPath=db.doc(`studentIds/${sid}`);
      const [snapshot,claim]=await t.getAll(profilePath,claimPath);
      const current=snapshot.data(),reservation=claim.data();
      if(current && (current.uid!==uid || current.email!==auth.email))fail('permission-denied','Your profile identity needs operator review.');
      if(reservation && (reservation.uid!==uid || !['active','retired'].includes(reservation.state)))
        fail('already-exists','This Student ID is already registered. Check your ID or contact your school.');
      // This query protects legacy profiles awaiting backfill. The registry document is the atomic uniqueness lock.
      const matches=await matchingStudents(t,sid);
      if(matches.some(p=>p.id!==uid || p.uid!==uid) || matches.length>1)
        fail('already-exists','This Student ID is already registered. Check your ID or contact your school.');
      const old=current?.studentNumber;
      let oldClaim,oldMatches=[];
      if(validStudentId(old) && old!==sid) {
        [oldClaim]=await t.getAll(db.doc(`studentIds/${old}`));oldMatches=await matchingStudents(t,old);
        if(oldClaim.data() && oldClaim.data().uid!==uid)fail('failed-precondition','Your current Student ID mapping needs operator review before it can change.');
      }
      const now=Timestamp.fromMillis(clock());
      if(!reservation)t.create(claimPath,{uid,state:'active',createdAt:now,updatedAt:now},{serverTimestampFields:['createdAt','updatedAt']});
      else if(reservation.state!=='active')t.update(claimPath,{state:'active',updatedAt:now});
      if(oldClaim) {
        if(oldClaim.data())t.update(db.doc(`studentIds/${old}`),{state:'retired',updatedAt:now});
        else if(oldMatches.length===1 && oldMatches[0].id===uid)t.create(db.doc(`studentIds/${old}`),{uid,state:'retired',createdAt:now,updatedAt:now},{serverTimestampFields:['createdAt','updatedAt']});
      }
      if(current)t.update(profilePath,{...details,updatedAt:now});
      else t.create(profilePath,{...details,uid,email:auth.email,photoURL:typeof auth.photoURL==='string' && auth.photoURL.length<=2048?auth.photoURL:null,
        platformRole:'user',accountStatus:'pending',createdAt:now,updatedAt:now},{serverTimestampFields:['createdAt','updatedAt']});
      if(old!==sid)t.create(db.doc(`activityLogs/student-id-${crypto.randomUUID()}`),{actorUid:uid,operation:'claimStudentId',targetPath:`users/${uid}`,
        before:{studentNumber:typeof old==='string'?old:null},after:{studentNumber:sid},createdAt:now},{serverTimestampFields:['createdAt']});
      return {saved:true};
    });
  }};
}
