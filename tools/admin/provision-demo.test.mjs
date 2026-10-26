import {test} from 'node:test';
import assert from 'node:assert/strict';
import {buildPlan,main} from './provision-demo.mjs';
test('sample organization IDs are stable and privileges are scoped',()=>{
  const plan=buildPlan('synthetic-manager');
  assert.equal(plan.length,4);assert.deepEqual(plan,buildPlan('synthetic-manager'));
  assert.ok(plan.every(org=>org.managerUid==='synthetic-manager' && !('platformRole' in org)));
  assert.equal(plan.filter(org=>org.visibility==='public' && org.status==='active').length,2);
});
test('reject invalid UID or another project before any Firebase calls',async()=>{
  assert.throws(()=>buildPlan('bad/uid'));assert.throws(()=>buildPlan(''));
  await assert.rejects(main(['--project','other','--manager-uid','demo']),/orglink-dev/);
});
test('applying requires explicit demonstration-manager acknowledgment',async()=>{
  await assert.rejects(main(['--project','orglink-dev','--manager-uid','demo','--apply']),/confirm-demo-manager/);
});
