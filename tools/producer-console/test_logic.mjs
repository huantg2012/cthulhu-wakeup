import {test} from 'node:test';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {calculatePreview, validateFeedback, mergeFeedback, deliveryItem, deliveryStatus, filterDelivery, deliveryConnections, deliveryContext} from './web/logic.mjs';

// Use the same CSV reader as the server, never copy current game coefficients.
// These assertions need only the parameter table. Serializing every evolving
// evidence report here can exceed Node's subprocess buffer without testing more.
const runParameters = JSON.parse(execFileSync('python3',['-c',"import json;from server import load_model;print(json.dumps(load_model()['tables']['run_parameters']))"],{cwd:new URL('.',import.meta.url)}));
const params=Object.fromEntries(runParameters.rows.map(r=>[r.id,Number(r.value)]));
const base={planet:1,system:1,cosmic:1,insight:0,wounds:0,population:81,cohesion:80};
const entry={id:'DISC-TEST',target:'MECH-ANCHORS',title:'测试',body:'内容',kind:'question',status:'open',createdAt:'2026-10-25',updatedAt:'2026-10-25',sourceRevision:'test'};
const valid = id => id==='MECH-ANCHORS';

test('preview uses CSV coefficients and applies rounding once',()=>{
 const actual=calculatePreview(base,params);
 assert.equal(actual.a,params.initial_awakening+params.anchor_planet_contribution+params.anchor_system_contribution+params.anchor_cosmic_contribution);
 assert.equal(actual.upkeep,params.anchor_planet_upkeep+params.anchor_system_upkeep+params.anchor_cosmic_upkeep);
 assert.equal(actual.income,6);
});
test('zero, cap, wounds and cross-tier prerequisites have distinct outcomes',()=>{
 assert.equal(calculatePreview({...base,planet:0,system:0,cosmic:0,wounds:100},params).a,0);
 assert.equal(calculatePreview({...base,planet:18,system:12,cosmic:6,insight:20},params).a,params.awakening_before_final_cap);
 assert.equal(calculatePreview({...base,planet:18,system:12,cosmic:0,insight:20},params).qualified,false);
 assert.equal(calculatePreview({...base,population:0},params).income,0);
 assert.equal(calculatePreview({...base,cohesion:0},params).income,0);
});
test('offline and online imports reject malformed or unknown targets',()=>{
 assert.doesNotThrow(()=>validateFeedback({schemaVersion:1,revision:0,items:[entry]},valid));
 for(const change of [{body:4},{status:'adopted'},{target:'DATA-powers/unknown'},{title:''},{extra:'field'}]) {
   assert.throws(()=>validateFeedback({schemaVersion:1,revision:0,items:[{...entry,...change}]},valid));
 }
});
test('merge is idempotent, order-independent, and never silently overwrites',()=>{
 const reordered=Object.fromEntries(Object.entries(entry).reverse());
 assert.equal(mergeFeedback([entry],[reordered]).length,1);
 assert.equal(mergeFeedback([entry],[{...entry,id:'DISC-SECOND'}]).length,2);
 assert.throws(()=>mergeFeedback([entry],[{...entry,body:'changed'}]),/冲突/);
 assert.equal(entry.body,'内容');
});

