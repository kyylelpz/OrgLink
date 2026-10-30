import {AttendanceError} from './attendance.js';
export const SEARCH_LIMIT=2000;
export const SEARCH_TTL=5*60*1000;
export const normalizeSearch=value=>value.trim().toLowerCase();
export function createDirectorySearchCache(clock=Date.now){
  const entries=new Map();
  return {
    invalidate(key){entries.delete(key);},
    async get(key,load){
      const previous=entries.get(key);
      if(previous&&previous.expiresAt>clock())return previous.promise;
      const entry={expiresAt:clock()+SEARCH_TTL,promise:Promise.resolve().then(load)};
      entries.delete(key);entries.set(key,entry);
      // Two directories in production, plus bounded room for local test origins.
      while(entries.size>4)entries.delete(entries.keys().next().value);
      try{return await entry.promise;}catch(error){if(entries.get(key)===entry)entries.delete(key);throw error;}
    },
  };
}
export async function substringPage({t,cache,key,collection,field,search,cursor}){
  const fields=collection==='users'
    ? ['uid','fullName','email','studentNumber','yearLevel','section','platformRole','accountStatus']
    : ['organizationId','name','description','logoURL','mission','vision','goals','membershipRequirements','visibility','status','managerUid','approvalSettings'];
  const rows=await cache.get(key,()=>t.query({from:[{collectionId:collection}],
    select:{fields:fields.map(fieldPath=>({fieldPath}))},
    orderBy:[{field:{fieldPath:'__name__'},direction:'ASCENDING'}],limit:SEARCH_LIMIT+1}));
  if(rows.length>SEARCH_LIMIT)throw new AttendanceError('resource-exhausted',
    `Substring search supports up to ${SEARCH_LIMIT} records per directory. The default paginated directory remains available. No partial search results were returned.`);
  const value=row=>normalizeSearch(field==='__name__'?row.id:typeof row[field]==='string'?row[field]:'');
  const after=cursor?normalizeSearch(cursor.value):null;
  const compare=(a,b)=>a<b?-1:a>b?1:0;
  return rows.filter(row=>value(row).includes(search)&&
    (!cursor||compare(value(row),after)>0||value(row)===after&&compare(row.id,cursor.id)>0))
    .sort((a,b)=>compare(value(a),value(b))||compare(a.id,b.id)).slice(0,26);
}
