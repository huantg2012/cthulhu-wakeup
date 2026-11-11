"""Build visual-only study from the accepted continuous interaction fixture."""
from pathlib import Path
root = Path(__file__).resolve().parent
source = root.parent.parent / 'presentation-rebuild' / 'interaction-slice.html'
html = source.read_text()
html = html.replace('<title>邪神苏醒 · 诸界之间 · 交互样板</title>', '<title>邪神苏醒 · 立绘与界面承托探索</title>')
html = html.replace('ritual-assets/', '../../presentation-rebuild/ritual-assets/')
html = html.replace('href="interface-', 'href="../../presentation-rebuild/interface-')
html = html.replace('</head>', '<link rel="stylesheet" href="ui.css"></head>')
html = html.replace('</body>', '<script src="ui.js"></script></body>')
(root / 'index.html').write_text(html)
print('Built index.html from accepted interaction fixture; original unchanged.')
