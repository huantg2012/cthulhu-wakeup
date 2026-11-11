// Snapshot of the selected original palette, verified by the server against
// godot-base/scripts/data.gd. These roles participate before lighting/post.
import {mix} from './engine.js';
export const tide={archetype:0,styleSid:0,palette:0,worldSeed:1339,c0:'#04161a',c1:'#0b3b3d',c2:'#1f6b5e',c3:'#8c9a6a',c4:'#6bff9e',nebula:'#5a2a6e',corruption:'#c040ff',star:'#fff4c8'};
export function roles(w=tide){return{
 cloth:mix(w.c2,w.c3,.44),clothShadow:mix(w.c0,w.nebula,.22),
 linen:mix(w.c3,w.star,.19),linenShadow:mix(w.c1,w.c3,.4),
 stone:mix(w.c3,w.star,.08),stoneShadow:mix(w.c0,w.c2,.35),
 salt:mix(w.c3,w.star,.37),wet:mix(w.c1,w.c2,.25),
 copper:mix(w.c3,'#b78b50',.55),water:mix(w.c1,w.c2,.5),light:w.c4,
 violet:mix(w.c0,w.nebula,.66)
};}
