"""Publish the existing approved-composition gallery with the baked native faces."""
from pathlib import Path
import json
import hashlib

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'docs/art/visual-generation/card-illustration-study/full-deck-drafts'
OUT = SOURCE.parent / 'painted-deck'

def main():
    draft = json.loads((SOURCE / 'manifest.json').read_text())
    baked = json.loads((OUT / 'manifest.json').read_text())
    assert len(baked['images']) == 71 and len(baked['records']) == 72
    for entry in draft['cards']:
        key = entry['illustration_key']
        assert baked['records'][entry['id']] == key
        assert (OUT / 'cards' / (entry['id'].replace('/', '__')+'.png')).is_file()
        assert hashlib.sha256((OUT / entry['art_path']).read_bytes()).hexdigest() == baked['images'][key]['png_sha256']
        assert (ROOT / baked['images'][key]['resource'].removeprefix('res://')).is_file()
    page = (SOURCE / 'index.html').read_text()
    page = page.replace('邪神苏醒 · 全目录构形审阅', '邪神苏醒 · 正式固化立绘')
    page = page.replace('构形色稿 · 尚待制作人定型 · 非正式接入', '构形已获认可 · 原生成器暗黑厚涂后期 · 已接入正式 Session')
    page = page.replace('图稿仍处于造型与色块阶段，正式笔触及渲染须在构形确认后制作。', '图像已离线通过原生成器暗黑厚涂后期，固化为 512px 原生纹理。游戏只加载成品，不会重新绘制。')
    page = page.replace('href="svg/', 'href="../full-deck-drafts/svg/')
    page = page.replace('只看构形', '只看立绘')
    page = page.replace('未改正式资产映射、玩法或存档。', '已替换正式资产映射；玩法与存档不变。后期成品的审美仍交制作人复审。')
    (OUT / 'index.html').write_text(page)
    (OUT / 'coverage.json').write_text(json.dumps({
        'definitions':64, 'support_surfaces':8, 'unique_images':71,
        'checked':['definition-to-art mapping','native saved texture presence','PNG provenance','72 native card captures'],
        'runtime_evidence':'native/', 'notes':'All-catalogue rendering is not a playthrough of every locked card.'
    }, ensure_ascii=False, indent=2)+'\n')
    print('PAINTED_REVIEW_OK: 72 native cards, 71 fixed images, approved source SVG links')

if __name__ == '__main__': main()
