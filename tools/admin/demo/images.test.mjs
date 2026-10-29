import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,rm,readFile} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import sharp from 'sharp';
import {buildDataset,hash} from './dataset.mjs';
import {prepareImage,graphic,safeIcon,download,retry,cloudinaryClient,validateAsset,LICENSES,MAX_IMAGE_BYTES} from './images.mjs';
import {cloudinarySignature} from '../../../workers/attendance/src/images.js';
const spec=buildDataset().images.at(-1),owner='a'.repeat(64),publicId='orglink/events/'+'b'.repeat(64),cloud='demo-test';
const asset={public_id:publicId,asset_id:'asset',asset_folder:'orglink/events',context:{custom:{orglink_demo_owner:owner}},secure_url:`https://res.cloudinary.com/${cloud}/image/upload/v1/${publicId}.png`,resource_type:'image',type:'upload',format:'png',bytes:1000,width:1380,height:736};
const env={CLOUDINARY_CLOUD_NAME:cloud,CLOUDINARY_API_KEY:'12345',CLOUDINARY_API_SECRET:'test-secret'};
test('fallback PNGs have valid dimensions, compression, embedded provenance and distinct bytes',async()=>{
  const cache=await mkdtemp(join(tmpdir(),'orglink-images-'));try{
    const noSource=async()=>new Response('not available',{status:404});const first=await prepareImage(spec,{cache,fetchImpl:noSource});const second=await prepareImage({...spec,index:spec.index+1,label:'Different Event'},{cache,fetchImpl:noSource});
    assert.ok(first.buffer.length<MAX_IMAGE_BYTES);assert.notEqual(hash(first.buffer),hash(second.buffer));assert.equal(first.metadata.license,'CC0-1.0');assert.equal(first.metadata.sourceUrl,null);assert.ok(first.metadata.fallback);const m=await sharp(first.buffer).metadata();assert.equal(m.width,spec.width);assert.equal(m.height,spec.height);assert.ok(m.exif.length>0);assert.equal(first.metadata.sha256,hash(first.buffer));
    const avatar=await prepareImage(buildDataset().images[0],{cache,fetchImpl:()=>{throw Error('Avatar must not fetch');}});assert.equal(avatar.metadata.width,768);assert.equal(avatar.metadata.license,'CC0-1.0');
  }finally{await rm(cache,{recursive:true,force:true});}
});
test('pinned licenses and original source references are preserved in metadata',async()=>{
  assert.ok(LICENSES.every(l=>/^[a-f0-9]{64}$/.test(l.sha256)&&l.url.startsWith('https://raw.githubusercontent.com/')));
  // License downloads with incorrect hashes MUST fall back, never claim that license was verified.
  const cache=await mkdtemp(join(tmpdir(),'orglink-license-'));try{const p=await prepareImage(spec,{cache,fetchImpl:async()=>new Response('forged license')});assert.equal(p.metadata.licenses.length,0);assert.equal(p.metadata.sourceSha256,null);assert.ok(p.metadata.fallback);}finally{await rm(cache,{recursive:true,force:true});}
});
test('verified licensed icons are composed and cached with full attribution',async()=>{
  const cache=await mkdtemp(join(tmpdir(),'orglink-licensed-'));let downloads=0;
  const fetchImpl=async url=>{downloads++;if(url.endsWith('/icons/palette.svg'))return new Response('<svg><path d="M2 4h20v16H2Z"/></svg>');const index=LICENSES.findIndex(l=>l.url===url);const file=index===0?'lucide-ISC.txt':'feather-MIT.txt';return new Response((await readFile(new URL(`./licenses/${file}`,import.meta.url),'utf8')).replace(/\r\n/g,'\n'));};
  try{const first=await prepareImage(spec,{cache,fetchImpl});assert.equal(first.metadata.licenses.length,2);assert.equal(first.metadata.license,'ISC AND MIT');assert.ok(first.metadata.sourceUrl.endsWith('palette.svg'));assert.equal(first.metadata.fallback,null);assert.ok(first.metadata.licenses.every(l=>l.text.includes('Permission')));const count=downloads;await prepareImage(spec,{cache,fetchImpl});assert.equal(downloads,count);}finally{await rm(cache,{recursive:true,force:true});}
});
test('SVG composition escapes titles and rejects active/external SVG content',()=>{
  assert.match(graphic({...spec,label:'A < B & C'}),/A &lt; B &amp; C/);
  assert.match(safeIcon('<svg><path d="M1 2"/></svg>'),/path/);
  for(const s of ['<svg><script/></svg>','<svg><image href="https://example.com"/></svg>','<svg><path onclick="x"/></svg>','<svg><use/></svg>','<svg><path fill="url(x)"/></svg>'])assert.throws(()=>safeIcon(s));
});
test('source downloading enforces allowlist, size, status and transient retry',async()=>{
  await assert.rejects(download('https://example.com/test'));const url=LICENSES[0].url;
  await assert.rejects(download(url,async()=>new Response(new Uint8Array(256*1024+1))));
  await assert.rejects(download(url,async()=>new Response('',{status:403})));
  let n=0;const result=await retry(async()=>{if(++n<3)throw Object.assign(Error('temporary'),{retryable:true});return 7;},{pause:async()=>{}});assert.equal(result,7);assert.equal(n,3);
  let permanent=0;await assert.rejects(retry(async()=>{permanent++;throw Error('permanent');},{pause:async()=>{}}));assert.equal(permanent,1);
});
test('Cloudinary signs dynamic folders and ownership, then independently verifies assets',async()=>{
  let uploaded=false,postCount=0;const calls=[];const client=cloudinaryClient(env,{clock:()=>1000000,fetchImpl:async(url,options)=>{calls.push([url,options]);if(url.endsWith('/image/upload')){postCount++;uploaded=true;const form=options.body;assert.equal(form.get('asset_folder'),'orglink/events');assert.equal(form.get('overwrite'),'false');const params=Object.fromEntries([...form].filter(([k])=>!['api_key','signature','file'].includes(k)));assert.equal(form.get('signature'),await cloudinarySignature(params,env.CLOUDINARY_API_SECRET));assert.equal(form.get('context'),`orglink_demo_owner=${owner}`);return Response.json(asset);}return uploaded?Response.json(asset):new Response('',{status:404});}});
  const result=await client.upload({publicId,folder:'orglink/events'},Buffer.from('png'),owner);assert.equal(result.public_id,publicId);assert.equal(postCount,1);await client.upload({publicId,folder:'orglink/events'},Buffer.from('png'),owner);assert.equal(postCount,1);assert.ok(calls.some(([url])=>url.includes('/resources/image/upload/')));
});
test('forged asset references, ownership, folder, formats and oversized files are rejected',()=>{
  const config={publicId,folder:'orglink/events',owner,cloud};assert.equal(validateAsset(asset,config),asset);
  for(const patch of [{public_id:'foreign'},{asset_folder:'orglink/profiles'},{context:{}},{format:'svg'},{bytes:MAX_IMAGE_BYTES+1},{width:5000},{pages:2},{secure_url:'http://example.com/image.png'},{type:'private'}])assert.throws(()=>validateAsset({...asset,...patch},config));
});
test('deletion checks ownership first, tolerates missing assets and confirms signed deletion',async()=>{
  let deletes=0;const client=cloudinaryClient(env,{fetchImpl:async(url,options)=>{if(url.endsWith('/image/destroy')){deletes++;assert.equal(options.body.get('public_id'),publicId);assert.equal(options.body.get('invalidate'),'true');return Response.json({result:'ok'});}return Response.json({...asset,context:{}});}});await assert.rejects(client.destroy({publicId,folder:'orglink/events'},owner));assert.equal(deletes,0);
  const missing=cloudinaryClient(env,{fetchImpl:async()=>new Response('',{status:404})});await missing.destroy({publicId,folder:'orglink/events'},owner);
  const valid=cloudinaryClient(env,{fetchImpl:async url=>url.endsWith('/image/destroy')?Response.json({result:'ok'}):Response.json(asset)});await valid.destroy({publicId,folder:'orglink/events'},owner);
});
test('lost upload response is reconciled without repeating the multipart upload',async()=>{
  let uploaded=false,posts=0;const client=cloudinaryClient(env,{fetchImpl:async url=>{if(url.endsWith('/image/upload')){posts++;uploaded=true;throw Error('lost response');}return uploaded?Response.json(asset):new Response('',{status:404});}});await client.upload({publicId,folder:'orglink/events'},Buffer.from('png'),owner);assert.equal(posts,1);
});
