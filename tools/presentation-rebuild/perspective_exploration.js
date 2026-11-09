// Visual layer over the accepted interaction slice.
const perspectiveWorlds = D.comparison[0].worlds;
worlds.forEach((world, index) => { world.name = perspectiveWorlds[index].name; });
people[0].name = D.comparison[0].person;
people[0].detail = '潜在信徒 · 本轮求告';
fixture('local').name = '退潮之约';
fixture('target').name = '沿岸见证所';
let perspectiveStyle = 'painted';
let perspectivePoseGallery = false;

function perspectiveTile(kind, index, cls) {
    const world = kind === 'world';
    if (!world) {
        return `<svg class="${cls}" viewBox="0 0 768 1024" preserveAspectRatio="xMidYMid meet" aria-hidden="true">
          <svg class="p-painted" viewBox="${index * 768} 0 768 1024" width="768" height="1024"><image width="1536" height="1024" href="perspective-assets/people-painted.png"/></svg>
          <svg class="p-pixel" viewBox="${index * 887} 0 887 887" width="768" height="1024" preserveAspectRatio="xMidYMid meet"><image width="1774" height="887" href="perspective-assets/people-pixel.png"/></svg>
        </svg>`;
    }
    const x = world ? (index % 2) * 627 : index * 768;
    const y = world && index > 1 ? 627 : 0;
    const width = world ? 627 : 768;
    const height = world ? 627 : 1024;
    const assetWidth = world ? 1254 : 1536;
    const assetHeight = world ? 1254 : 1024;
    return `<svg class="${cls}" viewBox="${x} ${y} ${width} ${height}" preserveAspectRatio="xMidYMid meet" aria-hidden="true">
    <image class="p-painted" width="${assetWidth}" height="${assetHeight}" href="perspective-assets/${kind}-painted.png"/>
    <image class="p-pixel" width="${assetWidth}" height="${assetHeight}" href="perspective-assets/${kind}-pixel.png"/></svg>`;
}
island = index => perspectiveTile('world', index, 'world-form');
const perspectiveSetup = setupScene;
setupScene = function () {
    perspectiveSetup();
    document.querySelectorAll('.realm .overline').forEach((label, index) => {
        label.textContent = ['行星尺度', '星际尺度', '宇宙尺度'][index];
    });
};
ritualPersonArt = (cls, alt) => `<span class="${cls} p-person" role="img" aria-label="${E(alt)}">${perspectiveTile('people', 0, 'p-person-art')}</span>`;
const perspectiveOriginalPrayer = prayerScene;
prayerScene = function () {
    const p = D.prayers.find(row => row.id === 'PRAYER_08');
    return `<section class="ritual-layer prayer-scene perspective-prayer" role="dialog" aria-label="祈求场景">
      <div class="perspective-prayer-world">${perspectiveTile('world', 0, 'world-form')}</div>
      <div class="person-medallion">${perspectiveTile('people', 0, 'p-person-art')}</div>
      <div class="ritual-top"><span>${E(worlds[0].name)} / 求告者 ${E(people[0].name)}</span>${act('×','closeModal','','dismiss')}</div>
      <div class="prayer-story"><small>一个向未知存在发出的求告</small><h2>${E(p.title)}</h2>
        <p>“如果有什么能听见我，<br>请让我知道，<br>我的声音没有消失。”</p>
        ${act('查求告者与已有联系 ↗','peek','person:0','secondary')}</div>
      <div class="prayer-decisions">${S.prayed
        ? '<h3>本轮已经回应</h3><p class="quiet">求告者与当地联系仍在。</p>'+act('查看回应回执','modal','history','secondary')
        : ['shallow','deep'].map(m=>act(`<strong>${m==='shallow'?'浅触':'深干预'}</strong><p>${E(p[m+'_gain'])}<br>代价：${E(p[m+'_cost'])}</p>`,'response',m,'choice '+(S.response===m?'active':''))).join('')+
          `<p class="quiet">${param('prayer_'+S.response+'_whispers')} 低语 · ${param('prayer_'+S.response+'_faith')} 信仰<br>回应占用本轮一次机会。</p>${act('回应这声祈求 · 预演','prayerPreview','','primary',S.whispers<param('prayer_'+S.response+'_whispers')||S.faith<param('prayer_'+S.response+'_faith'))}`}
      </div></section>`;
};
const perspectiveRender = render;
render = function () {
    perspectiveRender();
    const fit = $('#fit');
    fit.dataset.perspectiveStyle = perspectiveStyle;
    fit.classList.add('perspective-review');
    $('#ui').insertAdjacentHTML('beforeend',`<div class="perspective-switch" aria-label="美术媒介">
      ${act('分层绘景','perspectiveStyle','painted',perspectiveStyle==='painted'?'active':'')}
      ${act('像素美术','perspectiveStyle','pixel',perspectiveStyle==='pixel'?'active':'')}
      ${act('人物姿态样本','perspectiveGallery','','')}</div>`);
    if (perspectivePoseGallery) {
        $('#ui').insertAdjacentHTML('beforeend',`<section class="perspective-gallery" role="dialog" aria-label="人物姿态样本">
          <h2>求告者姿态与识别</h2><p>两种处境下的姿态示例，画面位置和尺度一致。</p>
          <div class="pose-pair"><div>${perspectiveTile('people',0,'pose-art')}<p>无指向求告 · 仰望与抱胸</p></div>
          <div>${perspectiveTile('people',1,'pose-art')}<p>密教信徒 · 低头与合掌</p></div></div>
          ${act('返回当前场景','perspectiveGallery','','secondary')}</section>`);
    }
    const oldPortrait = document.querySelector('.peek-portrait');
    if (oldPortrait) oldPortrait.outerHTML = ritualPersonArt('peek-portrait', people[0].name);
    if (S.focus === 'cult' && !S.modal) {
        $('#ui').insertAdjacentHTML('beforeend',`<div class="perspective-cult" aria-label="教团活动整体视图">
          ${perspectiveTile('world',3,'cult-form')}<small>当地教团 · 人群与活动范围</small></div>`);
    }
};
document.addEventListener('click', event => {
    const b = event.target.closest('[data-a="perspectiveStyle"],[data-a="perspectiveGallery"]');
    if (!b) return;
    event.stopImmediatePropagation();
    if (b.dataset.a === 'perspectiveStyle') perspectiveStyle = b.dataset.v;
    else perspectivePoseGallery = !perspectivePoseGallery;
    render();
}, true);
