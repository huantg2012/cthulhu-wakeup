"""Direct 2D pixel drawing. No meshes, projection engine, or image-generation API.
Run: python3 draw_family.py. Geometry and ordered material strokes are authored in 192px space.
"""
from pathlib import Path
from PIL import Image, ImageDraw
import csv, random
ROOT = Path(__file__).resolve().parent
W = 192
C = dict(bg='#080e18', mist='#101e2b', abyss='#0d2232', deepest='#101a28',
         ink='#111b2b', rock='#243644', rocklight='#3a525e', stone='#365265',
         stonehi='#5f7885', edge='#8ba7ac', bone='#d2cfb4', gold='#9b8d61',
         roof='#264a60', roofhi='#49778b', roofs='#1c3449', water='#1b5b6b',
         wave='#398294', foam='#84afb0', glow='#bde2bb', warm='#e7c58b',
         cloth='#254451', clothhi='#456674', clothlight='#68848c', clothshadow='#172c39', skin='#aaad9a', skinshadow='#687e7c')

def new():
    im=Image.new('RGB',(W,W),C['bg']); return im,ImageDraw.Draw(im)
def poly(d,pts,c):d.polygon(pts,fill=C.get(c,c))
def line(d,pts,c,width=1):d.line(pts,fill=C.get(c,c),width=width)
def rect(d,box,c):d.rectangle(box,fill=C.get(c,c))
def ellipse(d,box,c):d.ellipse(box,fill=C.get(c,c))
def save(im,name):
    (ROOT/'assets').mkdir(exist_ok=True)
    im.resize((768,768),Image.Resampling.NEAREST).save(ROOT/'assets'/name)

def background(d):
    # Quiet stepped aureole, deliberately no generated noise or fake pixel filter.
    ellipse(d,(22,31,174,176),'#0b1521')
    ellipse(d,(36,45,163,170),'#0d1925')
    ellipse(d,(41,157,162,179),'#060d16')

def lamp(d,x,y):
    line(d,[(x,y-8),(x,y-3)],'gold')
    poly(d,[(x-3,y-4),(x+3,y-4),(x+2,y+2),(x-2,y+2)],'ink')
    rect(d,(x-1,y-3,x+1,y),'warm'); line(d,[(x-3,y+2),(x+3,y+2)],'gold')
    rect(d,(x,y-2,x,y),'glow')

