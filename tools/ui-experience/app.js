/* Offline interaction study. Deterministic fixture receipts, never a game engine. */
'use strict';
(() => {
const C=window.CATALOG, P=C.params, $=id=>document.getElementById(id);
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const clone=x=>JSON.parse(JSON.stringify(x));
const B=(label,cmd,args={},disabled=false,cls='')=>`<button type="button" class="${cls}" data-cmd="${cmd}" data-args="${esc(JSON.stringify(args))}" ${disabled?'disabled':''}>${esc(label)}</button>`;
const tag=s=>`<span class="tag">${esc(s)}</span>`;
const rows=x=>x.join('');
const info=(title,body)=>`<div class="block"><h3>${esc(title)}</h3><div style="margin-top:9px">${body}</div></div>`;
const scenarios=[['opening','初醒 · 无教团与圣物'],['events','轮初事件 · 必须先处理'],['foundation','首团之前 · 组织与实践'],['mid','多成员教团 · 自由行动'],['answered','祈求已回应 · 继续主动行动'],['crowded','十二教团 · 供奉不足'],['pressure','容量浏览 · 三十六世界记录'],['scarce','零资源 · 仍可结束回合'],['rest','敛息 · 未行动且有创伤'],['loss','拘禁与失去媒介'],['late','降临准备 · 高阶条件'],['manifest','降临进行中 · 待续付'],['victory','终局 · 苏醒'],['defeat','终局 · 寂灭']];
const routeNames=['引导入梦','观察法则例外','独立复核异常','再次使用例外','交换异常读数','私祷献身','共同工作','秘密集会','主持祭仪','记录实践','维持历法','祭仪教习','共同见闻','再现共同记忆','保留不同视角','建立保管约定','履行祈求中的约定','互惠交付'];
const ROUTES=C.progression_route_operations.map((r,i)=>({...r,name:routeNames[i]}));
const powerFields={
 POWER_LISTEN:['clue','fact'],POWER_DREAM:['person','contact','preparation'],POWER_ORACLE:['person','purpose','preparation'],POWER_BESTOW:['person','attribute'],POWER_APPOINT:['cult','person','office','anchor'],POWER_SACRIFICE:['person','sacrifice'],POWER_BREACH:['person','world','weakness','preparation'],POWER_SEED:['person','cult','material','preparation'],POWER_ANCHOR:['world','institution','keeper','relic','basis'],POWER_VEIL:['person','cult','evidence','preparation'],POWER_TRANSFER:['person','destination','followers'],POWER_MANIFEST:['cosmic','system','keeper']};
const fieldNames={person:'人物',contact:'实际联系',clue:'已获得的线索',fact:'所指事实',preparation:'准备与圣物',purpose:'神谕指向的行动',attribute:'赐予的能力',cult:'教团',office:'职务',anchor:'已有锚点',sacrifice:'献祭用途',world:'世界',weakness:'当前弱点情报',material:'当前材料',institution:'机构',keeper:'护持者',relic:'绑定圣物',basis:'当前依托',evidence:'要销毁的证据',destination:'接收教团所在世界',followers:'随行信众',cosmic:'宇宙锚点',system:'星系锚点',recipient:'接收人',record:'记录',mode:'方式',other:'另一参与者',stage:'当前步骤',source:'当前来源'};
let S, stack=[], pending=null, lastFocus=null;
function world(id){return S.worlds.find(w=>w.id===Number(id));}
function cult(id){return S.cults.find(c=>c.world===Number(id));}
function person(id){return S.people.find(p=>p.id===id);}
function relic(id){return S.relics.find(r=>r.id===id);}
function title(id){return world(id)?.name||'所指世界';}
function memberName(id){return person(id)?.name||'尚未辨明的人物';}
function active(){return S.phase==='actions'&&!S.terminal;}
function addHistory(message,links=[]){S.history.unshift({turn:S.turn,message,links});S.history=S.history.slice(0,80);}
function toast(t){$('toast').textContent=t;$('toast').style.display='block';clearTimeout(toast.timer);toast.timer=setTimeout(()=>$('toast').style.display='none',2600);}
function makeWorlds(count){const indexes=[0,1,2,0,1,2,3,4,5,3,6,7];return Array.from({length:count},(_,i)=>{const p=C.civilization_profiles[indexes[i%12]];return {id:i+1,name:`${p.name} · ${String(i+1).padStart(2,'0')}`,tier:p.tier,profile:p.id,known:i<12,clue:false,focus:[1,4,7].includes(i+1),barrier:i===3?75:null,pollution:i===3?29:null,alert:i===3?61:null,stability:null};});}
function makePerson(id,w,role='成员'){return {id,name:({'N04':'记录者','N05':'祭司','N06':'使者'}[id]||'信徒')+' · '+id,world:w,role,bound:true,cult:w,loyalty:76,sanity:52,status:'在场',used:false,tenure:5,devotion:true,leaveAllowed:role==='成员'};}
function fixture(key){
 const s={version:1,scenario:key,turn:18,phase:'actions',faith:18,whispers:4,budget:4,awake:43,insight:12,wounds:0,peak:43,responded:false,usedAction:false,selectedCult:4,center:'home',worlds:makeWorlds(12),cults:[],people:[],relics:[],anchors:[],prayers:['PRAYER_08','PRAYER_01','PRAYER_04'],eventIds:[],eventResolved:[],history:[],releaseFocus:[],notices:[{world:10,text:'本轮末将扣押空名印',relic:'R11'},{world:6,text:'祈求余1轮'}],manifest:null,terminal:null,localFollowers:3,localSpent:4,cultQuery:'',relicQuery:'',filters:{},drafts:{},reservations:[{id:'reserve1',text:'尚未使用的记录实践参与预留',releasable:true}],result:null};
 for(const [w,n,coh,order] of [[1,49,80,'传教'],[4,64,70,'传教'],[7,81,80,'传教'],[11,100,85,'守持']])s.cults.push({world:w,followers:n,cohesion:coh,order,state:'运作中',leader:'N'+String(w).padStart(2,'0')});
 for(const [id,w,role] of [['N01',1,'领袖／护持者'],['N02',1,'成员'],['N04',4,'领袖'],['N05',4,'祭仪者'],['N06',4,'成员'],['N07',7,'领袖／护持者'],['N08',7,'成员'],['N11',11,'领袖／护持者'],['N12',11,'成员']])s.people.push(makePerson(id,w,role));
 for(let i=0;i<18;i++){const type=C.relics[i%6];s.relics.push({id:'R'+String(i+1).padStart(2,'0'),type:type.id,name:type.name,world:i<3?[1,7,11][i]:[4,1,7,11][i%4],placement:i<3?'绑定':i<8?'携带':'保管',holder:i>=3&&i<8?['N04','N01','N07','N08','N11'][i-3]:'',anchor:i<3?'A'+(i+1):''});}
 s.relics[6].world=7;s.relics[7].world=11;
 [[1,4,1,'N01'],[7,7,2,'N07'],[11,10,4,'N11']].forEach(([w,contribution,cost,keeper],i)=>s.anchors.push({id:'A'+(i+1),world:w,institution:'解释机构',contribution,cost,keeper,relic:'R0'+(i+1),active:true,refuse:false}));
 s.history=[{turn:18,message:'轮初整理完成；低语已刷新。',links:[{type:'budget'}]},{turn:17,message:'世界10发出了扣押圣物的预告。',links:[{type:'world',id:10}]}];
 if(['opening','foundation'].includes(key)){
  s.turn=key==='opening'?1:4;s.awake=10;s.insight=0;s.peak=10;s.budget=3;s.whispers=3;s.faith=key==='opening'?18:12;s.cults=[];s.relics=[];s.anchors=[];s.worlds=makeWorlds(1);s.worlds[0].focus=true;s.selectedCult=null;
  s.people=[{...makePerson('N01',1,'受求告者'),bound:key==='foundation',cult:null,loyalty:key==='foundation'?45:30,devotion:key==='foundation'}];s.notices=[];s.prayers=['PRAYER_08'];s.reservations=[];s.history=[{turn:s.turn,message:'一位记录者的求告进入你的感知。',links:[{type:'person',id:'N01'}]}];
 }
 if(key==='events'){s.phase='events';s.eventIds=['EVENT_02','EVENT_05'];}
 if(key==='answered'){s.responded=true;s.whispers=3;s.usedAction=true;s.center='cult';}
 if(['crowded','pressure'].includes(key)){
  s.turn=46;s.awake=65;s.peak=65;s.budget=5;s.whispers=4;s.responded=true;s.usedAction=true;s.center='cult';s.worlds=makeWorlds(key==='pressure'?36:12);s.worlds.forEach(w=>w.known=true);s.cults=[];s.people=[];s.anchors=[];
  const ns=[49,36,25,64,16,9,81,64,49,36,100,25],cs=[80,75,64,70,60,52,80,76,70,64,85,60];
  s.worlds.forEach(w=>w.focus=[1,2,4].includes(w.id));
  for(let i=1;i<=12;i++){s.people.push(makePerson('N'+String(i).padStart(2,'0'),i,'领袖'));s.cults.push({world:i,followers:ns[i-1],cohesion:cs[i-1],order:[1,2,4].includes(i)?'传教':[5,8,12].includes(i)?'敛藏':'守持',state:'运作中',leader:'N'+String(i).padStart(2,'0')});}
  for(const [j,w] of [11,7,8,9,1,2,4].entries()){const tier=s.worlds[w-1].tier;s.anchors.push({id:'A'+(j+1),world:w,institution:'解释机构',contribution:{planet:4,system:7,cosmic:10}[tier],cost:{planet:1,system:2,cosmic:4}[tier],keeper:'N'+String(w).padStart(2,'0'),relic:'R'+String(j+1).padStart(2,'0'),active:true,refuse:false});s.people[w-1].role='领袖／护持者';}
  s.relics.forEach((r,i)=>{r.placement=i<7?'绑定':i<12?'携带':'保管';r.world=i<7?s.anchors[i].world:[1,3,5,10,12][(i-7+5)%5];r.holder=i>=7&&i<12?'N'+String(r.world).padStart(2,'0'):'';r.anchor=i<7?s.anchors[i].id:'';});
 }
 if(key==='scarce'){s.faith=0;s.whispers=0;s.usedAction=true;s.responded=true;}
 if(key==='rest'){s.faith=12;s.wounds=3;s.awake=40;}
 if(key==='loss'){s.people.find(p=>p.id==='N04').status='失踪';s.people.find(p=>p.id==='N05').status='被拘禁';s.cults.find(c=>c.world===4).state='休眠';s.cults.find(c=>c.world===4).dormant=2;s.relics[3].placement='扣押';s.notices.unshift({world:4,text:'领袖失踪 · 教团连续休眠2轮'});s.center='cult';}
 if(['late','manifest','victory'].includes(key)){
  s.turn=70;s.awake=93;s.peak=93;s.insight=13;s.faith=60;s.budget=6;s.whispers=6;s.selectedCult=11;s.center='cult';s.cults.push({world:8,followers:64,cohesion:80,order:'守持',state:'运作中',leader:'N08'});s.cults.forEach(c=>c.order='守持');s.people=[];s.anchors=[];let n=1;
  for(const [w,count] of [[1,3],[7,3],[8,1],[11,3]])for(let j=0;j<count;j++){const id='N'+String(n++).padStart(2,'0');s.people.push(makePerson(id,w,j===0?'领袖／护持者':'护持者'));if(j===0)s.cults.find(c=>c.world===w).leader=id;const tier=s.worlds[w-1].tier;s.anchors.push({id:'A'+n,world:w,institution:['解释机构','传播机构','秩序机构'][j],contribution:{planet:4,system:7,cosmic:10}[tier],cost:{planet:1,system:2,cosmic:4}[tier],keeper:id,relic:'R'+String(n-1).padStart(2,'0'),active:true,refuse:false});}
  s.people.push(makePerson('N20',4,'领袖'));s.cults.find(c=>c.world===4).leader='N20';s.worlds.forEach(w=>w.focus=[7,8,11].includes(w.id));s.relics.forEach((r,i)=>{r.placement=i<10?'绑定':'保管';r.holder='';r.world=i<10?s.anchors[i].world:11;r.anchor=i<10?s.anchors[i].id:'';});s.notices=[];
  if(key==='manifest')s.manifest={step:2,paid:false,keeper:s.anchors.find(a=>a.world===11).keeper};
  if(key==='victory'){s.terminal='victory';s.phase='ended';s.awake=100;}
 }
 if(key==='defeat'){s.terminal='defeat';s.phase='ended';s.awake=0;s.notices=[];}
 return s;
}
function loadScenario(key){S=fixture(key);stack=[];pending=null;$('scenario').value=key;render();}
function income(c){if(c.state!=='运作中')return 0;return Math.floor(Math.min(P.cult_income_cap,Math.sqrt(c.followers))*c.cohesion/100*(c.order==='敛藏'?P.conceal_income_multiplier:1));}
function budget(){let balance=S.faith;const payments=[];for(const c of S.cults){if(c.order!=='传教'||c.state!=='运作中')continue;const eligible=world(c.world).focus;const paid=eligible&&balance>=P.expansion_faith_cost;if(paid)balance-=P.expansion_faith_cost;payments.push({kind:'cult',id:c.world,name:title(c.world),cost:P.expansion_faith_cost,paid,reason:!eligible?'未关注，本轮守持':!paid?'信仰不足，本轮守持':''});}for(const a of S.anchors){const keeper=person(a.keeper);const legal=keeper?.status==='在场'&&cult(a.world)?.state==='运作中'&&relic(a.relic)?.placement==='绑定';const paid=!a.refuse&&legal&&balance>=a.cost;if(paid)balance-=a.cost;payments.push({kind:'anchor',id:a.id,name:title(a.world)+' · '+a.institution,cost:a.cost,paid,loss:a.active?a.contribution:0,reason:a.refuse?'明确停供':!legal?'护持或媒介条件失效':!paid?'信仰不足':''});}return{payments,balance,income:S.cults.reduce((n,c)=>n+income(c),0),loss:payments.filter(p=>p.kind==='anchor'&&!p.paid).reduce((n,p)=>n+p.loss,0)};}
function capacity(){return P.faith_capacity_base+S.peak*P.faith_capacity_per_peak_awakening;}
function rememberSheet(){if(current())current().scroll=document.querySelector('.sheet-body')?.scrollTop||0;}
function open(type,id=null,args={}){rememberSheet();if(!stack.length)lastFocus=document.activeElement;const trigger=document.activeElement;stack.push({type,id,form:{},...args,returnCmd:trigger?.dataset?.cmd,returnArgs:trigger?.dataset?.args});renderLayers();}
function close(){const closed=stack.pop();renderLayers();const target=[...document.querySelectorAll('button[data-cmd]')].find(b=>closed?.returnCmd&&b.dataset.cmd===closed.returnCmd&&b.dataset.args===closed.returnArgs);(target||(!stack.length?lastFocus:null))?.focus?.();}
function current(){return stack[stack.length-1];}
function selectField(name,options,form={},label=fieldNames[name]||name){const value=form[name]??options[0]?.[0]??'';return `<div class="field"><label for="field-${name}">${esc(label)}</label><select id="field-${name}" data-field="${name}">${options.map(([v,t])=>`<option value="${esc(v)}" ${String(value)===String(v)?'selected':''}>${esc(t)}</option>`).join('')}</select></div>`;}
function sectionTitle(t,sub='',buttons=''){return `<div class="stage-title"><div><h1>${esc(t)}</h1><p class="muted">${esc(sub)}</p></div><div class="row">${buttons}</div></div>`;}
function showSheet(title,body,footer='',size='',back=true){return `<div class="veil"><section class="sheet ${size}" role="dialog" aria-modal="true" aria-label="${esc(title)}"><div class="sheet-head">${back&&stack.length>1?B('‹ 返回','close'):''}<h2>${esc(title)}</h2>${back?B('关闭 ×','close'):''}</div><div class="sheet-body" data-scroll-key="sheet">${body}</div>${footer?`<div class="sheet-foot">${footer}</div>`:''}</section></div>`;}
function renderGlobal(){const b=budget();$('global').innerHTML=`<div><b>第 ${S.turn} 回合</b><div class="muted">${({actions:'自由行动',events:'事件处理',between:'轮间',ended:'终局'})[S.phase]}</div></div><div class="metric">低语<b>${S.whispers} / ${S.budget}</b></div><div class="metric">信仰<b>${S.faith} / ${capacity()}</b></div><div class="metric">苏醒<b>${S.awake}</b></div>${B('本体 / 苏醒来源','open',{type:'self'})}${B(`支出与供奉${b.loss?' · 有缺口':''}`,'open',{type:'budget'})}<div class="row">${B(`世界 ${S.worlds.length}`,'open',{type:'worlds'})}${B(`人物 ${S.people.length}`,'open',{type:'people'})}${B('关注与名额','open',{type:'attention'})}${B('暂停','open',{type:'pause'})}</div>`;}
function renderCults(){const list=S.cults.filter(c=>title(c.world).includes(S.cultQuery));$('cults').innerHTML=`<div class="aside-title stack"><div class="between"><h2>教团 ${S.cults.length}</h2>${B('总览','open',{type:'cultList'},false,'mini')}</div><input aria-label="查找教团" placeholder="查找名称" value="${esc(S.cultQuery)}" data-search="cult"></div><div class="aside-scroll" data-scroll-key="cults">${S.cults.length?rows(list.map(c=>`<button class="item full ${c.world===S.selectedCult?'selected':''}" data-cmd="selectCult" data-args='{"id":${c.world}}'><b>${esc(title(c.world))}</b><small>${c.state} · ${c.order} · 收入 ${income(c)}</small>${S.notices.some(n=>n.world===c.world)?'<div class="hint">! 有待留意的变化</div>':''}</button>`)):`<div class="empty"><b>尚无教团</b><span>已有联系与可发起的活动留在中央。</span></div>`}</div><div class="aside-foot">${list.length} / ${S.cults.length} · 列表可滚动</div>`;}
function renderRelics(){const list=S.relics.filter(r=>(r.name+r.id+title(r.world)).includes(S.relicQuery));$('relics').innerHTML=`<div class="aside-title stack"><div class="between"><h2>圣物 ${S.relics.length}</h2>${B('展开','open',{type:'relicList'},false,'mini')}</div><input aria-label="查找圣物" placeholder="查找名称、编号" value="${esc(S.relicQuery)}" data-search="relic"></div><div class="aside-scroll" data-scroll-key="relics">${list.length?rows(list.map(r=>`<button class="item full" data-cmd="open" data-args='${esc(JSON.stringify({type:'relic',id:r.id}))}'><b>${esc(r.name)} ${r.id}</b><small>${r.placement} · ${r.holder?esc(memberName(r.holder)):esc(title(r.world))}</small></button>`)):'<div class="empty">尚无圣物<br>真实取得机会出现时，会从相关事情进入。</div>'}</div><div class="aside-foot">${list.length} / ${S.relics.length} · 独立浏览，物件留在当地</div>`;}
function renderPowers(){$('powers').innerHTML=rows(C.powers.map(p=>B(p.name,'open',{type:'power',id:p.id},false,S.awake<Number(p.unlock_awakening)?'dim':'').replace('</button>',`<small>${S.awake<+p.unlock_awakening?'需苏醒 '+p.unlock_awakening:p.whispers+'低语 · '+p.faith+'信仰'}</small></button>`)));}
function renderChronicle(){$('chronicle').innerHTML=`${B('编年史','open',{type:'history'})}<div class="latest">${rows(S.history.slice(0,2).map(h=>`<div>${h.turn}轮 · ${esc(h.message)}</div>`))}</div>${S.notices.length?B(`危机与期限 ${S.notices.length}`,'open',{type:'notices'}):''}${B('祈求','home',{center:'home'})}${B(S.phase==='between'?'进入下一回合':S.terminal?'本局回顾':'结束回合',S.phase==='between'?'next':S.terminal?'open':'endPreview',S.terminal?{type:'history'}:{},S.phase==='events', 'primary')}`;}
function renderStage(){
 if(S.terminal){$('stage').innerHTML=endingBody();return;}
 if(S.phase==='between'){$('stage').innerHTML=sectionTitle('本轮已经结束','先付支出、世界演化、收入与期限依次处理。')+resultBody()+`<div class="actions">${B('查看编年史','open',{type:'history'})}${B('进入下一回合','next',{},false,'primary')}</div>`;return;}
 const collapse=S.responded?`<div class="between"><span>祈求 · 本轮已回应 1/1，其余仍可查看</span>${B('查看祈求与期限','open',{type:'prayers'},false,'mini')}</div>`:'';
 if(S.center==='cult'&&cult(S.selectedCult)){$('stage').innerHTML=collapse+cultBody(S.selectedCult,true);return;}
 $('stage').innerHTML=sectionTitle('当前联系',S.phase==='events'?'先处理当前事件；已知世界与人物仍可查看。':'回应祈求与发动权能的先后由你决定。')+`<div class="phase-line"><span class="${S.phase==='events'?'current':''}">事件</span><span class="${!S.responded?'current':''}">祈求 / 自由行动</span><span>轮末</span></div>`+collapse+prayerList()+`<div class="divider"></div>`+(S.cults.length?`<div class="between"><h2>持续联系</h2>${B('查看当前教团','selectCult',{id:S.selectedCult||S.cults[0].world})}</div><div class="object-space">${B('教团与具名成员','selectCult',{id:S.selectedCult||S.cults[0].world})}${B('世界总览','open',{type:'worlds'})}${B('圣物与取得机会','open',{type:'relicList'})}</div>`:preCultBody())+noticeSummary();
}
function prayerList(){return `<div class="stack">${rows(S.prayers.map(id=>{const p=C.prayers.find(p=>p.id===id);return `<div class="item between"><div><h3>${esc(p.title)}</h3><p class="muted">${esc(memberName(S.people[0]?.id))} · ${esc(title(S.people[0]?.world||1))} · 请求余 ${p.lifetime} 轮</p></div>${B(S.responded?'查看（本轮只读）':'查看诉求','open',{type:'prayer',id})}</div>`;}))}${!S.prayers.length?'<div class="empty">本轮没有祈求。已有联系仍可主动处置。</div>':''}</div>`;}
function preCultBody(){return `<h2>人物与当前机会</h2><div class="object-space"><div class="object"><b>${esc(memberName('N01'))}</b>${tag(S.people[0]?.bound?'正式成员':'已有联系')}<p>${B('查看人物 / 活动','open',{type:'person',id:'N01'})}</p></div><div class="object"><b>教团尚未形成</b><p>当地信众 ${S.localFollowers} / ${P.cult_form_followers}</p><p>当地实付 ${S.localSpent} / ${P.cult_form_local_spend}</p>${B('查看形成条件','open',{type:'foundation'})}</div></div><div class="row">${B('当前可发起的活动','open',{type:'routes',id:'N01'})}${B('人物与请求线索','open',{type:'people'})}</div>`;}
function noticeSummary(){return `<div class="divider"></div><div class="row"><b>其他地方</b>${rows(S.notices.slice(0,2).map(n=>B(title(n.world)+' · '+n.text,'open',{type:'world',id:n.world},false,'mini')))}</div>`;}
function cultBody(id,main=false){const c=cult(id);if(!c)return '<div class="empty">此处尚无教团。</div>';const ms=S.people.filter(p=>p.cult===c.world&&p.bound);const as=S.anchors.filter(a=>a.world===c.world);return `${main?sectionTitle(title(c.world)+'的教团',`${c.state} · 信众 ${c.followers} · 凝聚 ${c.cohesion}`,B('世界资料','open',{type:'world',id:c.world})):''}<div class="object-space"><div class="object"><b>教团</b><span>成员、活动与变化的共同位置</span></div><div>↔</div><div class="object"><b>具名成员 ${ms.length}</b><span>${esc(ms.map(p=>p.name).join('、'))}</span><p>${B('展开完整成员名册','open',{type:'members',id:c.world})}</p></div><div>↔</div><div class="object"><b>锚点 ${as.length}</b>${B(as.length?'查看护持与媒介':'查看当地机会','open',{type:as.length?'anchors':'opportunities',id:c.world})}</div></div>${c.state!=='运作中'?`<div class="warning">${esc(memberName(c.leader))}无法履职。当前不产收入；连续休眠 ${c.dormant||1} / ${P.cult_dormant_max_turns} 轮。${B('查看成员与继任','open',{type:'members',id:c.world})}</div>`:''}<div class="columns"><div class="block"><h2>本轮指令</h2><div class="order-choice" style="margin:14px 0">${['传教','敛藏','守持'].map(o=>B(o,'order',{id:c.world,order:o},!active()||c.state!=='运作中'||(o==='传教'&&!world(c.world).focus),o===c.order?'active':'')).join('')}</div><p>${c.order==='传教'?'本轮先付2信仰；新增信众受当地余量与领袖影响限制；察觉+2。':c.order==='敛藏'?'收入减半后取整；察觉−2。已经发动的抵抗不会因此撤销。':'正常收入；没有额外招募或指令察觉变化。'}</p><p class="muted">按当前条件预计收入 +${income(c)}，演化后才到账。${!world(c.world).focus?'传教需要取得关注；查看不占关注。':''}</p></div><div class="block"><h2>成员与可发起活动</h2>${rows(ms.slice(0,3).map(p=>`<div class="member-line"><div><b>${esc(p.name)}</b><p class="muted">${esc(p.role)} · ${p.status} · ${p.used?'本轮机会已用':'执行机会未用'}</p></div>${B('查看 / 处置','open',{type:'person',id:p.id},false,'mini')}</div>`))}${B('全部成员与任命','open',{type:'members',id:c.world})}</div></div>${noticeSummary()}`;}
function render(){const positions={};document.querySelectorAll('[data-scroll-key]').forEach(e=>positions[e.dataset.scrollKey]=e.scrollTop);renderGlobal();renderCults();renderRelics();renderPowers();renderStage();renderChronicle();renderLayers();document.querySelectorAll('[data-scroll-key]').forEach(e=>{if(positions[e.dataset.scrollKey])e.scrollTop=positions[e.dataset.scrollKey];});}

function worldList(){const f=current().form;const list=S.worlds.filter(w=>(w.name).includes(f.query||'')&&(!f.filter||f.filter==='全部'||(f.filter==='有教团'&&cult(w.id))||(f.filter==='无教团'&&!cult(w.id))||(f.filter==='关注中'&&w.focus)||(f.filter==='有危机'&&S.notices.some(n=>n.world===w.id))));return `<div class="toolbar"><input aria-label="查找世界" data-field="query" placeholder="名称、编号" value="${esc(f.query||'')}">${selectField('filter',['全部','有教团','无教团','关注中','有危机'].map(v=>[v,v]),f,'筛选')}${B('查找','refresh')}</div><p class="muted">世界 ${S.worlds.length} · 当前筛选 ${list.length}；只包含已得到身份或线索的地方。查看不改变关注。</p><table><thead><tr><th>世界</th><th>教团 / 人物</th><th>锚点</th><th>当前消息</th><th></th></tr></thead><tbody>${rows(list.map(w=>`<tr><td><b>${esc(w.name)}</b><br><small>${w.clue?'仅有请求线索':({planet:'星球',system:'星系',cosmic:'宇宙'})[w.tier]} ${w.focus?'· 关注中':''}</small></td><td>${cult(w.id)?'有教团':'尚无教团'} · ${S.people.filter(p=>p.world===w.id).length} 位可查人物</td><td>${S.anchors.filter(a=>a.world===w.id).length}</td><td>${esc(S.notices.filter(n=>n.world===w.id).map(n=>n.text).join('；')||'未获新消息')}</td><td>${B('查看','open',{type:'world',id:w.id})}</td></tr>`))}</tbody></table>`;}
function worldBody(id){const w=world(id);if(!w)return '<p>尚未获得此处身份。</p>';const profile=C.civilization_profiles.find(p=>p.id===w.profile);return `<div class="between"><div><h3>${esc(w.name)}</h3><p class="muted">${w.clue?'请求所指的地方，其他情况尚未查明':({planet:'星球文明',system:'星系文明',cosmic:'宇宙文明'})[w.tier]}</p></div>${B(w.focus?'关注中 / 释放安排':'关注此处','open',{type:'attention',id:w.id})}</div>${w.clue?'<div class="empty">尚未得知文明、机构与完整人物信息。</div>':`<div class="columns" style="margin-top:18px">${info('文明与情报',`<p>传播背景：${esc(profile.entry_route)}</p><div class="divider"></div><p>屏障：${w.barrier??'未掌握'} · 污染：${w.pollution??'未掌握'}</p><p>察觉：${w.alert??'未掌握'} · 稳定：${w.stability??'未掌握'}</p>${B('逐项查看来源与时间','open',{type:'sources',id:w.id})}`)}${info('这里的联系',`<p>具名人物 ${S.people.filter(p=>p.world===w.id).length} · 圣物 ${S.relics.filter(r=>r.world===w.id).length}</p><div class="row">${B('人物','open',{type:'people',id:w.id})}${B(cult(w.id)?'教团与成员':'当地组织机会','open',{type:cult(w.id)?'cult':'opportunities',id:w.id})}${B('圣物','open',{type:'relicList',id:w.id})}</div>`)}</div><div class="divider"></div><h3>机构与当前依托</h3>${rows(['解释机构','传播机构','秩序机构'].map((n,i)=>{const a=S.anchors.find(a=>a.world===w.id&&a.institution===n);return `<div class="member-line"><div><b>${n}</b><p class="muted">${a?(a.active?'锚点有效':'锚点休眠'):'未建立锚点'} · 当前已获知的机构资料</p></div><div class="row">${B('材料与实践','open',{type:'materials',id:w.id})}${B(a?'查看锚点':'查看建立条件','open',{type:a?'anchor':'anchorConditions',id:a?a.id:w.id})}</div></div>`;}))}`}<div class="divider"></div>${S.notices.filter(n=>n.world===w.id).map(n=>`<div class="warning">${esc(n.text)} ${B('事情与期限','open',{type:'notices'})}</div>`).join('')}`;}
function membersBody(id){const c=cult(id);const ms=S.people.filter(p=>p.bound&&p.cult===Number(id));return `<div class="between"><p>具名成员 ${ms.length} · 无名信众 ${c?.followers||0}（分别计数）</p>${B('任命领袖 / 护持者','open',{type:'power',id:'POWER_APPOINT',form:{cult:String(id)}},!active())}</div>${ms.length?`<table><thead><tr><th>姓名 / 职责</th><th>处境与机会</th><th>已知关联</th><th></th></tr></thead><tbody>${rows(ms.map(p=>`<tr><td><b>${esc(p.name)}</b><br>${esc(p.role)}${p.pending?' · 任命待生效':''}</td><td>${p.status}<br>${p.used?'本轮执行机会已用':'本轮执行机会未用'}</td><td>${esc(S.relics.filter(r=>r.holder===p.id).map(r=>r.name+' '+r.id).join('、')||'无随身圣物')}<br>${S.anchors.filter(a=>a.keeper===p.id).map(a=>'护持'+a.institution).join('、')}</td><td>${B('人物 / 行动','open',{type:'person',id:p.id})}</td></tr>`))}</tbody></table>`:'<div class="empty">没有当前可列出的正式成员。</div>'}<div class="divider"></div><p class="muted">领袖、护持者、祭仪者和普通成员都在同一名册中；失踪、拘禁或离任不会删除已知身份。</p>`;}
function peopleBody(id){const list=S.people.filter(p=>!id||p.world===Number(id));return `<p>正式成员 ${S.people.filter(p=>p.bound).length}/12 · 已有联系但未加入的人物也可查看。</p><div class="list" style="margin-top:15px">${rows(list.map(p=>`<div class="item between"><div><b>${esc(p.name)} · ${esc(title(p.world))}</b><small>${p.bound?'正式成员':'尚未加入'} · ${p.status} · ${esc(p.role)}</small></div>${B('查看','open',{type:'person',id:p.id})}</div>`))}</div>`;}
function personBody(id){const p=person(id);if(!p)return '<p>该人物的身份仍未查明。</p>';const held=S.relics.find(r=>r.holder===p.id);const as=S.anchors.filter(a=>a.keeper===p.id);return `<div class="columns">${info(p.name,`<p>${esc(title(p.world))} · ${p.status}</p><p>${p.bound?'正式成员':'尚未加入'} · ${esc(p.role)}</p><p>忠诚 ${p.loyalty} · 理智 ${p.sanity}</p><p>意志2 · 洞察3 · 影响1 · 适应2</p><p>${p.used?'本轮执行机会已用':'本轮执行机会未用'}</p>${p.pending?`<p>待任命：${esc(p.pending)}，下轮生效</p>`:''}`)}${info('同一人物的关联',`<div class="stack">${B('所在世界','open',{type:'world',id:p.world})}${p.cult?B('所属教团及全体成员','open',{type:'members',id:p.cult}):''}${held?B('携带 '+held.name+' '+held.id,'open',{type:'relic',id:held.id}):'<span>未携带圣物</span>'}${rows(as.map(a=>B('护持 '+a.institution,'open',{type:'anchor',id:a.id})))}</div>`)}</div><div class="divider"></div><h3>当前可发起的操作</h3><div class="row" style="margin:12px 0">${B('发动权能','open',{type:'powerList',person:id})}${B('活动、实践与约定','open',{type:'routes',id})}${B('交予记录','open',{type:'transfer',id},!p.bound||S.people.filter(n=>n.bound&&n.cult===p.cult&&n.id!==id).length===0)}${!p.bound?B('接纳成员','attentionAct',{kind:'enroll',id},!active()):B('确认离团','attentionAct',{kind:'leave',id},!active()||!p.leaveAllowed)}</div>${!p.bound&&!p.devotion?'<p class="muted">接纳需要本人的真实献身依据；忠诚数值不能替代。</p>':''}${p.status!=='在场'?'<div class="warning">当前失能，不能执行任务。仍可查阅关系与已有经历。</div>':''}${B('已知经历与来源','open',{type:'history',person:id})}`;}
function relicList(id){const f=current().form;const rs=S.relics.filter(r=>(!id||r.world===Number(id))&&(!f.query||(r.name+r.id).includes(f.query))&&(!f.placement||f.placement==='全部'||r.placement===f.placement));return `<div class="toolbar"><input aria-label="查找物件" data-field="query" value="${esc(f.query||'')}" placeholder="名称或编号">${selectField('placement',['全部','绑定','携带','保管','扣押','封存','已消耗'].map(x=>[x,x]),f,'状态')}${B('查找','refresh')}${B('查看真实取得机会','open',{type:'opportunities',id})}</div><p class="muted">匹配 ${rs.length} / ${S.relics.length} 件 · 同名物件保留不同身份</p><div class="list">${rows(rs.map(r=>`<div class="item between"><div><b>${esc(r.name)} ${r.id}</b><small>${esc(title(r.world))} · ${r.placement} ${r.holder?'· '+esc(memberName(r.holder)):''}</small></div>${B('查看 / 处置','open',{type:'relic',id:r.id})}</div>`))}${!rs.length?'<div class="empty">当前没有符合条件的物件。</div>':''}</div>`;}
function relicBody(id){const r=relic(id);if(!r)return '<p>物件尚未取得完整信息。</p>';const t=C.relics.find(t=>t.id===r.type);const a=S.anchors.find(a=>a.relic===r.id);return `<div class="object-space"><div class="object"><b>${esc(r.name)} ${r.id}</b><span>${r.placement}</span></div><div><p>${esc(title(r.world))}</p>${r.holder?B(memberName(r.holder),'open',{type:'person',id:r.holder}):''}${a?B(a.institution+' · '+memberName(a.keeper),'open',{type:'anchor',id:a.id}):''}</div></div><div class="columns">${info('用途与代价',`<p>${esc(t.carry_effect)}</p><p>${esc(t.carry_cost)}</p><p class="muted">绑定时不同时作为随身准备；搬运需要实际通路。</p>`)}${info('当前处置',`<div class="stack">${B('携带','open',{type:'relicAction',id,action:'equip'},!active()||r.placement!=='保管')}${B('卸下','open',{type:'relicAction',id,action:'unequip'},!active()||r.placement!=='携带')}${B('解绑：锚点将立即休眠','open',{type:'relicAction',id,action:'unbind'},!active()||r.placement!=='绑定')}${B('解离：永久消耗物件','open',{type:'relicAction',id,action:'disassemble'},!active()||!['保管','携带'].includes(r.placement))}${B('查看回收机会','open',{type:'opportunities',id:r.world})}</div>`)}</div>${['扣押','封存'].includes(r.placement)?'<div class="warning">已失去自由处置资格；必须有真实回收机会或等待封存解除，不能直接取回。</div>':''}<div class="divider"></div>${B('来源与历史','open',{type:'sources',relic:id})}`;}
function anchorBody(id){const a=S.anchors.find(a=>a.id===id);if(!a)return '<p>尚未建立。</p>';return `<h3>${esc(title(a.world))} · ${a.institution}</h3><p>状态：${a.active?'有效':'休眠'} · 当前贡献 ${a.active?a.contribution:0} · 每轮供奉 ${a.cost}</p><div class="object-space">${B(memberName(a.keeper),'open',{type:'person',id:a.keeper})} ↔ ${B(relic(a.relic)?.name+' '+a.relic,'open',{type:'relic',id:a.relic})}</div><div class="row">${B('供奉顺序 / 拒付','open',{type:'budget'})}${B('查看维持条件','open',{type:'anchorConditions',id:a.world})}${B('更换护持者','open',{type:'power',id:'POWER_APPOINT',form:{cult:String(a.world),office:'护持者',anchor:a.id}},!active())}${!a.active?B('查看修复锚定','open',{type:'power',id:'POWER_ANCHOR',form:{world:String(a.world)}}):''}</div><p class="muted" style="margin-top:16px">仅停供或临时失去条件时，条件恢复且实际付费才恢复；结构被毁、更换媒介或护持者可能需要重新锚定。</p>`;}
function budgetBody(){const b=budget();return `<div class="flow"><b>现有信仰 ${S.faith}</b><span>→</span><b>先传教</b><span>→</span><b>再供奉</b><span>→</span><b>演化</b><span>→</span><b>收入与期限</b></div><p class="muted">预计收入 ${b.income} 在演化后到账，不能用于此前支出。当前苏醒 ${S.awake}；只修改安排不会立即扣除贡献。</p><table><thead><tr><th>对象 / 次序</th><th>应付</th><th>按当前余额的结果</th><th>安排</th></tr></thead><tbody>${rows(b.payments.map(p=>`<tr><td>${esc(p.name)}</td><td>${p.cost}</td><td>${p.paid?'可支付':esc(p.reason)}${!p.paid&&p.kind==='anchor'?` · 实际结算时苏醒−${p.loss}`:''}</td><td>${p.kind==='cult'?B('调整教团指令','open',{type:'cult',id:p.id}):`${B('↑','moveAnchor',{id:p.id,delta:-1},!active(), 'mini')}${B('↓','moveAnchor',{id:p.id,delta:1},!active(),'mini')}${B(S.anchors.find(a=>a.id===p.id).refuse?'恢复供奉':'本轮停供','toggleAnchor',{id:p.id},!active(),'mini')}`}</td></tr>`))}</tbody></table><div class="warning">按当前安排：付后余 ${b.balance}；预计苏醒 ${S.awake} → ${Math.max(0,S.awake-b.loss)}。${b.loss?'存在供奉缺口或停供项。':'当前安排无供奉缺口。'}</div><div class="divider"></div>${noticeSummary()}`;}
function attentionBody(id){const focused=S.worlds.filter(w=>w.focus);return `<div class="columns">${info('关注世界 '+focused.length+'/3',`${rows(focused.map(w=>`<div class="member-line"><div>${esc(w.name)}<small>${S.releaseFocus.includes(w.id)?' · 下轮释放已安排':''}</small></div>${B('下轮释放','attentionAct',{kind:'release_focus',id:w.id},!active()||S.releaseFocus.includes(w.id),'mini')}</div>`))}${id&&!world(id)?.focus?B('关注 '+title(id),'attentionAct',{kind:'focus',id},!active()||focused.length>=3):''}<p class="muted">查看不改变关注。释放不会立即腾出本轮名额；持续任务可能阻止释放。</p>`)}${info('人物名额',`<p>正式成员 ${S.people.filter(p=>p.bound).length}/12</p><p>当前请求与事件人物 ${S.people.filter(p=>!p.bound).length}/12</p>${B('查看全部人物与职责','open',{type:'people'})}<p class="muted">正式成员包含领袖、护持者及其他成员；接纳和离开必须有对应依据。</p>`)}</div><div class="divider"></div><h3>尚未使用的活动预留</h3>${rows(S.reservations.map(r=>`<div class="member-line"><span>${esc(r.text)}</span>${B('释放此预留','attentionAct',{kind:'release_project',id:r.id},!active()||!r.releasable)}</div>`))}${!S.reservations.length?'<p>没有可释放的未用活动预留。</p>':''}`;}
function routesBody(id){return `<p>当前人物：${esc(memberName(id||S.people[0]?.id))}。活动从人物、世界材料与真实机会进入；不是一套额外权能。</p><div class="list">${rows(ROUTES.map(r=>`<div class="item between"><div><b>${esc(r.name)}</b><small>${r.id==='ROUTE_GUIDED_DREAM'?'使用既有入梦权能':r.id==='ROUTE_PACT_PERFORMANCE'?'回到固定祈求的深应，仍受每轮一次回应限制':r.repeat_turns?'需要跨不同回合实际完成':'按当前参与者与来源选择'}</small></div>${B('查看条件 / 准备','open',{type:'route',id:r.id,person:id})}</div>`))}</div>`;}
function materialsBody(id){return `<h3>${esc(title(id||S.selectedCult||1))} · 已知材料与实践</h3><div class="object-space"><div class="object"><b>原始见证记录</b><span>有原记录者与来源；副本不等于新见证。</span></div><div class="object"><b>当前实践</b><span>完成 1 / 2 个不同回合</span></div></div><div class="row">${B('查看来源与参加者','open',{type:'sources',id})}${B('实际开展活动','open',{type:'routes',id:S.people.find(p=>p.world===Number(id))?.id||S.people[0]?.id})}${B('交予记录','open',{type:'transfer',id:S.people.find(p=>p.world===Number(id))?.id||S.people[0]?.id})}</div><p class="muted">记录、原参加者、真实实践、机构当前使用和知情分别判断。读到一份材料不自动取得持续依托。</p>`;}
function opportunitiesBody(id){return `<p>只列已获知的实际机会；没有物件不提前出现处置菜单。</p><div class="block"><h3>解释机构留下的媒介</h3><p>${esc(title(id||S.selectedCult||1))} · 当前已知依托产生的首次机会</p><p>回收、公开或等待会各自产生不同后果；先预览费用与归属。</p><div class="row">${['回收','公开','等待'].map((x,i)=>B(x,'opportunity',{world:id||S.selectedCult||1,choice:['recover','public','wait'][i]},!active())).join('')}</div></div><div class="divider"></div>${B('查看当前建立 / 维持条件','open',{type:'anchorConditions',id:id||S.selectedCult||1})}`;}
function prayerBody(id){const p=C.prayers.find(p=>p.id===id);const actor=S.people[0];return `<div class="between"><div><h3>${esc(p.title)}</h3><p>${esc(actor?.name)} · ${esc(title(actor?.world||1))}</p></div>${B('查看求告人','open',{type:'person',id:actor?.id})}</div><div class="warning" style="margin:16px 0">请求窗口剩余 ${p.lifetime} 轮；原危机期限单独记录。${S.responded?'本轮回应机会已用，本请求只读。':''}</div><div class="columns">${info('浅触',`<p>${esc(p.shallow_gain)}</p><p class="muted">始终代价：${esc(p.shallow_cost)}</p><p>1低语 · 0信仰</p>${B('准备浅触回应','preparePrayer',{id,variant:'shallow'},!active()||S.responded)}`)}${info('深应',`<p>${esc(p.deep_gain)}</p><p class="muted">始终代价：${esc(p.deep_cost)}</p><p>2低语 · 4信仰</p>${B('准备深应回应','preparePrayer',{id,variant:'deep'},!active()||S.responded)}`)}</div><div class="actions">${B('先做准备 / 发动权能','open',{type:'powerList',person:actor?.id})}${B('保持未回应，返回','close')}</div>`;}
function formOptions(key,form={}){
 const w=Number(form.world||form.cult||S.selectedCult||S.people[0]?.world||1),local=S.people.filter(p=>p.world===w&&p.bound);
 const allPeople=S.people.map(p=>[p.id,`${p.name} · ${title(p.world)} · ${p.status}${p.used?' · 本轮已执行':''}`]);
 switch(key){
 case 'person':return allPeople;
 case 'other':case 'recipient':return S.people.filter(p=>p.bound&&p.cult===person(form.person||current()?.id)?.cult&&p.id!==(form.person||current()?.id)&&p.status==='在场').map(p=>[p.id,p.name]);
 case 'keeper':return (form.cosmic?S.people.filter(p=>p.id===S.anchors.find(a=>a.id===form.cosmic)?.keeper):local).map(p=>[p.id,p.name+' · '+p.role]);
 case 'world':case 'cult':return S.cults.map(c=>[c.world,title(c.world)]);
 case 'destination':return S.cults.filter(c=>c.world!==person(form.person)?.world&&[1,4,7].includes(c.world)).map(c=>[c.world,title(c.world)+' · 已有通路与接收教团']);
 case 'cosmic':case 'system':return S.anchors.filter(a=>world(a.world)?.tier===key&&a.active).map(a=>[a.id,title(a.world)+' · '+a.institution]);
 case 'anchor':return S.anchors.filter(a=>a.world===w).map(a=>[a.id,a.institution+' · '+(a.active?'有效':'休眠')]);
 case 'relic':return S.relics.filter(r=>r.world===w&&['保管','携带'].includes(r.placement)).map(r=>[r.id,r.name+' '+r.id+' · '+r.placement]);
 case 'institution':return ['解释机构','传播机构','秩序机构'].map(x=>[x,x]);
 case 'attribute':return ['意志','洞察','影响','适应'].map(x=>[x,x]);
 case 'office':return ['领袖','护持者'].map(x=>[x,x]);
 case 'sacrifice':return [['faith','信仰'],['insight','洞见（须独特见证）'],['heal','愈合创伤']];
 case 'mode':return [['faith','化为信仰'],['insight','化为洞见'],['followers','化为当地信众'],['whispers','释放低语']];
 case 'followers':return [0,1,2,3,4].map(x=>[x,x+' 人']);
 case 'purpose':return C.powers.filter(p=>!['POWER_LISTEN','POWER_ORACLE'].includes(p.id)).map(p=>[p.id,p.name]);
 case 'preparation':return [['none','不用准备'],['oracle','已为此人、此行动留下的神谕'],...S.relics.filter(r=>r.placement==='携带'&&(!form.person||r.holder===form.person)).map(r=>[r.id,r.name+' '+r.id+' · 符合用途时才可用'])];
 case 'stage':return [['prepare','建立本次共同情境 / 约定'],['perform','完成当前一段实际实践']];
 default:return [['known','本次已知、当前仍有效的'+(fieldNames[key]||key)]];
 }
}
function fields(keys,form){return `<div class="columns">${keys.map(k=>selectField(k,formOptions(k,form),form)).join('')}</div>`;}
function powerBody(id){const p=C.powers.find(p=>p.id===id),f=current().form;if(!p)return '<p>权能不存在。</p>';return `<div class="between"><h3>${p.name}</h3><b>${p.whispers}低语 · ${p.faith}信仰</b></div><p>${esc(p.target_requirement)}</p>${S.awake<+p.unlock_awakening?`<div class="warning">需要当前苏醒 ${p.unlock_awakening}；当前为 ${S.awake}。说明保留，暂不能执行。</div>`:''}${fields(powerFields[id],f)}<details><summary>始终代价与可能后果</summary><p>${esc(p.always_cost)}</p><p>成功：${esc(p.success)}</p><p>失败：${esc(p.failure)}</p><p>灾变：${esc(p.disaster)}</p></details><div class="actions">${B('检查资格与预览','preview',{kind:'power',id},!active(),'primary')}</div>`;}
function routeBody(id){const r=ROUTES.find(r=>r.id===id),f=current().form;if(!f.person)f.person=current().person||S.people[0]?.id;const special=r.id==='ROUTE_GUIDED_DREAM'||r.id==='ROUTE_PACT_PERFORMANCE';return `<h3>${r.name}</h3><p>${esc(r.rationale.split('；')[0])}</p>${special?`<div class="warning">${r.id==='ROUTE_GUIDED_DREAM'?'通过既有入梦权能执行，不新增一套费用。':'通过固定祈求的深应执行；已回应后不能绕开本轮限制。'}</div>${B('进入对应操作','routeAlias',{id,person:f.person})}`:`${fields(['person',...(Number(r.participants_max)>1?['other']:[]),'source',...(['memory_circle','reciprocal_covenant'].includes(r.mode)?['stage']:[])],f)}${r.repeat_turns?'<div class="warning">当前显示的是跨轮过程中的一步；同轮重复不能完成另一轮实践。</div>':''}<div class="actions">${B('检查资格与预览','preview',{kind:'route',id},!active(),'primary')}</div>`}`;}
function transferBody(id){const f=current().form;if(!f.person)f.person=id||S.people[0]?.id;const options=formOptions('recipient',f);return `<p>转交一份记录或其准确知识，不增加见证人数、实践次数或契约责任。</p>${fields(['person','recipient','record'],f)}${!options.length?'<div class="warning">没有同一教团、在场且具有当前接触条件的其他正式成员。</div>':'<p>同一持续教团的已知联系；接收者须仍有资格。</p>'}<p>1低语 · 0信仰</p><div class="actions">${B('预览转交','preview',{kind:'transfer',id:f.person},!active()||!options.length,'primary')}</div>`;}
function relicActionBody(id,action){const r=relic(id);const f=current().form;const names={equip:'携带',unequip:'卸下',unbind:'解绑',recover:'回收',disassemble:'解离'};return `<h3>${names[action]} ${esc(r.name)} ${r.id}</h3>${action==='equip'?selectField('person',S.people.filter(p=>p.world===r.world&&p.status==='在场'&&!S.relics.some(q=>q.holder===p.id)).map(p=>[p.id,p.name]),f,'由谁携带'):''}${action==='disassemble'?selectField('mode',formOptions('mode'),f):''}<p>${action==='unbind'?'对应锚点立即休眠；贡献随绑定失效立即失去。':action==='disassemble'?'四种用途互斥；永久消耗这一件物品。':'按当前所在地和资格处置，不在世界间自动传送。'}</p><div class="actions">${B('查看代价与后果','preview',{kind:'relic',id,action},!active(),'primary')}</div>`;}
function eventBody(){const id=S.eventIds.find(id=>!S.eventResolved.includes(id));if(!id)return '';const e=C.events.find(e=>e.id===id),effects=C.event_effects.filter(x=>x.event_id===id&&x.status==='active');return `<h3>${esc(e.title)}</h3><p class="muted">${esc(title(S.selectedCult||1))} · 本轮未处理事件 ${S.eventIds.length-S.eventResolved.length}</p><div class="row" style="margin:14px 0">${B('相关世界','open',{type:'world',id:S.selectedCult||1})}${B('相关人物','open',{type:'people',id:S.selectedCult||1})}${B('已知前因','open',{type:'sources'})}</div>${effects.map(x=>B((x.option==='A'?e.choice_a:e.choice_b)+` · ${x.faith_cost}信仰`,'eventPreview',{id,option:x.option},S.faith<+x.faith_cost,'choice').replace('</button>',`<small>${esc(x.on_choose)}<br>代价：${esc(x.irreversible_cost)}</small></button>`)).join('')}<p class="muted">资源不足时仍可选择零费用的承受分支。处理前自由行动暂停，信息仍可查。</p>`;}
function noticesBody(){return `<div class="list">${rows(S.notices.map(n=>`<div class="item"><h3>${esc(title(n.world))}</h3><p>${esc(n.text)}</p><div class="row">${B('查看相关世界','open',{type:'world',id:n.world})}${n.relic?B('查看媒介','open',{type:'relic',id:n.relic}):''}${B('已知来源','open',{type:'sources',id:n.world})}</div></div>`))}${!S.notices.length?'<div class="empty">尚未收到迫近后果的消息。</div>':''}</div>`;}
function historyBody(){return `<p class="muted">只回顾已知事实。结果、支付和前因分开；未知原因不会补成故事。</p><div class="list" style="margin-top:15px">${rows(S.history.map((h,i)=>`<div class="item"><b>第 ${h.turn} 回合</b><p>${esc(h.message)}</p><div class="row">${rows((h.links||[]).map(l=>B(({world:'相关世界',person:'相关人物',relic:'相关圣物',budget:'支出记录'})[l.type]||'查看相关对象','open',l,false,'mini')))}${B('展开已知前因','open',{type:'historyFact',id:i},false,'mini')}</div></div>`))}</div>`;}
function selfBody(){const contributions=S.anchors.filter(a=>a.active).reduce((n,a)=>n+a.contribution,0);return `<h3>当前苏醒 ${S.awake}</h3><p>初生自我 ${P.initial_awakening} + 洞见 ${S.insight} + 有效锚点 ${contributions} − 创伤 ${S.wounds}</p><p>历史峰值 ${S.peak} · 信仰容量 ${capacity()}</p><div class="divider"></div><h3>敛息</h3><p>消耗6信仰，恢复至多3创伤，封闭本轮余下行动；世界仍继续演化。</p>${S.responded||S.usedAction?'<div class="warning">本轮已回应或使用过权能／圣物，不能再敛息。</div>':''}${B('预览敛息','preview',{kind:'rest'},!active()||S.responded||S.usedAction||S.wounds<=0)}<div class="divider"></div>${S.manifest?manifestBody():`<p>降临尚未开始。</p>${B('查看降临条件','open',{type:'power',id:'POWER_MANIFEST'})}`}`;}
function manifestBody(){const m=S.manifest;if(!m)return '<p>当前没有进行中的降临。</p>';const keeper=person(m.keeper);return `<h3>降临 · 第 ${m.step} / 3 轮</h3><p>${m.paid?'本轮费用已付，等待轮末核验':'本轮尚未续付'} · 护持者 ${esc(keeper?.name||'已失效')}</p><p>持续需要：原宇宙与星系锚点、原护持者、关注与当轮执行机会。</p><p>${m.step<3?'本轮不是最终检定，不提前显示完成结果。':'本轮续付后，在轮末进行最终检定及存续核验。'}</p><div class="row">${B('继续降临 · 3低语 / 8信仰','preview',{kind:'manifest',action:'continue'},!active()||m.paid)}${B('中止降临','preview',{kind:'manifest',action:'cancel'},!active())}${B('检查依赖','open',{type:'anchors'})}</div>`;}
function endingBody(){return sectionTitle(S.terminal==='victory'?'你已苏醒':'本次联系已终止',S.terminal==='victory'?'终极仪式完成。':'苏醒归零或联系最终断绝，按实际终局原因回顾。')+`<div class="object-space"><div class="object"><b>终局 ${S.terminal==='victory'?'苏醒':'寂灭'}</b><p>回合 ${S.turn} · 当前苏醒 ${S.awake}</p></div></div><div class="row">${B('本局编年史','open',{type:'history'})}${B('世界与人物回顾','open',{type:'worlds'})}${B('查看最终支出','open',{type:'budget'})}${B('返回开始界面','open',{type:'start'})}</div><p class="muted" style="margin-top:18px">本局只读；不再推进普通回合或操作人物、圣物。</p>`;}
function resultBody(){return S.result?`<div class="inline-result"><h2>${esc(S.result.title)}</h2><p class="long" style="margin-top:12px">${esc(S.result.text)}</p><div class="row" style="margin-top:14px">${rows((S.result.links||[]).map(l=>B('查看'+({world:'世界',person:'人物',relic:'圣物',budget:'收支'})[l.type],'open',l)))}</div></div>`:'<p>没有新的结算记录。</p>';}
function renderLayers(){
 const priorId=document.activeElement?.id;
 if(!stack.length){$('layers').innerHTML=S.phase==='events'?showSheet('当前事件',eventBody(),'', '',false):'';syncModal(priorId);return;}
 const x=current();let body='',name='',size='';
 switch(x.type){
 case 'worlds':name='世界总览';body=worldList();size='wide';break;
 case 'world':name='世界资料';body=worldBody(x.id);break;
 case 'sources':name='已知来源与获知时间';body=`<div class="trace"><b>所选对象的公开事实</b><p>第${S.turn-1}轮 · 来自真实行动或消息。</p></div><div class="trace"><b>当前数值与条件</b><p>每项单独保留来源和获知时间，失效事实只供回顾。</p></div><div class="empty">尚未获知的前因<br>不推测、不显示隐藏人物或条目数量。</div>`;break;
 case 'cultList':name='教团总览';body=`<div class="list">${S.cults.map(c=>`<div class="item between"><span>${esc(title(c.world))} · ${c.state} · ${c.order}</span><div class="row">${B('查看成员','open',{type:'members',id:c.world})}${B('带到主场景','selectCult',{id:c.world})}</div></div>`).join('')}</div>`;break;
 case 'cult':name=title(x.id)+'的教团';body=cultBody(x.id);break;
 case 'members':name=title(x.id)+' · 全体具名成员';body=membersBody(x.id);break;
 case 'people':name=x.id?title(x.id)+'的人物':'人物与成员';body=peopleBody(x.id);break;
 case 'person':name='人物详情与当前操作';body=personBody(x.id);break;
 case 'relicList':name='圣物总览';body=relicList(x.id);break;
 case 'relic':name='圣物详情';body=relicBody(x.id);break;
 case 'relicAction':name='准备圣物操作';body=relicActionBody(x.id,x.action);break;
 case 'anchor':name='锚点、护持与媒介';body=anchorBody(x.id);break;
 case 'anchors':name='锚点总览';body=S.anchors.map(a=>`<div class="member-line"><span>${esc(title(a.world))} · ${a.institution} · ${a.active?'有效':'休眠'}</span>${B('查看依赖','open',{type:'anchor',id:a.id})}</div>`).join('')||'<div class="empty">尚无锚点，当前不产生供奉安排。</div>';break;
 case 'anchorConditions':name='当前建立 / 维持条件';body=`<p>${esc(title(x.id))} · 固定机构与原依托</p><div class="steps"><div class="step">教团：至少12无名信众、凝聚40</div><div class="step">本地合格护持者与一件未绑定圣物</div><div class="step">污染门槛按机构固定序号检查；缺少情报时只显示已获知的资格结论</div><div class="step">真实的当前机构依托、原参加者和材料仍有效</div><div class="step">成功后待本轮实际供奉，才产生苏醒贡献</div></div><div class="row">${B('查看依托与材料','open',{type:'materials',id:x.id})}${B('准备锚定','open',{type:'power',id:'POWER_ANCHOR',form:{world:String(x.id)}})}</div>`;break;
 case 'budget':name='本轮支出与锚点供奉';body=budgetBody();size='wide';break;
 case 'attention':name='关注、成员与未用预留';body=attentionBody(x.id);break;
 case 'routes':name='当前活动、实践与约定';body=routesBody(x.id);break;
 case 'route':name='准备实际活动';body=routeBody(x.id);break;
 case 'materials':name='记录、实践与依托';body=materialsBody(x.id);break;
 case 'transfer':name='交予记录';body=transferBody(x.id);break;
 case 'opportunities':name='实际已知机会';body=opportunitiesBody(x.id);break;
 case 'prayers':name='本轮祈求';body=prayerList();break;
 case 'prayer':name='诉求与回应';body=prayerBody(x.id);break;
 case 'prayerSetup':name='准备回应';body=`<p>${esc(C.prayers.find(p=>p.id===x.id).title)} · ${x.variant==='deep'?'深应':'浅触'}</p>${fields(['person','source','preparation'],x.form)}<p class="muted">代理须有当前真实委托；没有合法代理时采用原求告者，不凭空换人。</p><div class="actions">${B('检查回应资格','preview',{kind:'prayer',id:x.id,variant:x.variant},S.responded||!active(),'primary')}</div>`;break;
 case 'power':name='准备权能';body=powerBody(x.id);break;
 case 'powerList':name='选择权能';body=`<div class="columns">${C.powers.map(p=>B(`${p.name} · ${p.whispers}低语 / ${p.faith}信仰`,'open',{type:'power',id:p.id,form:{person:x.person||S.people[0]?.id}},false,'choice')).join('')}</div>`;break;
 case 'preview':name='执行前预览';body=previewBody();break;
 case 'confirm':name='不可逆后果确认';body=confirmBody();size='narrow';break;
 case 'result':name='实际结果';body=resultBody()+`<div class="actions">${B('返回刚才的位置','close',{},false,'primary')}</div>`;break;
 case 'notices':name='危机、调查与期限';body=noticesBody();break;
 case 'history':name='编年史';body=historyBody();break;
 case 'historyFact':name='已知前因与实际变化';body=`<div class="trace"><h3>${esc(S.history[x.id]?.message||'既存记录')}</h3><p>支付与变化分别记录；原身份保持。</p></div><div class="trace">已知前因：本轮实际选择。</div><div class="empty">更早原因尚未获知。</div>`;break;
 case 'self':name='本体、苏醒与恢复';body=selfBody();break;
 case 'manifest':name='进行中的降临';body=manifestBody();break;
 case 'foundation':name='首团形成条件';body=`<div class="steps"><div class="step">已有自愿献身、合格且可接纳的领袖</div><div class="step">当地无名信众 ${S.localFollowers}/${P.cult_form_followers}</div><div class="step">当地实际支出 ${S.localSpent}/${P.cult_form_local_spend}</div><div class="step">轮末核验自然形成；不再额外支付一次“建立教团”费</div></div>${B('从人物发起实际活动','open',{type:'routes',id:S.people[0]?.id})}`;break;
 case 'end':name='结束回合前';body=budgetBody()+`<div class="divider"></div>${S.manifest&&!S.manifest.paid?'<div class="warning">本轮降临尚未续付，结束后将中断。</div>':''}<p>提交后本轮计划锁定。已执行行为不回滚；未回应祈求与危机按各自期限处理。</p><div class="actions">${B('继续行动','close')}${B('锁定计划并结束回合','settle',{},!active(),'primary')}</div>`;size='wide';break;
 case 'pause':name='暂停';body=`<div class="stack">${B('继续','close')}${B('保存演示进度','save')}${B('读取演示进度','load')}${B('开始 / 继续界面','open',{type:'start'})}${B('放弃本局','preview',{kind:'abandon'},!!S.terminal)}</div><p class="muted" style="margin-top:16px">结构原型保存于本浏览器，独立于正式游戏存档。</p>`;size='narrow';break;
 case 'start':name='开始与继续';body=`<div class="empty"><h1>邪神苏醒</h1><div class="row">${B('新局','newGame',{},false,'primary')}${B('继续演示存档','load')}${B('返回当前局','close')}</div></div>`;break;
 case 'saveError':name='存档未能载入';body='<div class="warning">格式或版本不匹配。当前局保持不变，没有覆盖当前进度。</div>'+B('返回','close');break;
 case 'guide':name='流程与机制覆盖 · 原型外导览';body=guideBody();size='wide';break;
 default:name='尚未设计的入口';body='<p>该入口尚未配置。</p>';
 }
 $('layers').innerHTML=showSheet(name,body,'',size);
 const sheet=document.querySelector('.sheet-body');if(sheet)sheet.scrollTop=x.scroll||0;
 syncModal(priorId);
}
function syncModal(priorId){const dialog=document.querySelector('.sheet');for(const id of ['global','cults','stage','relics','powers','chronicle'])$(id).inert=!!dialog;if(dialog){const target=priorId&&dialog.querySelector('#'+priorId);(target||dialog.querySelector('button:not([disabled]),select,input'))?.focus?.();}}

function collect(){const f={...current()?.form};document.querySelectorAll('[data-field]').forEach(e=>f[e.dataset.field]=e.type==='checkbox'?e.checked:e.value);return f;}
function routeCost(r,f){if(r.cost_rule==='foundation_private')return[P.private_whispers,P.private_faith];if(r.cost_rule==='foundation_joint_work')return[P.joint_work_whispers,P.joint_work_faith];if(r.cost_rule==='foundation_gathering')return[P.gathering_whispers,P.gathering_faith];if(r.cost_rule==='memory_contract_preparation'||f.stage==='prepare')return[P.preparation_whispers,P.preparation_faith];return[P.prayer_deep_whispers,P.prayer_deep_faith];}
function makePlan(args,f={}){
 const plan={...args,form:clone(f),whispers:0,faith:0,title:'',always:[],changes:[],errors:[],irreversible:false,probabilistic:false,originDepth:stack.length};
 if(args.kind==='power'){
  const p=C.powers.find(p=>p.id===args.id);Object.assign(plan,{title:p.name,whispers:+p.whispers,faith:+p.faith,probabilistic:p.check_kind!=='deterministic'&&p.id!=='POWER_MANIFEST'});plan.always=[p.always_cost];plan.changes=[p.success];if(S.awake<+p.unlock_awakening)plan.errors.push('当前苏醒未达 '+p.unlock_awakening);
  const actor=person(f.person||f.keeper);if(powerFields[p.id].some(k=>['person','keeper'].includes(k))&&!actor)plan.errors.push('尚未选定合格人物');if(actor&&actor.status!=='在场')plan.errors.push('人物当前'+actor.status+'，不能承担行动');
  if(actor&&!actor.bound&&!['POWER_DREAM','POWER_LISTEN'].includes(p.id))plan.errors.push('需要正式成员资格；忠诚本身不等于加入');
  if(actor?.used&&['POWER_BREACH','POWER_SEED','POWER_ANCHOR','POWER_VEIL','POWER_TRANSFER','POWER_MANIFEST'].includes(p.id))plan.errors.push('执行者本轮机会已用');
  if(['POWER_BREACH','POWER_SEED','POWER_ANCHOR','POWER_VEIL'].includes(p.id)&&!world(Number(f.world||f.cult||actor?.world))?.focus)plan.errors.push('当前需要此世界的关注资格；请查看关注与名额');
  if(p.id==='POWER_DREAM'&&actor?.dreamTurn===S.turn)plan.errors.push('同一人物的入梦仍在冷却');
  if(p.id==='POWER_BESTOW'&&actor?.bestowed)plan.errors.push('此人已获得过永久赐予');
  if(p.id==='POWER_APPOINT'&&actor?.world!==Number(f.cult))plan.errors.push('人物必须在所选教团所在世界');
  if(p.id==='POWER_SACRIFICE'){plan.irreversible=true;if((actor?.tenure||0)<P.sacrifice_min_tenure)plan.errors.push('入团不足3轮');plan.always.unshift('无论结果如何，目标都会死亡，并失去其职位与护持。');}
  if(p.id==='POWER_TRANSFER'){plan.irreversible=true;if(!f.destination)plan.errors.push('没有实际可达的接收教团');}
  if(p.id==='POWER_ANCHOR'){
   const w=Number(f.world),c=cult(w),r=relic(f.relic);if(!c||c.followers<12||c.cohesion<40)plan.errors.push('教团人数或凝聚不足');if(!r||!['携带','保管'].includes(r.placement)||r.world!==w)plan.errors.push('没有当地合法、未绑定的圣物');if(S.anchors.some(a=>a.keeper===f.keeper))plan.errors.push('此人正在护持其他锚点');if(S.anchors.some(a=>a.world===w&&a.institution===f.institution&&a.active))plan.errors.push('所选机构已有有效锚点');plan.changes.push('成功先成为待供奉的休眠锚点；12信仰为行动费，维持费在轮末另付。');
  }
  if(p.id==='POWER_MANIFEST'){if(!f.cosmic||!f.system||!f.keeper)plan.errors.push('需要有效宇宙锚点、星系锚点与原护持者');if(S.manifest)plan.errors.push('已有进行中的降临，请从持续仪式入口继续');plan.changes=['开启第1轮仪式，尚不进行最终检定；之后需逐轮续付并保持依赖。'];}
 }else if(args.kind==='prayer'){
  const p=C.prayers.find(p=>p.id===args.id),deep=args.variant==='deep';plan.title=p.title+' · '+(deep?'深应':'浅触');plan.whispers=deep?P.prayer_deep_whispers:P.prayer_shallow_whispers;plan.faith=deep?P.prayer_deep_faith:P.prayer_shallow_faith;plan.probabilistic=true;plan.always=[p[deep?'deep_cost':'shallow_cost'],'无论成功与否，本轮回应机会用尽。'];plan.changes=[p[deep?'deep_gain':'shallow_gain']];if(S.responded)plan.errors.push('本轮已经回应过一次祈求');
 }else if(args.kind==='route'){
  const r=ROUTES.find(r=>r.id===args.id);[plan.whispers,plan.faith]=routeCost(r,f);plan.title=r.name;plan.probabilistic=r.check_rule!=='deterministic';plan.always=[`实际执行当前活动；${r.always_alert?'察觉增加'+r.always_alert+'；':''}${r.always_sanity_loss?'理智降低'+r.always_sanity_loss+'；':''}本人的执行机会按活动资格占用。`];plan.changes=[r.mode==='covert_gathering'?'从当地现存非信众转化至多3人，污染+1；首团条件留到轮末检查。':r.repeat_turns?'产生本回合的真实实践；尚缺另一回合时保留过程。':'产生当前活动的实际结果与有源记录，不自动完成其他步骤。'];const p=person(f.person);if(!p||p.status!=='在场'||p.used)plan.errors.push('参与者不在场或本轮已执行');if(!p?.bound&&r.mode!=='private_devotion')plan.errors.push('当前活动需要相应的成员资格');if(p&&p.practiceTurn===S.turn&&r.repeat_turns)plan.errors.push('此实践需要不同回合，不能本轮重复补齐');if(Number(r.participants_max)>1&&!f.other)plan.errors.push('缺少另一位具备当前实际联系的参加者');
 }else if(args.kind==='transfer'){
  plan.title='交予记录';plan.whispers=P.internal_whispers_cost;plan.faith=P.internal_faith_cost;plan.changes=['接收者获得这一记录的指定副本或准确知识；不增加独立见证或实践次数。'];const a=person(f.person),b=person(f.recipient);if(!a||!b||a.id===b.id||!a.bound||!b.bound||a.cult!==b.cult||a.world!==b.world||a.status!=='在场'||b.status!=='在场')plan.errors.push('发送者与接收者须为同团、同地、在场的不同正式成员，并有当前接触来源');
 }else if(args.kind==='relic'){
  const r=relic(args.id),t=C.relics.find(t=>t.id===r?.type);plan.title=({equip:'携带',unequip:'卸下',unbind:'解绑',recover:'回收',disassemble:'解离'})[args.action]+' '+(r?.name||'圣物')+' '+args.id;plan.whispers=args.action==='disassemble'&&f.mode==='whispers'?0:P.relic_operation_whispers;
  if(!r||r.placement==='已消耗')plan.errors.push('物件已经失去处置资格');
  if(args.action==='unbind'){const a=S.anchors.find(a=>a.relic===r?.id);plan.irreversible=true;plan.loss=a?.active?a.contribution:0;plan.always=[`锚点立即休眠，当前苏醒立即失去 ${plan.loss}；并非等到轮末。`];if(r?.placement!=='绑定')plan.errors.push('物件当前没有绑定锚点');}
  if(args.action==='equip'){const p=person(f.person);if(r?.placement!=='保管'||!p||p.world!==r.world||p.status!=='在场'||S.relics.some(q=>q.holder===p.id))plan.errors.push('需要同地、在场且未携带其他圣物的人物');plan.changes=['同一物件交给该人物携带，不改变所在地。'];}
  if(args.action==='unequip'&&r?.placement!=='携带')plan.errors.push('物件当前未被携带');
  if(args.action==='disassemble'){
   plan.irreversible=true;if(!['保管','携带'].includes(r?.placement))plan.errors.push('只有当前可控制、未绑定的物件可解离');
   const gain={faith:Math.min(+t.faith_disassembly,capacity()-S.faith),insight:Math.min(+t.insight_disassembly,P.insight_cap-S.insight),followers:+t.follower_gift,whispers:Math.min(+t.whisper_release,S.budget-S.whispers)}[f.mode||'faith'];plan.gain=Math.max(0,gain);plan.always=['永久消耗此物件，失去未来携带或绑定用途。',f.mode==='whispers'?t.release_side_effect:'本次操作消耗1低语。'];plan.changes=[`实际净增加 ${plan.gain} ${({faith:'信仰',insight:'洞见',followers:'当地信众',whispers:'低语'})[f.mode||'faith']}（受现有容量限制）`];
  }
 }else if(args.kind==='event'){
  const e=C.events.find(e=>e.id===args.id),effect=C.event_effects.find(e=>e.event_id===args.id&&e.option===args.option&&e.status==='active');plan.title=e.title+' · '+args.option;plan.faith=+effect.faith_cost;plan.changes=[effect.on_choose];plan.always=[effect.irreversible_cost];if(S.eventResolved.includes(args.id)||S.phase!=='events')plan.errors.push('事件已处理或当前阶段不符');
 }else if(args.kind==='rest'){
  plan.title='敛息';plan.faith=P.rest_faith_cost;plan.changes=[`恢复 ${Math.min(S.wounds,P.rest_wound_recovery)} 创伤；封闭本轮行动并继续世界结算。`];if(S.responded||S.usedAction||S.wounds<=0)plan.errors.push('必须尚未回应、未使用权能或圣物，且有创伤');
 }else if(args.kind==='manifest'){
  const m=S.manifest;plan.title=args.action==='cancel'?'中止降临':'继续降临';plan.irreversible=args.action==='cancel';if(!m)plan.errors.push('没有正在进行的仪式');else if(args.action==='continue'){plan.whispers=P.manifest_continue_whispers;plan.faith=P.manifest_continue_faith;plan.probabilistic=m.step===3;if(m.paid)plan.errors.push('本轮已经续付');if(person(m.keeper)?.status!=='在场'||person(m.keeper)?.used)plan.errors.push('原护持者没有本轮可用资格');plan.changes=[m.step===3?'本轮末才进行最终检定，并重查锚点与护持者存续。':'完成本轮续付；下一轮仍需保持原依赖。'];}else plan.always=['已经支付的资源不返还，仪式结束。'];
 }else if(args.kind==='abandon'){plan.title='放弃本局';plan.irreversible=true;plan.always=['本局封存，不再继续当前回合；未来事件不提前结算。'];}
 else if(args.kind==='opportunity'){plan.title=({recover:'回收媒介',public:'公开媒介',wait:'等待'})[args.choice];plan.changes=[args.choice==='recover'?'按这一已知机会取得原物件，保留真实来源与所在地。':args.choice==='public'?'公开这一实际媒介，可能扩大暴露与依赖。':'暂不处置，保留机会及其真实时限。'];plan.note='该机会样例演示选择与物件回流；正式费用/资格应取实际机会预览。';}
 if(args.kind!=='event'&&args.kind!=='abandon'&&!active())plan.errors.push('当前不能自由行动');
 if(S.terminal)plan.errors.push('本局已经结束，只能回顾');
 if(S.faith<plan.faith)plan.errors.push(`信仰不足：需要${plan.faith}，当前${S.faith}`);
 if(S.whispers<plan.whispers)plan.errors.push(`低语不足：需要${plan.whispers}，当前${S.whispers}`);
 return plan;
}
function previewBody(){if(!pending)return '<p>没有待预览的动作。</p>';const p=pending;return `<h3>${esc(p.title)}</h3><div class="preview-grid" style="margin-top:16px"><div class="stack">${info('本次必付',`<p class="result-numbers">${p.whispers} 低语 · ${p.faith} 信仰</p><p>支付后：低语 ${S.whispers-p.whispers} · 信仰 ${S.faith-p.faith}</p>${p.always.map(s=>`<p>${esc(s)}</p>`).join('')}`)}${info('可能变化 / 持续后果',p.changes.map(s=>`<p>${esc(s)}</p>`).join('')||'<p>按所选处置更新原对象。</p>')}</div><div class="stack">${p.probabilistic?info('四档结果',`<div class="probability"><span style="width:14%">14%</span><span style="width:56%">56%</span><span style="width:24%">24%</span><span style="width:6%">6%</span></div><p>深成14% · 成功56% · 失败24% · 灾变6%</p><p class="muted">此处是用于结构阅读的分布样例。正式概率须由同一当前规则预览提供。</p>`):info('结算方式',`<p>${p.kind==='power'&&p.id==='POWER_MANIFEST'?'起始轮不进行最终检定。':'此步骤不展示随机四档；按确定性操作或持续过程结算。'}</p>`)}${info('相关影响',`<p>这次支付后，需要重新检查剩余教团支出与锚点供奉。</p>${B('查看全局安排','open',{type:'budget'})}<p class="muted">返回会保留当前选择；执行前再次检查资格。</p>`)}</div></div>${p.errors.length?`<div class="warning" style="margin-top:18px"><b>当前不能执行</b>${p.errors.map(e=>`<p>${esc(e)}</p>`).join('')}${B('查看关注与名额','open',{type:'attention'})}</div>`:''}${p.note?`<p class="muted">${esc(p.note)}</p>`:''}<div class="actions">${B('返回选择','close')}${B(p.irreversible?'继续 · 确认不可逆后果':'执行','submit',{},p.errors.length>0,'primary')}</div>`;}
function confirmBody(){return `<h3>${esc(pending?.title)}</h3><div class="warning" style="margin:18px 0">${pending?.always.map(s=>`<p>${esc(s)}</p>`).join('')}</div><p>费用 ${pending?.whispers} 低语 / ${pending?.faith} 信仰。</p><div class="actions">${B('取消并返回预览','close')}${B('确认执行','execute',{},false,'primary')}</div>`;}
function refreshAwake(){S.awake=Math.max(0,Math.min(P.awakening_before_final_cap,P.initial_awakening+S.insight+S.anchors.filter(a=>a.active).reduce((n,a)=>n+a.contribution,0)-S.wounds));S.peak=Math.max(S.peak,S.awake);}
function deactivateForPerson(id){for(const a of S.anchors)if(a.keeper===id)a.active=false;for(const c of S.cults)if(c.leader===id)c.state='休眠';refreshAwake();}
function execute(){
 if(!pending)return;const q=makePlan(pending,pending.form);if(q.errors.length){pending=q;while(current()?.type==='confirm')stack.pop();render();toast('资格已改变，没有支付。');return;}
 const p=pending,f=p.form;pending=null;S.whispers-=p.whispers;S.faith-=p.faith;let extra='',links=[];const actor=person(f.person||f.keeper);
 if(p.kind==='prayer'){
  S.responded=true;S.usedAction=true;S.center=S.cults.length?'cult':'home';const a=S.people[0];if(p.id==='PRAYER_08'){a.bound=true;a.devotion=true;a.loyalty=Math.max(40,a.loyalty);a.sanity-=3;extra='求告人已成为正式成员；没有凭空增加无名信众。';}links=[{type:'person',id:a.id}];
 }else if(p.kind==='power'){
  S.usedAction=true;const w=Number(f.world||f.cult||actor?.world||1),c=cult(w);
  switch(p.id){
   case 'POWER_LISTEN':world(w).barrier=75;extra='一项具体情报已揭示，其他未知项保持未知。';break;
   case 'POWER_DREAM':actor.loyalty=Math.min(100,actor.loyalty+10);actor.sanity=Math.max(0,actor.sanity-4);actor.dreamTurn=S.turn;break;
   case 'POWER_ORACLE':actor.prepared=f.purpose;extra='神谕只准备所声明的行动与人物，保留到期时间。';break;
   case 'POWER_BESTOW':actor.bestowed=true;actor.sanity-=8;extra=`${f.attribute}获得永久赐予；今后不能重复成功赐予此人。`;break;
   case 'POWER_APPOINT':actor.pending=f.office;S.appointment={person:actor.id,world:Number(f.cult),office:f.office,anchor:f.anchor};extra='已登记任命，下轮生效；不会刷新本轮执行机会。';break;
   case 'POWER_SACRIFICE':actor.status='死亡';actor.bound=false;deactivateForPerson(actor.id);if(f.sacrifice==='insight')S.insight=Math.min(P.insight_cap,S.insight+1);else if(f.sacrifice==='heal')S.wounds=Math.max(0,S.wounds-6);else S.faith=Math.min(capacity(),S.faith+8);if(c)c.cohesion=Math.max(0,c.cohesion-12);extra='原人物死亡，原职位及护持失效。';break;
   case 'POWER_BREACH':actor.used=true;world(w).barrier=Math.max(0,(world(w).barrier||75)-12);extra='一次性弱点情报已消费。';break;
   case 'POWER_SEED':actor.used=true;if(c){c.followers+=4;c.cohesion-=2;}break;
   case 'POWER_VEIL':actor.used=true;if(c)c.followers=Math.max(0,c.followers-1);if(world(w).alert!=null)world(w).alert=Math.max(0,world(w).alert-10);extra='指定证据失效；已发动的反制仍保留。';break;
   case 'POWER_ANCHOR':{
    actor.used=true;const r=relic(f.relic),tier=world(w).tier,a={id:'A-new-'+S.turn,world:w,institution:f.institution,contribution:{planet:4,system:7,cosmic:10}[tier],cost:{planet:1,system:2,cosmic:4}[tier],keeper:actor.id,relic:r.id,active:false,refuse:false};const old=S.anchors.findIndex(x=>x.world===w&&x.institution===f.institution);if(old>=0)S.anchors[old]=a;else S.anchors.push(a);r.placement='绑定';r.anchor=a.id;r.holder='';actor.role+='／护持者';extra='锚点已形成，等待轮末实际供奉；当前尚未增加苏醒。';break;}
   case 'POWER_TRANSFER':{
    const original=actor.world;deactivateForPerson(actor.id);actor.world=Number(f.destination);actor.cult=actor.world;actor.role='成员';actor.used=true;for(const r of S.relics)if(r.holder===actor.id)r.world=actor.world;const n=Math.min(Number(f.followers)||0,cult(original)?.followers||0,4);if(cult(original))cult(original).followers-=n;cult(actor.world).followers+=n;extra='同一人物迁入接收教团；原职务与护持解除，合法随身物件同行。';break;}
   case 'POWER_MANIFEST':S.manifest={step:1,paid:true,keeper:f.keeper};if(actor)actor.used=true;extra='降临进入第1轮；尚未进行最终检定。';break;
  }links=actor?[{type:'person',id:actor.id},{type:'world',id:actor.world}]:[{type:'world',id:w}];
 }else if(p.kind==='route'){
  const r=ROUTES.find(r=>r.id===p.id);if(actor){actor.used=true;actor.practiceTurn=S.turn;}
  if(r.mode==='private_devotion'&&actor){actor.devotion=true;extra='留下自愿献身依据；是否接纳仍需正式成员资格与名额。';}
  if(r.mode==='covert_gathering'||r.mode==='calendar_rite'){if(cult(actor?.world))cult(actor.world).followers+=3;else{S.localFollowers+=3;S.localSpent+=p.faith;}extra='信众与实付已变化；尚未成立的教团在轮末核验。';}
  links=[{type:'person',id:actor?.id}];
 }else if(p.kind==='transfer'){extra=memberName(f.recipient)+'取得了指定记录副本；没有新增见证或实践。';links=[{type:'person',id:f.recipient}];}
 else if(p.kind==='relic'){
  S.usedAction=true;const r=relic(p.id);links=[{type:'relic',id:r.id}];
  if(p.action==='equip'){r.holder=f.person;r.placement='携带';}
  if(['unequip','unbind'].includes(p.action)){r.holder='';r.placement='保管';if(p.action==='unbind'){const a=S.anchors.find(a=>a.relic===r.id);if(a)a.active=false;r.anchor='';}}
  if(p.action==='disassemble'){r.placement='已消耗';r.holder='';if(f.mode==='whispers')S.whispers=Math.min(S.budget,S.whispers+p.gain);else if(f.mode==='insight')S.insight=Math.min(P.insight_cap,S.insight+p.gain);else if(f.mode==='followers'){if(cult(r.world))cult(r.world).followers+=p.gain;}else S.faith=Math.min(capacity(),S.faith+p.gain);extra='此物件已永久消耗；历史身份保留。';}
 }else if(p.kind==='event'){S.eventResolved.push(p.id);if(S.eventResolved.length===S.eventIds.length)S.phase='actions';extra='事件处理不占用祈求回应次数；其实际费用已支付。';}
 else if(p.kind==='rest'){S.wounds=Math.max(0,S.wounds-P.rest_wound_recovery);refreshAwake();stack=[];settle(true);return;}
 else if(p.kind==='manifest'){if(p.action==='cancel'){S.manifest=null;extra='仪式已中止，已付费用不返还。';}else{S.manifest.paid=true;person(S.manifest.keeper).used=true;extra='本轮续付完成，最终结果仍在对应轮末确认。';}}
 else if(p.kind==='abandon'){S.terminal='abandon';S.phase='ended';stack=[];addHistory('你放弃了本局；未来回合没有被提前结算。');render();return;}
 else if(p.kind==='opportunity'&&p.choice==='recover'){const type=C.relics[0],id='R-new-'+S.turn;S.relics.push({id,name:type.name,type:type.id,placement:'保管',world:Number(p.world),holder:'',anchor:''});links=[{type:'relic',id}];extra='同一取得机会已落为有来源的物件，不重复领取。';}
 refreshAwake();addHistory(p.title+'；'+(extra||p.changes[0]||'原对象已更新'),links);
 S.result={title:p.title+' · 结果样例',text:`已支付 ${p.whispers}低语、${p.faith}信仰。\n${p.changes.join('\n')}\n${extra}`,links};
 stack=stack.slice(0,Math.max(0,p.originDepth-1));stack.push({type:'result',form:{}});render();
}
function settle(rest=false){
 if(!active())return;const b=budget(),beforeAwake=S.awake;S.faith=b.balance;
 for(const payment of b.payments){if(payment.kind==='anchor'){const a=S.anchors.find(a=>a.id===payment.id);a.active=payment.paid;}else{const c=cult(payment.id);if(payment.paid)c.followers+=2;else c.order='守持';}}
 const receipts=Math.min(b.income,Math.max(0,capacity()-S.faith));S.faith+=receipts;
 if(!S.cults.length&&S.localFollowers>=6&&S.localSpent>=8&&S.people[0]?.bound){const a=S.people[0];a.cult=a.world;a.role='领袖';S.cults.push({world:a.world,followers:S.localFollowers,cohesion:60,order:'守持',state:'运作中',leader:a.id});S.selectedCult=a.world;addHistory('首个教团在轮末形成；下轮开始产出收入。',[{type:'world',id:a.world}]);}
 if(S.manifest){if(!S.manifest.paid||person(S.manifest.keeper)?.status!=='在场'||!S.anchors.some(a=>world(a.world).tier==='cosmic'&&a.active)||!S.anchors.some(a=>world(a.world).tier==='system'&&a.active)){S.manifest=null;S.wounds+=P.manifest_failure_wounds;addHistory('降临条件失效，仪式中断。');}else if(S.manifest.step===3){S.terminal='victory';S.phase='ended';S.awake=100;S.manifest=null;addHistory('最终降临完成。');}}
 if(!S.terminal){refreshAwake();if(S.awake<=0){S.terminal='defeat';S.phase='ended';}else S.phase='between';}
 S.result={title:rest?'敛息与本轮结算':'本轮结算',text:`${rest?'已恢复创伤，并放弃本轮余下行动。\n':''}1. 计划已锁定，已付教团与锚点费用。\n2. 未支付的锚点转为休眠。\n3. 世界演化在此阶段发生（本结构样例不运行后台模拟）。\n4. 本例实际入库收入 ${receipts}；当前信仰 ${S.faith}。\n5. 苏醒 ${beforeAwake} → ${S.awake}；期限后果单独留在记录中。`,links:[{type:'budget'}]};
 addHistory(S.result.title+'；收入'+receipts+'，苏醒'+beforeAwake+'→'+S.awake,[{type:'budget'}]);stack=[];render();
}
function nextTurn(){if(S.phase!=='between'||S.terminal)return;S.turn++;S.phase='actions';S.responded=false;S.usedAction=false;S.whispers=Math.min(P.whisper_cap,P.whisper_base+Math.floor(S.awake/P.whisper_growth_step));S.budget=S.whispers;S.people.forEach(p=>p.used=false);S.releaseFocus.forEach(id=>{if(world(id))world(id).focus=false;});S.releaseFocus=[];if(S.manifest){S.manifest.step++;S.manifest.paid=false;}if(S.appointment){const a=S.appointment,p=person(a.person),c=cult(a.world);if(p?.status==='在场'){p.role=a.office;p.pending=null;if(a.office==='领袖'){c.leader=p.id;c.state='运作中';}else{const an=S.anchors.find(x=>x.id===a.anchor);if(an){an.keeper=p.id;an.active=false;}}}S.appointment=null;}
 S.result=null;S.center='home';addHistory('新一轮开始：低语与执行机会刷新；新的事件在这里先处理。');stack=[];render();}
function attentionAct(a){if(!active())return;const p=person(a.id);if(a.kind==='focus'){if(S.worlds.filter(w=>w.focus).length>=3){toast('关注名额已满；下轮释放不会提前腾出本轮位置。');return;}world(a.id).focus=true;}
 else if(a.kind==='release_focus'){if(S.manifest){toast('进行中的降临仍占用相关关注，当前不能释放。');return;}S.releaseFocus.push(Number(a.id));}
 else if(a.kind==='release_project')S.reservations=S.reservations.filter(r=>r.id!==a.id||!r.releasable);
 else if(a.kind==='enroll'){if(!p?.devotion||S.people.filter(p=>p.bound).length>=12){toast('需要真实献身依据与空余成员名额。');return;}p.bound=true;}
 else if(a.kind==='leave'){if(!p?.leaveAllowed){toast('没有当前有效的离开依据。');return;}p.bound=false;p.cult=null;p.role='已有联系';}
 addHistory(({focus:'已取得关注',release_focus:'下轮释放关注已安排',release_project:'已释放未用预留',enroll:'已接纳正式成员',leave:'已确认离团'})[a.kind]);render();}

const COVERAGE=[
 ['开始与继续','新局、保存、恢复、载入失败不覆盖当前局','mid','start'],
 ['轮初事件','当前事件取得中央优先；关联查看、零费用分支、处理后回到行动','events','event'],
 ['祈求前后','查看诉求、代理与准备、浅触/深应、一次回应后只读、期限仍在','opening','prayers'],
 ['无教团阶段','人物联系、献身与接纳、秘密集会/祭仪、自然成团条件','foundation','foundation'],
 ['多成员教团','所有具名成员、职责、失能、执行机会、任命与下轮生效','mid','members'],
 ['人物主动行为','真实实践、记忆、教习、约定、接纳/离开、记录转交','mid','routes'],
 ['十二权能','各自选择器、来源/媒介、四档或确定性、冷却、门槛、不可逆代价','mid','powerList'],
 ['圣物生命周期','取得机会、当地保管、携带/卸下、绑定/解绑、回收、四种解离','mid','relicList'],
 ['完整世界入口','全部可见世界与请求线索；无教团世界、机构、情报来源、相关人/物','pressure','worlds'],
 ['锚点与依托','建立/维持条件、真实材料、护持者、媒介、休眠/修复','mid','anchors'],
 ['资源与指令','传教/敛藏/守持、前付顺序、供奉排序/拒付、缺口、收入后到','crowded','budget'],
 ['关注与容量','关注/下轮释放、正式成员、临时人物、仅可释放未用活动预留','crowded','attention'],
 ['危机与失控','已预告反制、拘禁/失踪、媒介失控、教团休眠与继任','loss','notices'],
 ['敛息与零资源','敛息资格、整轮代价；资源为零时仍可承受事件/结束回合','rest','self'],
 ['降临与续付','起始条件、跨轮依赖、继续/中止、前两轮不提前最终检定','late','manifest'],
 ['轮末与新一轮','锁定→先支出→演化→收入/期限→终局核验→下一轮','mid','end'],
 ['编年史与返回','最新记录常驻、完整回顾、关联对象、已知因果、原任务返回','mid','history'],
 ['终局与放弃','胜利/失败只读回顾、放弃确认、新局入口','victory','ending'],
 ['容量与查找','36世界、12教团、18物件；独立滚动/查找，不缩小全部对象','pressure','worlds'],
 ['执行前失效','取消无消耗，提交重查，资源/目标变化不误扣费','mid','previewGuard']
];
function guideBody(){return `<p>这里是原型外的情境导览。跳转会加载独立示例局面，不是正式游戏中的分类菜单。</p><div class="flow" style="margin:18px 0">${B('新局','demo',{scenario:'opening',view:'start'})} → ${B('轮初事件','demo',{scenario:'events',view:'event'})} → ${B('祈求 / 自由行动','demo',{scenario:'mid',view:'home'})} → ${B('轮末','demo',{scenario:'mid',view:'end'})} → ${B('降临 / 终局','demo',{scenario:'manifest',view:'manifest'})}</div>${COVERAGE.map(([title,scope,scenario,view])=>`<div class="coverage-row"><b>${title}</b><span>${scope}</span>${B('进入这个情境','demo',{scenario,view})}</div>`).join('')}<div class="divider"></div><p class="muted">输入与结果仅用于检验结构。当前原型不复刻随机、社会推演和全部来源生成，不能用来验证平衡或正式功能可达性。</p>`;}
function dispatch(cmd,args={}){
 switch(cmd){
 case 'open':open(args.type,args.id,args);break;
 case 'close':close();break;
 case 'refresh':rememberSheet();if(current())current().form=collect();renderLayers();break;
 case 'home':S.center=args.center||'home';stack=[];render();break;
 case 'selectCult':S.selectedCult=Number(args.id);S.center='cult';stack=[];render();break;
 case 'order':if(active()&&cult(args.id)){cult(args.id).order=args.order;render();}break;
 case 'toggleAnchor':if(active()){const a=S.anchors.find(a=>a.id===args.id);a.refuse=!a.refuse;render();}break;
 case 'moveAnchor':if(active()){const i=S.anchors.findIndex(a=>a.id===args.id),j=i+args.delta;if(j>=0&&j<S.anchors.length)[S.anchors[i],S.anchors[j]]=[S.anchors[j],S.anchors[i]];render();}break;
 case 'preparePrayer':open('prayerSetup',args.id,{variant:args.variant,form:{person:S.people[0]?.id}});break;
 case 'preview':{const f=collect();if(current())current().form=f;pending=makePlan(args,f);open('preview');break;}
 case 'eventPreview':pending=makePlan({kind:'event',...args});open('preview');break;
 case 'submit':if(pending&&!pending.errors.length){if(pending.irreversible)open('confirm');else execute();}break;
 case 'execute':execute();break;
 case 'opportunity':pending=makePlan({kind:'opportunity',...args});open('preview');break;
 case 'attentionAct':attentionAct(args);break;
 case 'routeAlias':if(args.id==='ROUTE_GUIDED_DREAM')open('power','POWER_DREAM',{form:{person:args.person}});else open('prayerSetup','PRAYER_06',{variant:'deep',form:{person:args.person}});break;
 case 'endPreview':if(active())open('end');break;
 case 'settle':settle();break;
 case 'next':nextTurn();break;
 case 'guide':open('guide');break;
 case 'reset':loadScenario(S.scenario);break;
 case 'newGame':loadScenario('opening');break;
 case 'save':try{localStorage.setItem('cthulhu-ui-experience-v1',JSON.stringify({version:1,state:S}));toast('演示进度已保存；正式游戏存档未变。');}catch{toast('当前环境不可保存；本次体验仍可继续。');}break;
 case 'load':try{const value=JSON.parse(localStorage.getItem('cthulhu-ui-experience-v1'));if(value?.version!==1||!Array.isArray(value.state?.worlds)||!scenarios.some(s=>s[0]===value.state.scenario))throw Error('invalid');S=value.state;stack=[];pending=null;$('scenario').value=S.scenario;render();toast('演示进度已恢复。');}catch{open('saveError');}break;
 case 'demo':loadScenario(args.scenario);if(args.view==='event'||args.view==='home'||args.view==='ending')break;if(args.view==='manifest'){open(S.manifest?'manifest':'power',S.manifest?null:'POWER_MANIFEST');break;}if(args.view==='previewGuard'){open('power','POWER_DREAM',{form:{person:'N04'}});break;}open(args.view,args.view==='members'?4:args.view==='routes'?'N04':null);break;
 }
}
document.addEventListener('click',e=>{const b=e.target.closest('button[data-cmd]');if(!b||b.disabled)return;dispatch(b.dataset.cmd,JSON.parse(b.dataset.args||'{}'));});
document.addEventListener('change',e=>{if(e.target.id==='scenario'){loadScenario(e.target.value);return;}if(e.target.id==='zoom'){scale();return;}if(e.target.dataset.field&&current()){rememberSheet();current().form=collect();if(['world','cult','person','office','mode','stage','cosmic'].includes(e.target.dataset.field))renderLayers();}});
document.addEventListener('input',e=>{if(e.target.dataset.search){const key=e.target.dataset.search==='cult'?'cultQuery':'relicQuery';S[key]=e.target.value;const pos=e.target.selectionStart;if(key==='cultQuery')renderCults();else renderRelics();const next=document.querySelector(`[data-search="${e.target.dataset.search}"]`);next?.focus();next?.setSelectionRange(pos,pos);}});
document.addEventListener('keydown',e=>{if(e.key==='Escape'&&stack.length){e.preventDefault();close();}if(e.key==='Tab'){const dialog=document.querySelector('.sheet');if(!dialog)return;const controls=[...dialog.querySelectorAll('button:not([disabled]),input:not([disabled]),select:not([disabled]),a[href]')];const first=controls[0],last=controls.at(-1);if(e.shiftKey&&(document.activeElement===first||!dialog.contains(document.activeElement))){e.preventDefault();last?.focus();}else if(!e.shiftKey&&(document.activeElement===last||!dialog.contains(document.activeElement))){e.preventDefault();first?.focus();}}});
function scale(){const v=$('viewport');const z=$('zoom').value==='1'?1:Math.min(1,v.clientWidth/1600,v.clientHeight/900);$('game').style.transform=`scale(${z})`;}
scenarios.forEach(([id,name])=>{const option=document.createElement('option');option.value=id;option.textContent=name;$('scenario').appendChild(option);});
window.addEventListener('resize',scale);
window.Experience={loadScenario,dispatch,get state(){return S;},get layers(){return stack;},get pending(){return pending;},makePlan,budget,coverage:COVERAGE,render,version:1};
loadScenario('mid');scale();
})();
