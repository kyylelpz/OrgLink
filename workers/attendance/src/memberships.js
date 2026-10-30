import {AttendanceError} from './attendance.js';
import {completeProfile,validId} from './admin.js';
import {Timestamp} from './firestore.js';
const fail=(code,message)=>{throw new AttendanceError(code,message);};
const keys=['manageEvents','manageAttendance','viewRoster'];
const canonical=v=>v&&typeof v==='object'&&!Array.isArray(v)?Object.fromEntries(Object.keys(v).sort().map(k=>[k,canonical(v[k])])):v;
const context=d=>{
  if(!validId(d?.organizationId)||!validId(d?.participantUid))fail('invalid-argument','Choose a valid organization and member.');
  return `organizations/${d.organizationId}/memberships/${d.participantUid}`;
};
const snapshot=m=>Object.fromEntries(['membershipStatus','membershipRole','positionTitle','permissions','requestedAt','joinedAt','reviewedAt','reviewedBy','endedAt','endedBy','endReason'].map(k=>[k,m[k]??null]));
export function membershipBackend(db,clock=Date.now){
  async function read(t,auth,data){
    if(!validId(auth?.uid))fail('unauthenticated','Sign in again.');
    const path=context(data);
    const [actor,organization,member]=await t.getAll(db.doc(`users/${auth.uid}`),db.doc(`organizations/${data.organizationId}`),db.doc(path));
    const p=actor.data(),org=organization.data();
    if(p?.uid!==auth.uid||p.accountStatus!=='active'||!completeProfile(p)||org?.status!=='active'||org.managerUid!==auth.uid)
      fail('permission-denied','Only the active assigned organization manager can manage memberships.');
    return {path,member,org};
  }
  return {
    async preview({auth,data}){
      if(Object.keys(data??{}).some(k=>!['organizationId','participantUid'].includes(k)))fail('invalid-argument','Unexpected membership fields.');
      return db.runTransaction(async t=>{
        const {member}=await read(t,auth,data),m=member.data();
        if(!m||m.uid!==data.participantUid||m.organizationId!==data.organizationId)fail('not-found','Membership not found.');
        const result=Object.fromEntries(['uid','organizationId','membershipRole','membershipStatus','positionTitle','permissions','applicantName','reviewedBy','endedBy','endReason'].map(k=>[k,m[k]??null]));
        for(const k of ['requestedAt','joinedAt','updatedAt','reviewedAt','endedAt'])result[k]=m[k]?.toMillis?.()??m[k]?.milliseconds??null;
        return {version:member.updateTime,membership:result};
      });
    },
    async mutate({auth,data}){
      context(data);
      const allowed=['organizationId','participantUid','operation','version','requestId'];
      if(data.operation==='end')allowed.push('reason');
      if(data.operation==='role')allowed.push('role','positionTitle');
      if(data.operation==='permissions')allowed.push('permissions');
      if(!['end','role','permissions'].includes(data.operation)||Object.keys(data).some(k=>!allowed.includes(k))||
        typeof data.version!=='string'||!data.version||data.version.length>128||!/^[-a-zA-Z0-9_]{16,80}$/.test(data.requestId??''))fail('invalid-argument','Refresh the roster and review valid membership changes.');
      let patch={};
      if(data.operation==='end'){
        if(typeof (data.reason??'')!=='string'||(data.reason??'').length>1000)fail('invalid-argument','Use an optional reason of at most 1000 characters.');
        patch={membershipStatus:'removed',permissions:{},endedBy:auth?.uid,endReason:(data.reason??'').trim()};
      } else if(data.operation==='role'){
        if(!['member','officer'].includes(data.role)||data.role==='officer'&&(typeof data.positionTitle!=='string'||!data.positionTitle.trim()||data.positionTitle.length>100)||data.role==='member'&&data.positionTitle!=null)
          fail('invalid-argument','Choose Member or Officer and a valid officer position.');
        patch={membershipRole:data.role,positionTitle:data.role==='officer'?data.positionTitle.trim():null};
      } else {
        if(!data.permissions||typeof data.permissions!=='object'||Array.isArray(data.permissions)||Object.keys(data.permissions).some(k=>!keys.includes(k))||Object.values(data.permissions).some(v=>typeof v!=='boolean'))
          fail('invalid-argument','Choose only supported officer permissions.');
        patch={permissions:Object.fromEntries(keys.map(k=>[k,data.permissions[k]===true]))};
      }
      return db.runTransaction(async t=>{
        const {path,member,org}=await read(t,auth,data);
        const auditPath=db.doc(`organizations/${data.organizationId}/membershipAudits/${auth.uid}-${data.requestId}`);
        const [previous]=await t.getAll(auditPath);
        const request=canonical(data);
        if(previous.data()){if(JSON.stringify(canonical(previous.data().request))!==JSON.stringify(request))fail('conflict','This request ID was already used for another change.');return {saved:true,duplicate:true};}
        const m=member.data();
        if(!m||m.uid!==data.participantUid||m.organizationId!==data.organizationId)fail('not-found','Membership not found.');
        if(data.participantUid===auth.uid||data.participantUid===org.managerUid||m.membershipRole==='manager')fail('permission-denied','Manager memberships and your own membership cannot be changed here.');
        if(member.updateTime!==data.version)fail('conflict','This membership changed. Close the dialog, refresh and review again.');
        if(m.membershipStatus!=='active')fail('failed-precondition','Only active memberships can be changed.');
        if(data.operation==='permissions'&&m.membershipRole!=='officer')fail('failed-precondition','Assign the Officer role before granting capabilities.');
        if(data.operation==='role')patch.permissions=data.role==='member'?{}:Object.fromEntries(keys.map(k=>[k,m.membershipRole==='officer'&&m.permissions?.[k]===true]));
        const now=Timestamp.fromMillis(clock());
        if(data.operation==='end')patch.endedAt=now;
        t.update(db.doc(path),{...patch,updatedAt:now});
        t.create(auditPath,{organizationId:data.organizationId,participantUid:data.participantUid,actorUid:auth.uid,operation:data.operation,requestId:data.requestId,request,before:snapshot(m),after:snapshot({...m,...patch}),createdAt:now});
        return {saved:true,duplicate:false};
      });
    },
  };
}