def cult(seed,variant=False):
    im,d=new(); background(d); rng=random.Random(seed)
    # Water occupies a bounded, basin-like island pedestal.
    poly(d,[(21,125),(79,101),(150,116),(175,139),(155,160),(100,182),(34,159)],'ink')
    poly(d,[(22,124),(80,100),(149,115),(174,137),(154,155),(99,176),(34,153)],'water')
    poly(d,[(31,137),(75,116),(145,125),(161,138),(144,151),(99,166),(47,150)],'abyss')
    for x,y,length in [(27,130,10),(39,151,12),(54,158,19),(77,168,15),(110,164,10),(137,153,12),(154,142,12),(35,128,12),(148,123,10),(116,171,8)]:
        line(d,[(x,y),(x+length,y-3)],'wave');line(d,[(x+3,y+2),(x+length-2,y)],'water')
    line(d,[(24,124),(33,128),(47,124)],'foam')
    # Fractured stone foundation with visible depth and overhang.
    top=[(42,119),(82,101),(148,122),(146,145),(99,167),(45,146)]
    poly(d,[(42,120),(46,151),(98,174),(145,153),(148,124),(99,145)],'deepest')
    poly(d,[(47,145),(98,164),(98,174),(48,153)],'rock')
    poly(d,[(98,162),(146,143),(145,153),(98,174)],'ink')
    poly(d,top,'rocklight')
    poly(d,[(46,120),(83,106),(144,123),(143,139),(99,161),(49,142)],'stone')
    line(d,[(45,146),(98,168),(145,146)],'stonehi')
    for a,b in [((57,132),(85,120)),((77,151),(110,132)),((99,160),(126,145)),((52,128),(116,152)),((70,115),(137,140))]:line(d,[a,b],'rock')
    # Right-side bell tower with an asymmetrical crown.
    poly(d,[(132,73),(146,66),(146,121),(132,129)],'roofs')
    poly(d,[(120,67),(132,73),(132,129),(120,122)],'stone')
    poly(d,[(117,66),(131,48),(149,65),(132,75)],'roof')
    poly(d,[(131,48),(149,65),(132,75)],'roofs')
    line(d,[(117,66),(132,75),(149,65)],'edge')
    rect(d,(125,79,128,94),'ink');poly(d,[(136,81),(141,78),(141,94),(136,97)],'ink')
    line(d,[(120,101),(132,108),(146,100)],'stonehi')
    lamp(d,139,89)
    # Main sanctuary: split slate roof, two facades, deep buttresses.
    poly(d,[(53,84),(98,104),(98,143),(53,121)],'stone')
    poly(d,[(98,104),(137,82),(137,121),(98,143)],'roofs')
    poly(d,[(49,83),(86,43),(140,81),(98,106)],'roof')
    poly(d,[(86,43),(140,81),(98,106)],'roofs')
    poly(d,[(53,81),(86,47),(99,101)],'roofhi')
    line(d,[(49,83),(98,106),(140,82)],'ink',2)
    line(d,[(49,82),(98,104),(140,80)],'edge')
    line(d,[(86,43),(140,80)],'stonehi')
    # Slate courses follow the roof planes, rather than random texture.
    for k in range(1,7):
        t=k/8
        ax=round(86+(49-86)*t);ay=round(43+(83-43)*t)
        bx=round(86+(98-86)*t);by=round(43+(104-43)*t)
        line(d,[(ax,ay),(bx,by)],'roof')
        line(d,[(bx+2,by),(round(86+(139-86)*t),round(43+(81-43)*t))],'ink')
    for x,y in [(61,76),(68,68),(76,61),(81,80),(90,91)]:line(d,[(x,y),(x+2,y+5)],'stonehi')
    # Gothic aperture and masonry on the lit facade.
    poly(d,[(63,99),(69,90),(75,105),(75,118),(63,112)],'ink')
    line(d,[(62,112),(62,99),(69,88),(76,104),(76,119)],'stonehi')
    line(d,[(69,95),(69,114)],'gold');line(d,[(64,104),(74,109)],'gold')
    for x,y in [(55,111),(77,111),(85,127),(57,119),(81,118)]:line(d,[(x,y),(x+8,y+4)],'rocklight')
    # Pointed entrance is cut into the shadow facade.
    poly(d,[(108,119),(108,112),(116,101),(124,105),(124,129),(108,137)],'ink')
    line(d,[(106,137),(106,112),(116,99),(126,103),(126,129)],'stonehi',2)
    line(d,[(111,131),(111,114),(117,105)],'rocklight')
    # Narrow front stair, each tread has separate top and front face.
    for k in range(5):
        y=134+k*3;x=106-k*2
        poly(d,[(x,y),(124+k,y-9),(127+k,y-7),(x+3,y+3)],'stonehi')
        line(d,[(x+3,y+3),(127+k,y-7)],'rock')
    for x,y in [(54,104),(84,119),(133,110)]:
        poly(d,[(x,y-13),(x+3,y-11),(x+3,y+17),(x-2,y+14)],'rocklight')
        line(d,[(x,y-13),(x,y+14)],'stonehi')
    # Small detached reliquary, a real compound rather than one building.
    poly(d,[(44,99),(56,105),(56,127),(44,122)],'stone')
    poly(d,[(56,105),(67,99),(67,120),(56,127)],'roofs')
    poly(d,[(41,99),(51,79),(70,98),(56,107)],'roofhi')
    poly(d,[(51,79),(70,98),(56,107)],'roof')
    line(d,[(41,99),(56,107),(70,98)],'edge')
    poly(d,[(49,110),(52,109),(54,112),(54,121),(49,119)],'ink')
    # Vessel, votive candles and offerings on the open terrace.
    ellipse(d,(70,131,91,143),'ink');poly(d,[(71,136),(73,145),(82,149),(90,143),(91,136)],'rock')
    ellipse(d,(69,129,92,141),'stonehi');ellipse(d,(73,132,88,138),'ink')
    line(d,[(75,134),(83,136),(87,133)],'glow')
    for x,y in [(68,139),(92,147),(98,126)]:
        line(d,[(x,y),(x,y-6)],'bone');rect(d,(x,y-8,x,y-7),'warm')
    lamp(d,128,113);lamp(d,57,117)
    # Seed changes the physical crown and cracks, with layout identity preserved.
    if variant:
        poly(d,[(83,48),(86,23),(91,47)],'roofhi');line(d,[(86,23),(91,47)],'edge')
        line(d,[(86,23),(86,18)],'gold')
    else:
        line(d,[(86,44),(86,30)],'gold');line(d,[(81,33),(86,36),(91,31)],'gold')
        rect(d,(85,29,87,31),'bone')
    for _ in range(6):
        x=rng.randrange(50,130);y=rng.randrange(147,156)
        line(d,[(x,y),(x+2,y+3),(x,y+5)],'ink')
    save(im,'pixel-cult-alt.png' if variant else 'pixel-cult.png')

