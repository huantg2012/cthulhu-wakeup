# Subset Noto CJK fonts to only the glyphs used by the scripts (keeps .pck small).
import glob, sys
from fontTools.ttLib import TTCollection
from fontTools import subset

root = sys.argv[1] if len(sys.argv) > 1 else '/workspace/project'
txt = ''
for f in glob.glob(root + '/scripts/*.gd'):
    txt += open(f, encoding='utf-8').read()
chars = set(txt) | set(chr(c) for c in range(32, 127)) | set('０１２３４５６７８９，。、：；！？（）【】「」《》—…·★☆')
text = ''.join(sorted(chars))

def make(src, idx, out):
    tt = TTCollection(src).fonts[idx]
    opts = subset.Options()
    opts.layout_features = ['*']
    opts.name_IDs = ['*']
    opts.notdef_outline = True
    opts.glyph_names = False
    sub = subset.Subsetter(opts)
    sub.populate(text=text)
    sub.subset(tt)
    tt.flavor = None
    tt.save(out)
    print(out, 'glyphs', len(tt.getGlyphOrder()))

make('/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc', 2, root + '/fonts/ui.ttf')
make('/usr/share/fonts/opentype/noto/NotoSerifCJK-Bold.ttc', 2, root + '/fonts/title.ttf')
