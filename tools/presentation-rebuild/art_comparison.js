// Comparison presentation over the interaction slice's shared state and actions.
const comparisonAssets = 'comparison-assets/';
const comparisonTiles = [[0, 0, 768, 512], [768, 0, 768, 512], [0, 512, 768, 512]];
const comparisonStyles = [['a', '分层绘景'], ['b', '像素美术']];
const comparisonTiers = {planet: '行星尺度', system: '星际尺度', cosmic: '宇宙尺度'};
const comparisonState = {index: 0, style: 'a', receipt: null, stageKey: ''};
const comparisonOldModal = modalContent;
const comparisonOldOptions = options;
const comparisonFixture = () => D.comparison[comparisonState.index];
const comparisonPrayer = () => D.comparison_prayers.find(row => row.id === comparisonFixture().case);

function selectComparisonSeed(index) {
    comparisonState.index = index;
    comparisonState.receipt = null;
    const scene = comparisonFixture();
    worlds.splice(0, worlds.length, ...scene.worlds);
    people.splice(0, people.length, {name: scene.person, role: comparisonPrayer().petitioner});
    Object.assign(S, {
        world: null, focus: null, modal: null, peek: null, toast: null, response: 'choice_a',
        prayed: false, power: 'POWER_DREAM', powerDrafts: {}, ritualPicker: null,
        powerReceipts: [], log: [], revealed: {}, policy: null, policySaved: null, search: '',
        eventPending: false, whispers: Number(fixture('whispers').value), faith: Number(fixture('faith').value),
    });
}

function comparisonChoice(key) {
    const prayer = comparisonPrayer();
    const [label, , price, success] = prayer[key].split('|');
    const contract = D.comparison_contracts.find(row => row.case_id === prayer.id && row.choice === key);
    return {key, label, success, contract, price: D.comparison_costs.find(row => row.id === price)};
}
function comparisonCost(price) {
    return `低语 ${price.whispers} · 信仰 ${price.faith}`;
}
function comparisonReceipt() {
    const choice = comparisonChoice(S.response);
    if (S.prayed || !afford(choice.price)) return;
    S.whispers -= Number(choice.price.whispers);
    S.faith -= Number(choice.price.faith);
    S.prayed = true;
    comparisonState.receipt = choice;
    S.log.push({
        kind: 'prayer',
        title: choice.label,
        detail: choice.contract.disclosure === 'unknown' ? '曲解结果待正式结算。' : choice.success,
    });
}

function atlasTile(kind, box, classes, stretch = false) {
    const [x, y, w, h] = box;
    const [width, height] = kind === 'world' ? [1536, 1024] : [1254, 1254];
    return `<svg class="${classes}" viewBox="${x} ${y} ${w} ${h}"
        preserveAspectRatio="${stretch ? 'none' : 'xMidYMid slice'}" aria-hidden="true">
        ${comparisonStyles.map(([style]) => `<image class="atlas-${style}" width="${width}" height="${height}"
            href="${comparisonAssets}${kind}-${style}.png"/>`).join('')}
    </svg>`;
}

function personPart(style, box, position) {
    const [x, y, w, h] = box;
    const [left, top, width, height] = position;
    return `<svg class="atlas-${style} person-part" viewBox="${x} ${y} ${w} ${h}"
        x="${left}" y="${top}" width="${width}" height="${height}" preserveAspectRatio="none">
        <image width="1254" height="1254" href="${comparisonAssets}people-${style}.png"/>
    </svg>`;
}
function comparisonFigure(classes) {
    const older = comparisonFixture().pattern === 'inlet';
    const split = older ? 627 : 0;
    const rig = {
        a: {splitY: 459, head: older ? [73, 16, 161, 117] : [62, 17, 158, 117], body: [4, 104, 303, 294]},
        b: {splitY: 518, head: older ? [75, 21, 174, 139] : [91, 20, 162, 138], body: [4, 118, 303, 280]},
    };
    return `<svg class="${classes} comparison-figure" viewBox="0 0 310 400" role="img"
        aria-label="${E(people[0].name)}">
        ${Object.entries(rig).map(([style, {splitY, head, body}]) =>
            personPart(style, [split, 0, 627, splitY], head) +
            personPart(style, [split, splitY, 627, 1254 - splitY], body)).join('')}
    </svg>`;
}

