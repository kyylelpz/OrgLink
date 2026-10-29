import { validStudentId, resolveStudentId } from './student_ids.js';
// Platform operations use the existing trusted Firestore transport, never client role claims.
import { AttendanceError } from './attendance.js';
import { Timestamp } from './firestore.js';
const fail = (code, message) => { throw new AttendanceError(code, message); };
const invalid = () => fail('invalid-argument', 'Check the submitted administration details.');
export const validId = value => typeof value === 'string' && value.length > 0 && value.length <= 128
  && !value.includes('/') && !['.', '..'].includes(value) && !/[\u0000-\u001f]/.test(value);
export function completeProfile(p) {
  return typeof p?.email === 'string' && p.email.trim().length > 0 && typeof p.fullName === 'string' && p.fullName.trim().length >= 2 && p.fullName.length <= 100
    && typeof p.studentNumber === 'string' && /^[A-Za-z0-9][A-Za-z0-9-]{2,29}$/.test(p.studentNumber)
    && Number.isInteger(p.yearLevel) && p.yearLevel >= 1 && p.yearLevel <= 6
    && typeof p.section === 'string' && /^[A-Za-z0-9][A-Za-z0-9 -]{0,29}$/.test(p.section);
}
function admin(profile, uid) {
  if (profile?.uid !== uid || profile.platformRole !== 'platformAdmin'
    || profile.accountStatus !== 'active' || !completeProfile(profile)) {
    fail('permission-denied', 'Platform administrator access is required.');
  }
}
function fields(value, allowed) {
  if (!value || typeof value !== 'object' || Array.isArray(value)
    || Object.keys(value).some(key => !allowed.includes(key))) invalid();
}
function text(value, max, required = false) {
  if (typeof value !== 'string' || value.length > max || /[\u0000-\u0008\u000b\u000c\u000e-\u001f]/.test(value)
    || (required && value.trim().length < 2)) invalid();
  return value.trim();
}
function organizationInput(input, creating) {
  fields(input, ['name','description','logoURL','mission','vision','goals','membershipRequirements',
    'visibility','status','managerStudentId','managerProfileVersion','managerRegistryVersion','acceptsRequests']);
  const patch = {};
  for (const [key,max] of [['name',100],['description',1500],['mission',1000],['vision',1000]]) {
    if (key in input) patch[key] = text(input[key],max,key === 'name');
  }
  for (const key of ['goals','membershipRequirements']) {
    if (key in input) {
      if (!Array.isArray(input[key]) || input[key].length > 10) invalid();
      patch[key] = input[key].map(item => text(item,120,true));
    }
  }
  if ('logoURL' in input && input.logoURL != null && input.logoURL !== '') invalid();
  for (const [key,options] of [['visibility',['public','private']],['status',['active','inactive']]]) {
    if (key in input) {
      if (!options.includes(input[key])) invalid();
      patch[key] = input[key];
    }
  }
  if ('managerStudentId' in input) {
    if (!validStudentId(input.managerStudentId)) fail('invalid-argument','Enter a manager Student ID with exactly 10 numeric digits.');
    for(const key of ['managerStudentId','managerProfileVersion','managerRegistryVersion']) {
      if(typeof input[key]!=='string' || !input[key] || input[key].length>128) fail('failed-precondition','Resolve and review the manager Student ID before saving.');
      patch[key]=input[key];
    }
  } else if ('managerProfileVersion' in input || 'managerRegistryVersion' in input) invalid();
  if ('acceptsRequests' in input) {
    if (typeof input.acceptsRequests !== 'boolean') invalid();
    patch.acceptsRequests = input.acceptsRequests;
  }
  if (creating && (!patch.name || !patch.managerStudentId || !patch.visibility || !patch.status)) invalid();
  if (!Object.keys(patch).length) invalid();
  return patch;
}
const versionMatches = (snapshot, version) => {
  if (typeof version !== 'string' || !version || snapshot.updateTime !== version)
    fail('conflict', 'This record changed. Refresh and review it before saving again.');
};
function canonical(value) {
  if (Array.isArray(value)) return value.map(canonical);
  if (value && typeof value === 'object') return Object.fromEntries(Object.keys(value).sort().map(k => [k,canonical(value[k])]));
  return value;
}
export function adminBackend(db, clock = Date.now) {
  const userPath = uid => db.doc(`users/${uid}`);
  async function read(uid, action) {
    return db.runTransaction(async t => {
      const [actor] = await t.getAll(userPath(uid)); admin(actor.data(),uid);
      return action(t);
    });
  }
  return {
    stats: ({auth}) => read(auth.uid, async t => ({
      users: await t.count({from:[{collectionId:'users'}]}),
      pending: await t.count({from:[{collectionId:'users'}],where:{fieldFilter:{field:{fieldPath:'accountStatus'},op:'EQUAL',value:{stringValue:'pending'}}}}),
      organizations: await t.count({from:[{collectionId:'organizations'}]}),
    })),
    manager: ({auth,data}) => read(auth.uid, async t => {
      fields(data,['studentId']);
      const matched=await resolveStudentId(t,db,data.studentId);
      const p=matched.profile;
      return {studentId:data.studentId,name:p.fullName,status:p.accountStatus,
        eligible:p.accountStatus==='active' && completeProfile(p) && ['user','platformAdmin'].includes(p.platformRole),
        version:matched.version,registryVersion:matched.registryVersion};
    }),
    list: ({auth,data}) => read(auth.uid, async t => {
      fields(data,['collection','field','search','cursor']);
      const collection = data.collection;
      const allowed = collection === 'users' ? ['fullName','email','studentNumber','__name__'] : collection === 'organizations' ? ['name','__name__'] : [];
      const field = data.field ?? allowed[0], search = data.search ?? '';
      if (!allowed.includes(field) || typeof search !== 'string' || search.length > 128) invalid();
      const query = {from:[{collectionId:collection}],orderBy:[{field:{fieldPath:field},direction:'ASCENDING'}],limit:26};
      if (field !== '__name__') query.orderBy.push({field:{fieldPath:'__name__'},direction:'ASCENDING'});
      if (search) {
        if (field === '__name__') {
          if (!validId(search)) invalid();
          query.where = {fieldFilter:{field:{fieldPath:field},op:'EQUAL',value:{referenceValue:db.doc(`${collection}/${search}`)}}};
        } else if (field === 'email' || field === 'studentNumber') {
          if(field==='studentNumber' && !validStudentId(search)) fail('invalid-argument','Enter exactly 10 numeric digits for Student ID search.');
          query.where = {fieldFilter:{field:{fieldPath:field},op:'EQUAL',value:{stringValue:search}}};
        } else {
          query.where = {compositeFilter:{op:'AND',filters:[
            {fieldFilter:{field:{fieldPath:field},op:'GREATER_THAN_OR_EQUAL',value:{stringValue:search}}},
            {fieldFilter:{field:{fieldPath:field},op:'LESS_THAN',value:{stringValue:search+'\uf8ff'}}},
          ]}};
        }
      }
      if (data.cursor) {
        fields(data.cursor,['id','value']);
        if (!validId(data.cursor.id) || typeof data.cursor.value !== 'string' || data.cursor.value.length > 320) invalid();
        query.startAt = {before:false,values:[...(field === '__name__' ? [] : [{stringValue:data.cursor.value}]),
          {referenceValue:db.doc(`${collection}/${data.cursor.id}`)}]};
      }
      const records = await t.query(query);
      const managers=collection==='organizations' && records.length ? await t.getAll(...records.slice(0,25).map(r=>userPath(r.managerUid))) : [];
      const items = records.slice(0,25).map((record,index) => {
        const result = {id:record.id,version:record.version};
        const keys = collection === 'users' ? ['uid','email','fullName','studentNumber','platformRole','accountStatus']
          : ['organizationId','name','description','logoURL','mission','vision','goals','membershipRequirements','visibility','status','managerUid','approvalSettings'];
        for (const key of keys) if (key in record) result[key] = record[key];
        if (collection === 'users') result.canReactivate = record.uid === record.id && record.platformRole === 'user'
          && record.accountStatus === 'disabled' && completeProfile(record);
        if(collection==='organizations') {const manager=managers[index]?.data(); result.managerStudentId=validStudentId(manager?.studentNumber)?manager.studentNumber:null; result.managerName=manager?.fullName ?? null; result.managerStatus=manager?.accountStatus ?? null;}
        return result;
      });
      const last = items.at(-1);
      return {items,nextCursor:records.length > 25 ? {id:last.id,value:field === '__name__' ? last.id : last[field]} : null};
    }),
    mutate: async ({auth,data}) => {
      fields(data,['requestId','operation','targetId','version','expectedManagerUid','changes','action']);
      if (!validId(auth.uid) || !validId(data.targetId) || !/^[A-Za-z0-9_-]{8,80}$/.test(data.requestId ?? '')) invalid();
      const operation = data.operation;
      if (!['accountStatus','createOrganization','updateOrganization'].includes(operation)) invalid();
      const creating = operation === 'createOrganization', account = operation === 'accountStatus';
      if (account && (data.changes !== undefined || !['approve','reject','deactivate','reactivate'].includes(data.action))) invalid();
      const patch = account ? null : organizationInput(data.changes,creating);
      const targetPath = `${account ? 'users' : 'organizations'}/${data.targetId}`;
      const request = canonical({...data,...(patch ? {changes:patch} : {})});
      const auditPath = db.doc(`activityLogs/admin-${auth.uid}-${data.requestId}`);
      return db.runTransaction(async t => {
        const [actor,target,audit] = await t.getAll(userPath(auth.uid),db.doc(targetPath),auditPath);
        admin(actor.data(),auth.uid);
        if (audit.data()) {
          if (JSON.stringify(canonical(audit.data().request)) !== JSON.stringify(request)) fail('conflict','This operation identifier was already used.');
          return {id:data.targetId,duplicate:true};
        }
        const current = target.data(); let changes, before;
        if (account) {
          if (!current || current.uid !== data.targetId) fail('not-found','The account is no longer available.');
          if (data.targetId === auth.uid || current.platformRole !== 'user')
            fail('permission-denied','Administrator accounts and your own account cannot be changed here.');
          versionMatches(target,data.version);
          if (data.action === 'approve' && (!completeProfile(current) || current.accountStatus !== 'pending'))
            fail('failed-precondition','Only complete pending profiles can be approved.');
          if ((data.action === 'reject' && current.accountStatus !== 'pending') || (data.action === 'deactivate' && current.accountStatus !== 'active'))
            fail('failed-precondition','The account status no longer supports this action.');
          if (data.action === 'reactivate' && (current.accountStatus !== 'disabled' || !completeProfile(current)))
            fail('failed-precondition','Only disabled student accounts with complete profiles can be reactivated.');
          changes = {accountStatus:{approve:'active',reject:'rejected',deactivate:'disabled',reactivate:'active'}[data.action]};
          before = {accountStatus:current.accountStatus};
        } else {
          if (creating && current) fail('already-exists','An organization with this identifier already exists.');
          if (!creating) {
            if (!current || current.organizationId !== data.targetId) fail('not-found','The organization is no longer available.');
            versionMatches(target,data.version);
            if (data.expectedManagerUid !== current.managerUid) fail('conflict','The organization manager changed. Refresh before saving.');
          }
          let managerUid=current?.managerUid,candidate;
          if(patch.managerStudentId) {
            const matched=await resolveStudentId(t,db,patch.managerStudentId);
            if(matched.version!==patch.managerProfileVersion || matched.registryVersion!==patch.managerRegistryVersion)
              fail('conflict','The manager profile or Student ID registry changed. Resolve and review it again.');
            managerUid=matched.uid;candidate=matched.profile;
          } else {
            const [manager]=await t.getAll(userPath(managerUid));candidate=manager.data();
          }
          if (candidate?.uid !== managerUid || candidate.accountStatus !== 'active' || !completeProfile(candidate)
            || !['user','platformAdmin'].includes(candidate.platformRole))
            fail('failed-precondition','Choose an active manager with a complete student profile.');
          changes = {...patch}; delete changes.acceptsRequests;
          delete changes.managerStudentId;delete changes.managerProfileVersion;delete changes.managerRegistryVersion;
          if(patch.managerStudentId)changes.managerUid=managerUid;
          if (creating || 'acceptsRequests' in patch) changes.approvalSettings = {
            ...(current?.approvalSettings ?? {mode:'manual'}), acceptsRequests:patch.acceptsRequests ?? true,
          };
          before = current ? {managerUid:current.managerUid,status:current.status,name:current.name} : null;
        }
        const now = Timestamp.fromMillis(clock());
        if (creating) t.create(db.doc(targetPath),{description:'',mission:'',vision:'',logoURL:null,goals:[],membershipRequirements:[],
          positions:[],publicOfficers:[],...changes,organizationId:data.targetId,createdAt:now,updatedAt:now},
          {serverTimestampFields:['createdAt','updatedAt']});
        else t.update(db.doc(targetPath),{...changes,updatedAt:now});
        t.create(auditPath,{actorUid:auth.uid,operation,targetPath,requestId:data.requestId,
          request,before,after:changes,createdAt:now},{serverTimestampFields:['createdAt']});
        return {id:data.targetId,duplicate:false};
      });
    },
  };
}