const delivery={
 requirements:[{id:'REQ-DEATH',title:'死亡传播',features:['MECH-PEOPLE'],rule:'身份不可复用',tasks:['TASK-LIFE'],contracts:['SET-LIFE'],acceptance:['ACC-DEATH'],coverage:{assigned:true,implemented:true,verification:'passed',missing:[]}},
 {id:'REQ-SAVE',title:'保存继续',features:['MECH-SAVE'],tasks:['TASK-SAVE'],contracts:[],acceptance:['ACC-SAVE'],coverage:{assigned:true,implemented:false,verification:'stale',missing:['等待新证据']}}],
 contracts:[{id:'SET-LIFE',title:'人物生命周期',features:['MECH-PEOPLE'],acceptance:['ACC-DEATH']}],
 tasks:[{id:'TASK-LIFE',title:'生命周期',features:['MECH-PEOPLE'],dependsOn:[],acceptance:['ACC-DEATH'],status:'verified',readiness:{ready:true,blockedBy:[]}},
 {id:'TASK-SAVE',title:'保存',features:['MECH-SAVE'],dependsOn:['TASK-LIFE'],acceptance:['ACC-SAVE'],status:'planned',readiness:{ready:true,blockedBy:[]}}],
 scenarios:[{id:'ACC-DEATH',title:'死亡解除引用',features:['MECH-PEOPLE'],verification:{status:'passed',evidence:[]}},
 {id:'ACC-SAVE',title:'保存续跑',features:['MECH-SAVE'],verification:{status:'stale',evidence:[]}}]
};
test('tracking locates all four stable object types and filters missing evidence separately',()=>{
 assert.equal(deliveryItem(delivery,'SET-LIFE').group,'contracts');
 assert.equal(deliveryItem(delivery,'TASK-LIFE').group,'tasks');
 assert.equal(deliveryItem(delivery,'ACC-DEATH').group,'scenarios');
 assert.equal(deliveryItem(delivery,'unknown'),null);
 assert.deepEqual(filterDelivery(delivery,{status:'gaps'}).map(x=>x.id),['REQ-SAVE']);
 assert.deepEqual(filterDelivery(delivery,{feature:'MECH-PEOPLE',query:'身份'}).map(x=>x.id),['REQ-DEATH']);
 assert.deepEqual(filterDelivery(delivery,{group:'scenarios',status:'stale'}).map(x=>x.id),['ACC-SAVE']);
 assert.deepEqual(filterDelivery(undefined),[]);
});
test('tracking follows forward and reverse links without inventing gameplay dependencies',()=>{
 const links=deliveryConnections(delivery,deliveryItem(delivery,'TASK-LIFE'));
 assert.deepEqual(new Set(links),new Set(['REQ-DEATH','ACC-DEATH','TASK-SAVE']));
 assert.equal(links.includes('MECH-PEOPLE'),false);
});
test('discussion workflow cannot promote traceability or make stale evidence current',()=>{
 const original=JSON.stringify(delivery);
 validateFeedback({schemaVersion:1,revision:0,items:[{...entry,target:'REQ-SAVE',status:'planned'}]},id=>!!deliveryItem(delivery,id));
 assert.equal(deliveryStatus(deliveryItem(delivery,'REQ-SAVE')),'stale');
 assert.equal(JSON.stringify(delivery),original);
 const staleTask={...deliveryItem(delivery,'TASK-LIFE'),verification:'stale'};
 assert.equal(deliveryStatus(staleTask),'stale');
 const changed={...delivery,tasks:[staleTask]};
 assert.equal(filterDelivery(changed,{group:'tasks',status:'gaps'}).length,1);
});


test('copied implementation context includes actionable evidence, task dependencies and settlement facts',()=>{
 const scenario={...deliveryItem(delivery,'ACC-DEATH'),given:'持有人活着并携带圣物',when:'记录持有人死亡',then:['死亡身份保留','解除携带'],verification:{status:'stale',evidence:[{check:'SIM-DEATH',report:'docs/qa/formal-simulation-results.json',status:'stale',generatedAt:'2026-10-25T06:00:00Z',changed:['src/simulation/world.gd'],reason:'实现已变化'}]}};
 const text=deliveryContext(delivery,scenario);
 for(const expected of ['给定局势：持有人活着并携带圣物','执行操作：记录持有人死亡','- 死亡身份保留','SIM-DEATH · stale · docs/qa/formal-simulation-results.json','src/simulation/world.gd','实现已变化'])assert.ok(text.includes(expected),expected);
 const task=deliveryContext(delivery,{...deliveryItem(delivery,'TASK-SAVE'),scope:'保存世界状态',readiness:{ready:false,blockedBy:['TASK-LIFE']}});
 for(const expected of ['交付范围：保存世界状态','前置任务：\n- TASK-LIFE','阻塞项：\n- TASK-LIFE','ACC-SAVE'])assert.ok(task.includes(expected),expected);
 const contract=deliveryContext(delivery,{...deliveryItem(delivery,'SET-LIFE'),owner:'人物状态结算',phase:'事实发生时',reads:['当前身份'],writes:['生命状态'],resolution:['死亡优先于普通恢复'],invariants:['身份不能复用']});
 for(const expected of ['结算责任：人物状态结算','生效时点：事实发生时','读取事实：\n- 当前身份','写入事实：\n- 生命状态','死亡优先于普通恢复','身份不能复用'])assert.ok(contract.includes(expected),expected);
 const empty=deliveryContext(delivery,{...scenario,evidence:[],verification:{status:'unverified',evidence:[]}});
 assert.ok(empty.includes('尚未记录可用运行证据'));
});