ritualPersonArt = comparisonFigure;

function comparisonWorldScene(view) {
    if (view === 'overview') {
        return `<div class="beyond-atmosphere"></div>
            <svg class="sight-paths" viewBox="0 0 1600 900" aria-hidden="true">
                <path d="M38 583C312 358 512 289 900 363S1294 683 1571 422"/>
                <path d="M118 658C382 500 630 508 864 516S1317 513 1470 313"/>
                <path d="M129 390C388 640 791 757 1280 595"/>
            </svg>
            ${worlds.map((world, i) => `<div class="world-glimpse glimpse-${i}">
                ${atlasTile('world', comparisonTiles[i], 'glimpse-art')}
                ${comparisonFixture().pattern === 'inlet' ? atlasTile('world',
                    [[65, 106, 440, 340], [806, 18, 393, 375], [103, 539, 408, 356]][i], 'glimpse-branch') : ''}
            </div>`).join('')}
            <div class="god-sight" aria-hidden="true"><i></i></div>`;
    }
    if (view === 'prayer' || view === 'dream' || view === 'echo') {
        const lamp = comparisonFixture().pattern === 'inlet';
        const crop = lamp ? [996, 512, 540, 512] : [768, 512, 768, 512];
        const actualChoice = comparisonState.receipt?.key;
        const lighting = view === 'prayer' && actualChoice === 'choice_a';
        const chosen = view === 'prayer' || view === 'echo' || Boolean(S.powerDrafts[S.power]?.person);
        return `<div class="shore-plate ${lamp ? 'inlet-shore' : ''} ${lighting ? 'answered-light' : ''}">
            ${atlasTile('world', crop, 'shore-scape', true)}
            ${lamp ? '<i class="beacon-shutter"></i><i class="beacon-light"></i>' :
                '<svg class="reef-light" viewBox="0 0 1600 900" aria-hidden="true"><path d="M379 493Q527 524 564 555T748 608T879 703"/></svg>'}
        </div>
        <div class="weather"></div>
        ${view !== 'prayer' ? `<svg class="dream-thread ${chosen ? 'thread-found' : ''}" viewBox="0 0 1600 900" aria-hidden="true">
            <path class="thread-echo" d="M274 153C459 181 450 385 720 378S822 371 870 405"/>
            <path class="thread-travel" d="M275 153C460 181 451 385 721 378S823 371 871 405"/>
            <circle cx="875" cy="405" r="139"/><circle cx="875" cy="405" r="191"/>
        </svg>` : ''}
        ${chosen ? comparisonFigure('scene-actor') : '<div class="absence-ring" aria-hidden="true"></div>'}`;
    }
    const tile = comparisonTiles[S.world ?? 0];
    return `<div class="local-plate">${atlasTile('world', tile, 'local-scape', true)}</div>
        ${view === 'cult' ? `<svg class="cult-traces" viewBox="0 0 1600 900" aria-hidden="true">
            <path d="M454 472Q650 529 799 580Q999 606 1208 369"/>
            <circle cx="454" cy="472" r="4"/><circle cx="799" cy="580" r="4"/><circle cx="1208" cy="369" r="4"/>
        </svg>` : ''}`;
}

function comparisonTabs() {
    const active = comparisonState.style;
    return `<div class="review-switch" aria-label="美术对照">
        ${comparisonStyles.map(([key, label], i) => act(`<kbd>${i + 1}</kbd> ${label}`, 'artStyle', key, 'style-tab')
            .replace('class="style-tab"', `class="style-tab" aria-pressed="${active === key}"`)).join('')}
    </div>`;
}

function comparisonTop() {
    const name = S.world === null ? '' : worlds[S.world].name;
    return `<header class="compare-hud">
        <div class="game-mark"><i aria-hidden="true"></i><div><strong>邪神苏醒</strong><small>第 ${fixture('turn').value} 轮 · 神意行动</small></div></div>
        <div class="compare-resources"><span>低语 <b>${S.whispers}</b></span><span>信仰 <b>${S.faith}</b></span><span>苏醒 <b>${fixture('awakening').value}</b></span></div>
        ${comparisonTabs()}
    </header>
    <nav class="compare-crumb">${act('诸界态势', 'home')}${name ? '<span>›</span>' + act(E(name), 'world', S.world) : ''}</nav>`;
}