def person(seed,variant=False):
    im,d=new(); background(d)
    # Silhouette: leaning head, one higher shoulder, asymmetric lower cloth.
    poly(d,[(42,174),(39,143),(48,98),(66,81),(69,55),(87,27),(106,32),(122,58),(120,85),(141,98),(154,135),(149,173),(122,183),(83,180)],'ink')
    poly(d,[(47,171),(46,137),(55,104),(75,83),(109,85),(136,100),(148,136),(143,176),(116,182),(82,175)],'clothshadow')
    # The hood is drawn in planar cloth shapes with an offset point, not an oval ring.
    poly(d,[(63,91),(67,54),(85,25),(106,31),(123,56),(121,87),(111,104),(88,113)],'cloth')
    poly(d,[(67,55),(85,25),(106,31),(94,36),(78,59),(75,86),(65,92)],'clothhi')
    poly(d,[(106,31),(123,56),(121,87),(111,103),(109,85),(112,58)],'clothshadow')
    poly(d,[(78,57),(94,38),(110,53),(113,76),(102,94),(86,91),(75,78)],'#080f18')
    poly(d,[(79,58),(94,38),(103,46),(92,44)],'clothlight')
    line(d,[(78,57),(75,78),(86,94),(102,96),(114,77)],'clothhi')
    # A partially seen cheek and nose stay in shadow, enough to avoid an empty suit.
    poly(d,[(105,60),(108,68),(106,73),(110,75),(103,78),(99,86),(93,83),(100,70)],'#263744')
    line(d,[(105,67),(104,73),(108,75)],'rocklight')
    line(d,[(95,85),(101,84)],'stone')
    # Shoulder cape drapes in long, broken wedges; lit edges agree with top-left light.
    poly(d,[(65,86),(82,96),(89,111),(69,126),(51,132),(54,107)],'clothhi')
    poly(d,[(65,87),(71,98),(61,118),(54,121),(58,104)],'clothlight')
    poly(d,[(82,98),(88,111),(70,126),(77,111)],'clothshadow')
    poly(d,[(112,88),(134,98),(146,127),(131,137),(112,119),(104,106)],'cloth')
    poly(d,[(117,93),(132,103),(139,122),(133,126)],'clothhi')
    line(d,[(112,88),(119,98),(126,117)],'clothlight')
    # Torso drapery, high-frequency detail only follows fold direction.
    poly(d,[(75,116),(105,110),(122,124),(134,173),(113,181),(76,174),(60,165)],'cloth')
    for pts,col in [([(78,116),(84,128),(75,171),(66,166)],'clothhi'), ([(91,119),(96,130),(90,178),(82,176)],'clothshadow'), ([(103,117),(109,128),(111,179),(101,179)],'clothhi'), ([(115,126),(119,140),(130,173),(120,177)],'clothshadow')]:poly(d,pts,col)
    for x,y in [(77,139),(75,151),(104,151),(108,169),(66,157)]:line(d,[(x,y),(x-2,y+9)],'clothlight')
    # Left forearm is lifted into the offering; right hand supports it from below.
    poly(d,[(52,116),(63,122),(73,132),(87,127),(92,136),(76,148),(63,144),(49,130)],'clothshadow')
    poly(d,[(52,117),(59,120),(65,132),(76,137),(86,133),(86,138),(75,143),(63,139),(52,128)],'clothhi')
    poly(d,[(138,121),(148,135),(137,151),(111,152),(105,140),(127,139)],'clothshadow')
    poly(d,[(140,125),(143,135),(132,145),(113,146),(111,141),(127,140)],'clothhi')
    # Angular hands with separate finger silhouettes and knuckles.
    poly(d,[(82,129),(87,124),(94,126),(100,132),(98,135),(91,131),(93,139),(88,140)],'skinshadow')
    line(d,[(85,129),(89,127),(96,131)],'skin')
    line(d,[(88,132),(94,135)],'bone')
    poly(d,[(107,139),(115,138),(119,142),(114,147),(105,147),(101,143)],'skinshadow')
    line(d,[(105,141),(113,141),(116,142)],'skin');line(d,[(104,144),(112,144)],'skin')
    if variant:
        poly(d,[(91,118),(110,113),(116,140),(97,145)],'gold')
        poly(d,[(93,119),(108,116),(113,138),(98,142)],'deepest')
        line(d,[(97,120),(100,136),(110,133)],'bone')
        line(d,[(94,117),(99,144)],'edge')
    else:
        # Sealed tide vessel with facets, a weighted neck and an engraved eye-shaped seam.
        poly(d,[(95,111),(105,111),(106,118),(111,125),(109,139),(99,144),(91,137),(90,124),(96,117)],'rocklight')
        poly(d,[(95,119),(101,117),(103,141),(98,140),(94,135)],'stonehi')
        poly(d,[(104,120),(110,125),(108,137),(103,140)],'roofs')
        rect(d,(94,109,106,113),'gold');line(d,[(94,109),(105,109)],'bone')
        line(d,[(96,126),(100,123),(105,126),(101,130),(96,126)],'gold')
        rect(d,(100,125,101,127),'glow')
    # Functional straps and a tiny clasp, no giant fantasy ornament.
    line(d,[(79,97),(93,114),(111,99)],'gold')
    poly(d,[(91,113),(95,112),(97,116),(93,120),(90,117)],'bone')
    line(d,[(57,111),(61,121)],'edge');line(d,[(132,107),(136,116)],'clothlight')
    # A few authored seam stitches and a frayed hem.
    for x,y in [(66,155),(65,160),(64,165),(119,158),(121,163),(123,169)]:line(d,[(x,y),(x+2,y)],'stonehi')
    for x,y in [(78,175),(84,177),(111,181),(119,180),(138,175)]:line(d,[(x,y),(x,y+2)],'clothhi')
    save(im,'pixel-person-alt.png' if variant else 'pixel-person.png')

if __name__=='__main__':
    for row in csv.DictReader((ROOT/'pixel-family.csv').open()):
        alt=row['id'].endswith('alt')
        cult(int(row['seed']),alt);person(int(row['seed']),alt)
    print('Wrote 4 direct-drawn 2D pixel assets at 768px (192px source).')
