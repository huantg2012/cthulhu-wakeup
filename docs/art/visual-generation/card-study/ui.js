// BEGIN GENERATED STUDY MANIFEST
const STUDY_MANIFEST = {
  "identity": {
    "world_template_id": "CIV_02",
    "world_name_source": "data/player_text.csv",
    "cult_name": "听潮密会",
    "person_name": "守历人·伊弥",
    "identity_status": "教团与人物为候选视觉设定，非正式对象",
    "world_note": "采用正式 CIV_02 文明模板的展示名称；不是具体存档的生成世界",
    "world_method": "原作 Godot 生成器直接输出",
    "cult_method": "ImageGen 二维绘画母版 · 非参数化生成",
    "person_method": "ImageGen 二维绘画母版 · 非参数化生成",
    "world_name": "塔穆什"
  },
  "params": {
    "scene": 0,
    "star_type": -1,
    "wonder": -1,
    "style": 0,
    "archetype": 0,
    "palette": 7,
    "seed": 1337,
    "composition": 1,
    "aspect": 1,
    "quality": 1,
    "animate": false,
    "corruption": 0.2,
    "madness": 0.06,
    "nebula": 0.25,
    "rings": 2,
    "count": 0,
    "tentacles": 0.0,
    "eyes": 0.0,
    "glyphs": 0.0,
    "show_title": false,
    "show_labels": false,
    "show_frame": false,
    "show_swatch": false
  },
  "capture": {
    "initial_g_time": 3.0,
    "frames_after_rebuild": 4
  },
  "labels": {
    "scene": "星球立绘",
    "style": "暗黑厚涂",
    "archetype": "溺亡之海",
    "palette": "深海靛蓝",
    "composition": "居中",
    "aspect": "1:1 方图"
  },
  "paths": {
    "world": "assets/v2-world.png",
    "cult": "assets/v2-cult.png",
    "person": "assets/v2-person.png",
    "reference": "reference-check/reference-world.png"
  },
  "comparison": {
    "status": "measured",
    "summary": "源资产比对：不同像素 0；RGBA 完全一致：True；平均 RGB 绝对误差 0。结果只证明 PNG 还原，不代表 UI 缩放或审美通过。",
    "evidence": {
      "schema": 1,
      "source": "docs/art/visual-generation/godot-base (accepted trimmed original)",
      "git_commit": "84945041c0c4e3231579fc3206cf35bcb78db1c1",
      "engine": "Godot 4.7.2 stable official ed1daf0bf; GL Compatibility; Apple M4 Pro",
      "source_manifest": "reference-check/source-sha256.json",
      "source_manifest_sha256": "61647860d128d29b3d20924863b3eaf4a491a96123ea0e322525aaf091d5894a",
      "source_copy_mismatches": [],
      "parameters": {
        "scene": 0,
        "style": 0,
        "seed": 1337,
        "archetype": 0,
        "palette": 7,
        "composition": 1,
        "star_type": -1,
        "wonder": -1,
        "count": 0,
        "rings": 2,
        "tentacles": 0.0,
        "eyes": 0.0,
        "glyphs": 0.0,
        "corruption": 0.2,
        "madness": 0.06,
        "nebula": 0.25,
        "aspect": 1,
        "quality": 1,
        "animate": false,
        "show_title": false,
        "show_labels": false,
        "show_frame": false,
        "show_swatch": false
      },
      "labels": {
        "style": "暗黑厚涂",
        "style_sid": 0,
        "archetype": "溺亡之海",
        "palette": "深海靛蓝",
        "composition": "居中",
        "aspect": "1:1 方图",
        "quality": "标准 1x",
        "generator_title": "Azaugg-Zho"
      },
      "capture": {
        "initial_g_time": 3.0,
        "animate": false,
        "frames_after_rebuild": 4,
        "render_path": "stock main.gd → stock generator.gd → stock post.gdshader → stock shots.gd vp_final.get_texture().get_image()",
        "output_size": [
          960,
          960
        ]
      },
      "reference": {
        "path": "reference-check/reference-world.png",
        "sha256": "332e8c43f4a7e25fb67f5c1be00687b96fd382f9750ec3afdd42435945781c3d"
      },
      "sample": {
        "path": "assets/v2-world.png",
        "sha256": "332e8c43f4a7e25fb67f5c1be00687b96fd382f9750ec3afdd42435945781c3d"
      },
      "comparison": {
        "bytes_equal": true,
        "rgba_pixels_equal": true,
        "different_pixels": 0,
        "mean_absolute_rgb_error": 0,
        "resized": false,
        "cropped": false,
        "repainted": false
      },
      "old_pixel_audit": {
        "sample": "assets/pixel-world.png",
        "reference": "reference-check/pixel-world-rerender.png",
        "sha256": "dc32379b2e3326ce4915503ae5401afc1407ca72a09f72b96087e620871aa3d4",
        "rerender_sha256": "dc32379b2e3326ce4915503ae5401afc1407ca72a09f72b96087e620871aa3d4",
        "rgba_pixels_equal": true,
        "actual_parameters": {
          "scene": 0,
          "style": 3,
          "seed": 1337,
          "archetype": 0,
          "palette": 7,
          "composition": 1,
          "star_type": -1,
          "wonder": -1,
          "count": 0,
          "rings": 2,
          "tentacles": 0.0,
          "eyes": 0.0,
          "glyphs": 0.0,
          "corruption": 0.2,
          "madness": 0.15,
          "nebula": 0.6,
          "aspect": 1,
          "quality": 1,
          "animate": false,
          "show_title": false,
          "show_labels": false,
          "show_frame": false,
          "show_swatch": false
        },
        "finding": "Current old pixel planet is exact original output. Previous metadata omitted sliders, render flags and names. Cross-asset visual mismatch exists in hand drawn cult/person; do not attribute it to a non-original planet."
      },
      "reproduction": {
        "prepare": "Copy docs/art/visual-generation/godot-base to an isolated temporary directory. Import assets there if needed. Do not edit any generator, shader, mesh or project source.",
        "command": "/Applications/Godot.app/Contents/MacOS/Godot --path /tmp/cthulhu-fidelity-audit -- --shots=/tmp/cthulhu-fidelity-v2 --cfg=scene:0,style:0,seed:1337,archetype:0,palette:7,composition:1,count:0,rings:2,tentacles:0.0,eyes:0.0,glyphs:0.0,corruption:0.2,madness:0.06,nebula:0.25,aspect:1,quality:1,animate:0,show_title:0,show_labels:0,show_frame:0,show_swatch:0",
        "take": "00_s0_st0_1337.png is vp_final PNG exported by stock shots.gd; copied verbatim to reference-check/reference-world.png and assets/v2-world.png.",
        "ui_note": "Pixel equality proves saved raster assets only. Browser scaling, masking or context dimming is outside this equality claim; the reference comparison must display both raw assets with the same unfiltered geometry."
      }
    }
  }
};
// END GENERATED STUDY MANIFEST
/* Visual study only. Existing interaction functions and data remain authoritative. */
'use strict';
const study = { skin: 0, family: 0, gallery: true, reference: false };
const studySkins = ['无垠黑绒', '异界图录', '深渊圣匣'];
const studyFamilies = [STUDY_MANIFEST.identity.world_name + ' · ' + STUDY_MANIFEST.labels.style];
const artPath = (kind, family = study.family) => (family === 1 && kind === 'world' ? 'assets/f1-world.png' : STUDY_MANIFEST.paths[kind]);
const studyImage = (kind, cls = '', family = study.family) => `<img class="study-art ${cls}" src="${artPath(kind, family)}" alt="${kind === 'world' ? '世界星球' : kind === 'cult' ? '教团盆栽场景' : '求告者半身'} · 生成小样">`;
const studyBar = document.createElement('header');
studyBar.id = 'study-bar';
studyBar.innerHTML = `<div class="study-heading"><b>立绘 × 界面</b><small>视觉候选 · 非正式对象</small></div><nav aria-label="界面方案">${studySkins.map((n,i)=>`<button data-study-skin="${i}"><kbd>${i+1}</kbd>${n}</button>`).join('')}</nav><label>同源画风 <select id="study-family">${studyFamilies.map((n,i)=>`<option value="${i}">${n}</option>`).join('')}</select></label><button id="study-gallery">立绘三联画</button><button id="study-reference">原作基准对照</button><select id="study-scene" aria-label="跳到展示场景"><option value="overview">诸界态势</option><option value="local">当地联系</option><option value="cult">教团</option><option value="prayer">祈求</option><option value="person">人物档案</option></select>`;
document.body.append(studyBar);
const studyGallery = document.createElement('section');
studyGallery.id = 'study-gallery-view';
studyGallery.setAttribute('aria-label','世界、教团、人物同源立绘比较');
document.body.append(studyGallery);
const originalStudyIsland = island;
island = function(i) {
  if (i === 2) return '<div class="study-unknown"><span>◌</span><small>尚未凝成清晰的形象</small></div>';
  return studyImage('world', 'study-world', i === 0 ? study.family : 1-study.family);
};
const oldStudyRender = render;
render = function() {
  oldStudyRender();
  const root = document.querySelector('#fit');
  root.dataset.studySkin = String(study.skin);
  root.classList.toggle('study-cult-view', S.focus === 'cult');
  document.querySelectorAll('#realms .realm').forEach((realm, i) => {
    const image = realm.querySelector('.study-world');
    if (image) image.src = artPath(i === 0 && S.focus === 'cult' ? 'cult' : 'world', i === 0 ? study.family : 1-study.family);
  });
  document.querySelectorAll('img[src*="recorder.png"]').forEach(img => {
    img.src = artPath('person');
    img.classList.add('study-art');
  });
  document.querySelectorAll('.event-picture .study-art').forEach(img => img.src = artPath('cult'));
  const seal = document.querySelector('.h-cult .seal');
  if (seal) { seal.innerHTML = studyImage('cult', 'study-seal'); seal.classList.add('study-picture-seal'); }
  const prayerSeal = document.querySelector('.h-prayer .seal');
  if (prayerSeal) { prayerSeal.innerHTML = studyImage('person', 'study-seal'); prayerSeal.classList.add('study-picture-seal'); }
  document.querySelectorAll('.prayer-art,.ritual-backdrop').forEach(el => {
    el.style.backgroundImage = `radial-gradient(ellipse at center, transparent, #080a10 85%), url("${artPath('world')}")`;
  });
  const footnote = document.querySelector('.footnote');
  if (footnote) footnote.firstChild.textContent = '视觉预览：' + STUDY_MANIFEST.identity.world_name + ' / ' + STUDY_MANIFEST.identity.cult_name + '；机制文字仍为原交互夹具，非正式对象映射。 ';
};
function studyParamsSummary() {
  const p=STUDY_MANIFEST.params, l=STUDY_MANIFEST.labels;
  return `${l.style} [${p.style}] · ${l.archetype} [${p.archetype}] · ${l.palette} [${p.palette}] · 种子 ${p.seed} · ${l.composition} [${p.composition}]`;
}
function studyParameters() {
  return `<details class="study-parameters"><summary>完整生成参数与身份来源</summary><div><p>${E(STUDY_MANIFEST.identity.world_note)}。${E(STUDY_MANIFEST.identity.identity_status)}。</p><pre>${E(JSON.stringify({identity:STUDY_MANIFEST.identity, generator:STUDY_MANIFEST.params,capture:STUDY_MANIFEST.capture},null,2))}</pre></div></details>`;
}
function comparisonContent() {
  const report=STUDY_MANIFEST.comparison;
  const status=report.summary || '比对结果详见下方记录；没有作者审美通过结论。';
  return `<div class="study-gallery-intro"><div><small>星球还原 · 同参数对照</small><h1>${E(STUDY_MANIFEST.identity.world_name)}</h1><p>${E(studyParamsSummary())}</p></div><button id="study-return-gallery">返回三联画</button></div>
  <div class="study-reference-grid">${[['reference','原作基准','独立运行原作工程'],['world','样板使用资产','对照原 PNG；不施加 CSS 滤镜']].map(([key,title,note])=>`<article><h2>${title}</h2><p>${note}</p><a href="${STUDY_MANIFEST.paths[key]}" target="_blank" rel="noopener"><img src="${STUDY_MANIFEST.paths[key]}" alt="${title}"></a><a class="study-original-link" href="${STUDY_MANIFEST.paths[key]}" target="_blank" rel="noopener">打开原尺寸 PNG ↗</a></article>`).join('')}</div>
  <div class="study-comparison-status"><b>${report.status==='pending'?'比对待完成':'已记录比对结果'}</b><p>${E(status)}</p><details><summary>查看实际比对记录</summary><pre>${E(JSON.stringify(report,null,2))}</pre></details></div>${studyParameters()}`;
}
function renderStudyGallery() {
  studyGallery.dataset.studySkin = String(study.skin);
  studyGallery.hidden = !study.gallery;
  const identity=STUDY_MANIFEST.identity;
  if(study.reference) studyGallery.innerHTML=comparisonContent();
  else studyGallery.innerHTML = `<div class="study-gallery-intro"><div><small>${E(identity.world_template_id)} / 世界模板 · 立绘视觉候选</small><h1>${E(identity.world_name)} <span>— ${E(identity.cult_name)}</span></h1><p class="study-param-line">${E(studyParamsSummary())}</p></div><button id="study-enter">放入交互夹具 →</button></div>
  <div class="study-triptych">${[
    ['world',identity.world_name,identity.world_method,'世界模板 · '+identity.world_template_id],
    ['cult',identity.cult_name,identity.cult_method,'候选教团 · 所属世界 '+identity.world_name],
    ['person',identity.person_name,identity.person_method,'候选人物 · '+identity.cult_name]
  ].map(([kind,title,method,belong],i)=>`<article class="study-card ${kind}"><div class="study-card-art">${studyImage(kind)}</div><div class="study-card-caption"><small>${['I','II','III'][i]}</small><h2>${E(title)}</h2><p>${E(belong)}</p><p class="study-method">${E(method)}</p></div></article>`).join('')}</div>
  <div class="study-gallery-note"><span>图像为原 PNG 等比缩放预览；三联画无滤镜、透明度或遮罩。</span><span>${E(identity.identity_status)} · 1–3 切换 UI 承托</span></div>${studyParameters()}
  <p class="study-contract-note">世界沿用原作生成器；教团与人物是二维绘制候选，尚未共享完整生成算法。交互预览中的机制文字仍来自原夹具，不表示这些候选对象已接入正式世界。</p>`;
  document.querySelector('#study-enter')?.addEventListener('click',()=>showStudyGallery(false));
  document.querySelector('#study-return-gallery')?.addEventListener('click',()=>showStudyReference(false));
  document.querySelector('#fit').inert = study.gallery;
  document.querySelector('#study-gallery').classList.toggle('active', study.gallery&&!study.reference);
  document.querySelector('#study-reference').classList.toggle('active', study.gallery&&study.reference);
  document.querySelectorAll('[data-study-skin]').forEach(b=>b.classList.toggle('active',Number(b.dataset.studySkin)===study.skin));
}
function showStudyGallery(show) { study.gallery=show; if(show) study.reference=false; renderStudyGallery();return settleStudy(); }
function showStudyReference(show=true) { study.reference=show;study.gallery=true;renderStudyGallery();return settleStudy(); }
function setStudySkin(index) { study.skin=index; document.body.dataset.studySkin=String(index); render(); renderStudyGallery(); return settleStudy(); }
async function settleStudy() {
  await new Promise(resolve => requestAnimationFrame(resolve));
  const finite = document.getAnimations().filter(animation => Number.isFinite(animation.effect.getComputedTiming().endTime));
  await Promise.allSettled(finite.map(animation => animation.finished));
  await Promise.all(Array.from(document.images).map(image => image.decode().catch(() => {})));
}
function visitStudyScene(scene) {
  // Authoring shortcuts select a fixture state; they never invoke payment/settlement.
  S.eventPending=false; S.toast=null; S.peek=null; S.modal=null; S.focus=null;
  if(scene==='overview') S.world=null;
  else { S.world=0; if(scene==='cult') S.focus='cult'; if(scene==='prayer') { S.focus='prayer'; S.modal='prayerScene'; } if(scene==='person') { S.modal='archive'; S.archiveTab='people'; S.archivePerson=0; } }
  showStudyGallery(false); render();
  document.querySelector('#study-scene').value = scene;
  return settleStudy();
}
studyBar.addEventListener('click', e=>{ const b=e.target.closest('[data-study-skin]'); if(b)setStudySkin(Number(b.dataset.studySkin)); });
document.querySelector('#study-family').addEventListener('change',e=>{study.family=Number(e.target.value);setupScene();render();renderStudyGallery();});
document.querySelector('#study-gallery').addEventListener('click',()=>showStudyGallery(true));
document.querySelector('#study-reference').addEventListener('click',()=>showStudyReference());
document.querySelector('#study-scene').addEventListener('change',e=>visitStudyScene(e.target.value));
document.addEventListener('keydown',e=>{if(/^[1-3]$/.test(e.key)&&!e.target.matches('input,select,textarea')){e.preventDefault();setStudySkin(Number(e.key)-1);} if(e.key==='Escape'&&study.gallery){e.preventDefault();showStudyGallery(false);}},true);
resize = function(){ const availableHeight=innerHeight-66;const scale=Math.min(innerWidth/1600,availableHeight/900);const fit=document.querySelector('#fit');fit.style.top='calc(50% + 33px)';fit.style.transform=`translate(-50%,-50%) scale(${scale})`; };
S.eventPending=false;
setupScene();setStudySkin(0);resize();