function comparisonFoot() {
    return `<footer class="compare-foot">
        <div class="play-tools">${act('十二权能', 'modal', 'powers')}${act('人物档案', 'managePerson', '0')}${act('编年史', 'modal', 'history')}</div>
        <div class="sample-select">${D.comparison.map((sample, i) => act(i === 0 ? '归船' : '坏灯塔', 'artSeed', i, i === comparisonState.index ? 'active' : '')
            .replace('class="', `aria-pressed="${i === comparisonState.index}" class="`)).join('')}</div>
        <div class="compare-meta">种子 ${comparisonFixture().seed}<span> / </span>美术样片</div>
    </footer>`;
}

function comparisonOverview() {
    return `<div class="compare-heading"><small>神意所及</small><h1>诸界态势</h1></div>
        ${worlds.map((world, i) => act(`<span class="world-tag">${comparisonTiers[world.tier]}</span>
            <strong>${E(world.name)}</strong><small>${i === 0 ? (S.prayed ? '回应已留痕 · 密教活动可查' : '有一声祈求 · 密教活动可查') : '已有世界联系'}</small>
            <span class="overview-metrics" title="屏障、污染、察觉、稳定">${metrics(i, true)}</span>`, 'world', i, 'sight-label sight-' + i)).join('')}`;
}

function comparisonLocal(view) {
    const index = S.world;
    const current = worlds[index];
    const cult = view === 'cult';
    const prayer = comparisonPrayer();
    return `<section class="local-heading">
        <small>${cult ? '当地教团 · 活动范围' : comparisonTiers[current.tier]}</small>
        <h1>${E(cult ? comparisonFixture().cult : current.name)}</h1>
        <p>${E(cult ? '沿岸数处小组彼此接应。亮点标示目前知晓的活动。' : current.background)}</p>
        <div class="comparison-intel">${metrics(index)}<small>${index < 2 ? '示例快照 · 第 ' + observation(index, 'barrier').observed + ' 轮' : '未掌握观测'}</small></div>
    </section>
    ${index === 0 ? (cult ? `<div class="cult-sites" aria-hidden="true"><span>礁岸留灯</span><span>渡口望守</span><span>灯塔接应</span></div>
        <div class="local-actions">${act('查看已知人物', 'managePerson', '0')}${act('持续指令', 'modal', 'policy')}${act('退回当地联系', 'unfocus')}</div>` :
        `<div class="shore-hook">${act(`<small>${S.prayed ? '祈求回执' : '一声无指向的祈求'}</small><strong>${E(prayer.title)}</strong>`, 'focus', 'prayer')}</div>
        <div class="local-actions">${act('查看当地教团', 'focus', 'cult')}${act('打开入梦准备', 'preparePower', 'POWER_DREAM')}</div>`) : ''}`;
}

prayerScene = function () {
    const prayer = comparisonPrayer();
    const selected = comparisonChoice(S.response);
    const answer = comparisonState.receipt;
    const choices = ['choice_a', 'choice_b', 'choice_c', 'choice_d', 'choice_e'].filter(key => prayer[key]);
    return `<section class="coast-dialog" aria-label="祈求场景">
        <div class="shore-heading"><small>祈求 · ${E(worlds[0].name)}</small><h1>${E(prayer.title)}</h1><p>${E(prayer.context)}</p></div>
        ${prayer.id === 'lantern_keeper' ? `<div class="beacon-caption">灯塔 · ${answer?.key === 'choice_a' ? '光扫过海面' : '灯火熄灭'}</div>` : ''}
        <div class="shore-words"><span>${E(people[0].name)} · ${E(prayer.petitioner)}</span>
            <blockquote>「${E(prayer.appeal)}」</blockquote>${act('查求告者', 'peek', 'person:0')}</div>
        <section class="decision-ledge">
        ${answer ? `<small>演示回执 · ${comparisonCost(answer.price)}</small><h2>${E(answer.label)}</h2>
            <p>${E(answer.contract.disclosure === 'unknown' ? '曲解结果待正式结算。' : answer.success)}</p>
            <p>${E(answer.contract.hint)}</p>${act('返回当地', 'closeModal', '', 'coast-return')}` : `
            <div class="ledge-heading"><span>如何回应</span><small>余 ${prayer.deadline} 轮 · 本轮一次</small></div>
            <div class="coast-choices">${choices.map(key => {
                const choice = comparisonChoice(key);
                return act(`<strong>${E(choice.label)}</strong><small>${comparisonCost(choice.price)}</small>`,
                    'response', key, S.response === key ? 'active' : '');
            }).join('')}</div>
            <p class="choice-hint">${E(selected.contract.hint || '具体后果未知。')}</p>
            ${act('回应 · 预演', 'coastAnswer', '', 'coast-primary', !afford(selected.price))}`}</section>
        ${act('返回当地 ↩', 'closeModal', '', 'scene-return')}
    </section>`;
};

options = function (field) {
    return field === 'person' ? [['0', comparisonFixture().person]] : comparisonOldOptions(field);
};

function comparisonDream(echo = false) {
    const p = powers.find(power => power.id === 'POWER_DREAM');
    const chosen = Boolean(S.powerDrafts.POWER_DREAM?.person);
    return `<section class="coast-dialog dream-dialog" aria-label="${echo ? '入梦回响' : '入梦准备'}">
        <div class="shore-heading"><small>十二权能 · 接触</small><h1>${echo ? '梦留下的回响' : '入梦'}</h1>
            <p>${echo ? '神意已触及此人。' : '循这声祈求找到一个能抵达的人。'}</p>
            ${echo ? '' : act('十二权能', 'modal', 'powers')}</div>
        ${chosen ? `<div class="dream-actor-name">${E(people[0].name)}${act('查阅', 'peek', 'person:0')}</div>` : ''}
        <section class="decision-ledge">
            ${echo ? `<small>演示回执 · ${comparisonCost(p)}</small><h2>${E(people[0].name)}</h2>
                <p>${E(p.success)}</p>${act('回到来处', 'closeModal', '', 'coast-primary')}` :
            `<div class="ledge-heading"><span>建立梦境联系</span><small>${comparisonCost(p)}</small></div>
                ${act(chosen ? E(people[0].name) + '　↗' : '选择可达人物　↗', 'ritualPick', 'person', 'dream-target')}
                <p class="choice-hint">失败：${E(p.failure)}<br>灾变：${E(p.disaster)}</p>
                ${act('施展入梦 · 预演', 'ritualCommit', '', 'coast-primary', !contactReady())}`}
        </section>
        ${act('返回 ↩', 'closeModal', '', 'scene-return')}
        ${S.ritualPicker && !echo ? `<aside class="coast-picker"><div class="ledge-heading"><span>选定梦境联系</span>
            ${act('收起', 'ritualPickClose')}</div>${act(comparisonFigure('picker-actor') +
            `<span>${E(people[0].name)}<small>${E(people[0].role)}</small></span>`, 'ritualChoose', '0')}</aside>` : ''}
    </section>`;
}

role = () => '当地人物';
held = () => null;
personDetail = function (index, tab) {
    const prayer = comparisonPrayer();
    const descriptions = {
        roles: `身份 · ${E(prayer.petitioner)}`,
        abilities: '已知联系 · 本次祈求',
        objects: E(prayer.context),
        history: '当前可见事实来自这次祈求。',
    };
    return `<p>${descriptions[tab] ?? descriptions.roles}</p>`;
};

peekContent = (function (previous) {
    return function () {
        if (S.peek?.startsWith('person')) {
            return `<aside class="peek compare-peek" aria-label="人物速览"><div class="peekhead">
                ${E(worlds[0].name)}${act('×', 'closePeek', '', 'dismiss')}</div>
                ${comparisonFigure('peek-actor')}<h2>${E(people[0].name)}</h2>
                <p>${E(comparisonPrayer().petitioner)}</p>${act('查看完整人物档案', 'managePerson', '0', 'secondary')}</aside>`;
        }
        return previous();
    };
})(peekContent);

goWorld = function (index) {
    S.world = index;
    S.focus = null;
    S.ritualPicker = null;
    closeLayers();
};

const comparisonAssetTargets = ['world', 'people'];
function setComparisonStyle(style) {
    comparisonState.style = style;
    $('#fit').dataset.artStyle = style;
    document.querySelectorAll('button[data-a="artStyle"]').forEach(button => {
        button.setAttribute('aria-pressed', String(button.dataset.v === style));
    });
}

function comparisonView() {
    if (S.modal === 'prayerScene') return 'prayer';
    if (S.modal === 'powerPrepare' && S.power === 'POWER_DREAM') return 'dream';
    if (S.modal === 'ritualResult' && S.lastRitual === 'POWER_DREAM') return 'echo';
    if (S.modal === 'powers' && S.world === null) return 'overview';
    if (S.world === null) return 'overview';
    return S.focus === 'cult' ? 'cult' : 'local';
}

setupScene = function () {
    $('#realms').classList.add('comparison-stage');
};
render = function () {
    const focused = document.activeElement?.dataset;
    const view = comparisonView();
    const prepared = S.powerDrafts[S.power]?.person;
    const stageKey = [comparisonState.index, view, S.world, prepared, comparisonState.receipt?.key].join('/');
    const fit = $('#fit');
    fit.dataset.scene = view;
    fit.dataset.seed = comparisonFixture().pattern;
    fit.dataset.artStyle = comparisonState.style;
    fit.classList.add('art-comparison');

    if (comparisonState.stageKey !== stageKey) {
        $('#realms').innerHTML = comparisonWorldScene(view);
        comparisonState.stageKey = stageKey;
    }
    const scene = view === 'prayer' ? prayerScene() : view === 'dream' || view === 'echo' ? comparisonDream(view === 'echo') : '';
    const overlay = S.modal && !scene ? comparisonOldModal() : '';
    const local = S.world === null ? comparisonOverview() : comparisonLocal(view);
    $('#ui').innerHTML = comparisonTop() + (scene || `<div class="comparison-local" ${overlay ? 'inert' : ''}>${local}</div>`) +
        overlay + (S.peek ? peekContent() : '') + comparisonFoot();
    if (focused?.a) {
        const match = Array.from($('#ui').querySelectorAll('button[data-a]')).find(button =>
            button.dataset.a === focused.a && button.dataset.v === focused.v);
        if (match) match.focus({preventScroll: true});
    }
};

document.addEventListener('click', event => {
    const button = event.target.closest('button[data-a]');
    if (!button || button.disabled) return;
    const {a, v} = button.dataset;
    if (a === 'artStyle') {
        event.stopImmediatePropagation();
        setComparisonStyle(v);
    } else if (a === 'artSeed' && Number(v) !== comparisonState.index) {
        event.stopImmediatePropagation();
        selectComparisonSeed(Number(v));
        render();
    } else if (a === 'coastAnswer') {
        event.stopImmediatePropagation();
        comparisonReceipt();
        render();
    } else if (a === 'backPrayer') {
        event.stopImmediatePropagation();
        goFocus('prayer');
        S.modal = 'prayerScene';
        render();
    }
}, true);

document.addEventListener('keydown', event => {
    if (event.target.matches('input, textarea, select') || event.altKey || event.ctrlKey || event.metaKey) return;
    if (event.key === '1' || event.key === '2') {
        event.preventDefault();
        setComparisonStyle(comparisonStyles[Number(event.key) - 1][0]);
    } else if (event.key === 'Escape' && S.ritualPicker && !S.peek) {
        event.stopImmediatePropagation();
        S.ritualPicker = null;
        render();
    }
}, true);

selectComparisonSeed(0);
const initialStyle = new URLSearchParams(location.search).get('style');
if (comparisonStyles.some(([key]) => key === initialStyle)) comparisonState.style = initialStyle;
comparisonAssetTargets.forEach(kind => comparisonStyles.forEach(([key]) => {
    const source = new Image();
    source.src = comparisonAssets + kind + '-' + key + '.png';
}));
