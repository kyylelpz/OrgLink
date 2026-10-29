export class MemoryDb {
  records=new Map();version=0;tail=Promise.resolve();failAudit=false;
  doc(path){return path;}
  seed(path,value){this.records.set(path,{value:structuredClone(value),version:`v${++this.version}`});}
  get(path){return this.records.get(path)?.value;}
  v(path){return this.records.get(path)?.version;}
  async runTransaction(fn){
    const previous=this.tail;let release;this.tail=new Promise(resolve=>release=resolve);await previous;
    const writes=[];
    const query=async q=>{
      const collection=q.from[0].collectionId;
      let rows=[...this.records].filter(([p])=>p.startsWith(collection+'/')&&p.split('/').length===2)
        .map(([p,r])=>({...structuredClone(r.value),id:p.split('/').at(-1),version:r.version}));
      const value=(row,field)=>field==='__name__'?`${collection}/${row.id}`:row[field];
      const matches=(row,f)=>{if(f.compositeFilter)return f.compositeFilter.filters.every(x=>matches(row,x));
        const x=f.fieldFilter,a=value(row,x.field.fieldPath),b=x.value.stringValue??x.value.referenceValue;
        return x.op==='EQUAL'?a===b:x.op==='GREATER_THAN_OR_EQUAL'?a>=b:a<b;};
      if(q.where)rows=rows.filter(row=>matches(row,q.where));
      const orders=q.orderBy??[];
      rows=rows.filter(row=>orders.every(o=>value(row,o.field.fieldPath)!==undefined));
      rows.sort((a,b)=>{for(const o of orders){const x=value(a,o.field.fieldPath),y=value(b,o.field.fieldPath);if(x!==y)return x<y?-1:1;}return 0;});
      if(q.startAt) rows=rows.filter(row=>{for(let i=0;i<orders.length;i++){const a=value(row,orders[i].field.fieldPath),b=q.startAt.values[i].stringValue??q.startAt.values[i].referenceValue;if(a!==b)return a>b;}return false;});
      return rows.slice(0,q.limit??rows.length);
    };
    const t={getAll:async(...paths)=>paths.map(path=>({data:()=>structuredClone(this.get(path)),exists:this.get(path)!==undefined,updateTime:this.v(path)})),query,
      count:async q=>(await query(q)).length,
      create:(path,data)=>{if(this.get(path))throw Error('Already exists');if(this.failAudit&&path.startsWith('activityLogs/'))throw Error('Audit failed');writes.push([path,data]);},
      update:(path,data)=>writes.push([path,{...this.get(path),...data}]),set:(path,data)=>writes.push([path,data])};
    try{const result=await fn(t);for(const [path,data] of writes)this.seed(path,data);return result;}finally{release();}
  }
}