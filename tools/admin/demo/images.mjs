import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {join} from 'node:path';
import {hash} from './dataset.mjs';
import {cloudinarySignature} from '../../../workers/attendance/src/images.js';

export const MAX_IMAGE_BYTES=5*1024*1024;
export const LICENSES=[
  {url:'https://raw.githubusercontent.com/lucide-icons/lucide/0.468.0/LICENSE',sha256:'1e7290b35280a048667bbf0ebabac1c7fd52a75300e8b2946ac165715997f2bc',spdx:'ISC',attribution:'Lucide Contributors (2022); portions Cole Bemis (2013–2022)'},
  {url:'https://raw.githubusercontent.com/feathericons/feather/v4.29.2/LICENSE',sha256:'308028e93fcf84972523cdf6e616f73168546b4953895f516d01287f16fe7bee',spdx:'MIT',attribution:'Cole Bemis, Feather'},
];
export async function retry(action,{attempts=3,pause=ms=>new Promise(r=>setTimeout(r,ms))}={}) {
  for(let i=0;;i++) {try{return await action();}catch(e){if(!e.retryable||i>=attempts-1)throw e;await pause(300*2**i);}}
}
const transient=message=>Object.assign(Error(message),{retryable:true});
export async function download(url,fetchImpl=fetch) {
  if(!/^https:\/\/raw\.githubusercontent\.com\/(lucide-icons\/lucide\/0\.468\.0\/(LICENSE|icons\/[a-z-]+\.svg)|feathericons\/feather\/v4\.29\.2\/LICENSE)$/.test(url))throw Error('Unapproved image source.');
  return retry(async()=>{
    let r;try{r=await fetchImpl(url,{redirect:'error',signal:AbortSignal.timeout(20000),headers:{'User-Agent':'OrgLink-development-demo-seeder/1.0'}});}catch{throw transient('Image source unavailable.');}
    if(r.status===429||r.status>=500)throw transient('Image provider temporarily unavailable.');
    if(!r.ok)throw Error('Image provider rejected the source.');
    const chunks=[];let length=0;
    for await(const chunk of r.body){length+=chunk.length;if(length>256*1024)throw Error('Source exceeds size limit.');chunks.push(chunk);}
    return Buffer.concat(chunks);
  });
}
export function safeIcon(source) {
  // Only the pinned icon collection's primitive drawing elements, no external resources.
  if(!/^\s*<svg\b/.test(source)||/<(?:script|image|use|foreignObject|style|text|a)\b|(?:href|on\w+|url)\s*[=(]|<!/i.test(source))throw Error('Unsupported icon markup.');
  const body=source.replace(/^\s*<svg\b[^>]*>/,'').replace(/<\/svg>\s*$/,'');
  if(/<(?!\/?(?:path|circle|rect|line|polyline|polygon|ellipse|g)\b)/i.test(body))throw Error('Unsupported icon elements.');
  return body;
}
const escape=value=>value.replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&apos;'}[c]));
export function graphic(spec,icon='') {
  const colors=['#153F59','#236859','#593C68','#7A402B','#304A83'],bg=colors[spec.index%colors.length],w=spec.width,h=spec.height;
  const avatar=spec.folder.endsWith('profiles');
  const drawing=avatar?`<circle cx="384" cy="290" r="${95+spec.index%4*7}" fill="#FFE0BD"/><path d="M175 700 Q170 440 384 445 Q600 440 593 700" fill="hsl(${spec.index*47%360},60%,75%)"/><path d="M275 265 Q270 100 400 165 Q505 150 495 265 Q400 215 275 265" fill="#263238"/><circle cx="350" cy="295" r="9" fill="#263238"/><circle cx="420" cy="295" r="9" fill="#263238"/><path d="M355 350 Q385 375 415 350" stroke="#8D493A" stroke-width="9" fill="none"/>`:
    `<g transform="translate(${w/2-100},${h/2-160}) scale(8.3)" fill="none" stroke="#FFFFFF" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">${icon||'<circle cx="12" cy="12" r="9"/><path d="M6 12h12M12 6v12"/>'}</g>`;
  const words=spec.label.split(' '),lines=[];let line='';for(const word of words){if((line+' '+word).length>29){lines.push(line);line=word;}else line+=(line?' ':'')+word;}if(line)lines.push(line);
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}"><rect width="100%" height="100%" fill="${bg}"/><circle cx="${w*.9}" cy="${h*.1}" r="${160+spec.index*2}" fill="#FFFFFF" opacity=".06"/>${drawing}${(avatar?[spec.label]:lines).map((text,i)=>`<text x="50%" y="${h-105+i*35}" text-anchor="middle" fill="#FFFFFF" font-family="sans-serif" font-size="${avatar?28:30}">${escape(text)}</text>`).join('')}<text x="50%" y="${h-20}" text-anchor="middle" fill="#FFFFFF" font-family="sans-serif" font-size="18">ORGLINK · FICTIONAL DEMO ${String(spec.index+1).padStart(2,'0')}</text></svg>`;
}
export async function prepareImage(spec,{cache,fetchImpl=fetch,sharpImpl,now=()=>new Date().toISOString()}={}) {
  const sharp=sharpImpl??(await import('sharp')).default;
  await mkdir(cache,{recursive:true});
  let icon='',licenses=[],fallback=null,sourceSha256=null;
  const sourceUrl=`https://raw.githubusercontent.com/lucide-icons/lucide/0.468.0/icons/${spec.icon}.svg`;
  async function cached(url) {
    const path=join(cache,hash(url));try{return await readFile(path);}catch(e){if(e.code!=='ENOENT')throw e;}
    const bytes=await download(url,fetchImpl);await writeFile(path,bytes,{mode:0o600});return bytes;
  }
  if(!spec.folder.endsWith('profiles')) {
    try {
      for(const license of LICENSES){const bytes=await cached(license.url);if(hash(bytes)!==license.sha256)throw Error('License checksum changed.');licenses.push({...license,text:bytes.toString('utf8')});}
      const source=await cached(sourceUrl);icon=safeIcon(source.toString('utf8'));sourceSha256=hash(source);
    }catch{icon='';licenses=[];fallback='Licensed source unavailable or failed verification; original generated graphic used.';}
  }
  const metadata={sourceUrl:icon?sourceUrl:null,sourceSha256:icon?sourceSha256:null,licenses,attribution:icon?LICENSES.map(l=>l.attribution).join('; '):'OrgLink original synthetic demonstration artwork',license:icon?'ISC AND MIT':'CC0-1.0',licenseUrl:icon?LICENSES[0].url:'https://creativecommons.org/publicdomain/zero/1.0/',generated:true,fallback,retrievedAt:now(),width:spec.width,height:spec.height};
  const buffer=await sharp(Buffer.from(graphic(spec,icon)),{limitInputPixels:8_000_000}).resize(spec.width,spec.height,{fit:'cover'}).withMetadata({exif:{IFD0:{Copyright:JSON.stringify(metadata)}}}).png({compressionLevel:9}).toBuffer();
  const actual=await sharp(buffer).metadata();
  if(buffer.length<1||buffer.length>MAX_IMAGE_BYTES||actual.format!=='png'||actual.width!==spec.width||actual.height!==spec.height)throw Error('Prepared image failed validation.');
  return {buffer,metadata:{...metadata,bytes:buffer.length,sha256:hash(buffer),format:'png'}};
}
export function validateAsset(a,{publicId,folder,owner,cloud}) {
  if(a?.public_id!==publicId||a.asset_folder!==folder||a.context?.custom?.orglink_demo_owner!==owner||a.resource_type!=='image'||a.type!=='upload'||!['png','jpg','webp'].includes(a.format)||!Number.isInteger(a.bytes)||a.bytes<1||a.bytes>MAX_IMAGE_BYTES||!Number.isInteger(a.width)||!Number.isInteger(a.height)||Math.min(a.width,a.height)<1||Math.max(a.width,a.height)>4096||(a.pages??1)>1||typeof a.secure_url!=='string'||a.secure_url.length>2048||!a.secure_url.startsWith(`https://res.cloudinary.com/${cloud}/image/upload/`)||!a.secure_url.endsWith(`/${publicId}.${a.format}`))throw Error('Cloudinary asset identity, ownership or image validation failed.');
  return a;
}
export function cloudinaryClient(env,{fetchImpl=fetch,clock=Date.now}={}) {
  const cloud=env.CLOUDINARY_CLOUD_NAME,key=env.CLOUDINARY_API_KEY,secret=env.CLOUDINARY_API_SECRET;
  if(!/^[a-z0-9_-]+$/i.test(cloud??'')||!/^\d+$/.test(key??'')||!secret)throw Error('Configure the three Cloudinary environment bindings.');
  async function request(path,options={},missing=false,allowRetry=true){return retry(async()=>{
    let r;try{r=await fetchImpl(`https://api.cloudinary.com/v1_1/${cloud}/${path}`,{...options,redirect:'error',signal:AbortSignal.timeout(25000)});}catch{throw transient('Cloudinary transport failed.');}
    if(missing&&r.status===404)return null;
    if(r.status===429||r.status>=500)throw transient('Cloudinary temporarily unavailable.');
    if(!r.ok)throw Error(`Cloudinary request failed (HTTP ${r.status}); credentials and response bodies are withheld.`);
    try{return await r.json();}catch{throw transient('Cloudinary response unavailable.');}
  },{attempts:allowRetry?3:1});}
  const inspect=publicId=>request(`resources/image/upload/${encodeURIComponent(publicId)}?context=true`,{headers:{Authorization:`Basic ${Buffer.from(`${key}:${secret}`).toString('base64')}`}},true);
  return {cloud,inspect,
    async upload(spec,buffer,owner){
      // Recover an upload whose response was lost, instead of reuploading on retries.
      const existing=await inspect(spec.publicId);if(existing)return validateAsset(existing,{...spec,owner,cloud});
      const params={public_id:spec.publicId,asset_folder:spec.folder,timestamp:Math.floor(clock()/1000),overwrite:'false',allowed_formats:'jpg,png,webp',transformation:'c_limit,w_2048,h_2048',context:`orglink_demo_owner=${owner}`};
      const form=new FormData();for(const [k,v] of Object.entries(params))form.set(k,String(v));
      form.set('api_key',key);form.set('signature',await cloudinarySignature(params,secret));form.set('file',new Blob([buffer],{type:'image/png'}),'demo.png');
      // Do not blindly retry multipart POST: a lost response must be reconciled by inspection.
      try{await request('image/upload',{method:'POST',body:form},false,false);}catch(error){const found=await inspect(spec.publicId);if(!found)throw error;}
      return validateAsset(await inspect(spec.publicId),{...spec,owner,cloud});
    },
    async destroy(spec,owner){const a=await inspect(spec.publicId);if(!a)return;validateAsset(a,{...spec,owner,cloud});const params={public_id:spec.publicId,timestamp:Math.floor(clock()/1000),invalidate:'true'};const body=new URLSearchParams({...params,timestamp:String(params.timestamp),api_key:key,signature:await cloudinarySignature(params,secret)});const result=await request('image/destroy',{method:'POST',body});if(!['ok','not found'].includes(result.result))throw Error('Cloudinary deletion was not confirmed.');},
  };
}
