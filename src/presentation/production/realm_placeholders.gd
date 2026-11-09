extends RefCounted
## Geometry copied from the locked sample’s island() placeholders.
const SHAPES := [
"""
<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="920" viewBox="0 0 600 460" aria-hidden="true">
<defs>
<linearGradient id="rock0" x2=".4" y2="1">
<stop stop-color="#34505e">
</stop>
<stop offset="1" stop-color="#0b1420">
</stop>
</linearGradient>
<linearGradient id="wall0" x2="1" y2=".8">
<stop stop-color="#718f99">
</stop>
<stop offset="1" stop-color="#253e4e">
</stop>
</linearGradient>
<radialGradient id="glow0">
<stop stop-color="#718f99" stop-opacity=".15">
</stop>
<stop offset="1" stop-color="#718f99" stop-opacity="0">
</stop>
</radialGradient>
</defs>
<ellipse cx="300" cy="245" rx="294" ry="190" fill="url(#glow0)">
</ellipse>
<ellipse cx="300" cy="319" rx="240" ry="80" fill="none" stroke="#718f99" opacity=".12">
</ellipse>
<ellipse cx="300" cy="319" rx="263" ry="90" fill="none" stroke="#718f99" opacity=".06">
</ellipse>
<path d="M75 272L195 227 398 225 518 274 456 337 310 405 173 355Z" fill="url(#rock0)">
</path>
<path d="M75 272L232 205 412 218 518 274 341 339 187 315Z" fill="#213a47" stroke="#718f99" stroke-opacity=".4">
</path>
<path d="M187 315L310 405M341 339L310 405M456 299L420 351M135 296L173 355" fill="none" stroke="#55707c" opacity=".27">
</path>
<path d="M135 277L291 222 446 270 307 319Z" fill="#344b54" opacity=".6">
</path>
<path d="M156 284L310 231M256 306L411 253M222 250L362 299" stroke="#829396" opacity=".18">
</path>
<g stroke="#8ba5ab" stroke-opacity=".25">
<path d="M235 249V139L310 111 378 140V258L307 286Z" fill="url(#wall0)">
</path>
<path d="M310 111V286L378 258V140Z" fill="#203a48">
</path>
<path d="M225 138L310 101 388 138 310 174Z" fill="#789094">
</path>
<path d="M256 128V87L308 64 353 88V137L310 156Z" fill="#4d6975">
</path>
<path d="M308 64V156L353 137V88Z" fill="#233e4e">
</path>
<path d="M245 87L307 57 364 87 309 113Z" fill="#83999a">
</path>
<path d="M272 75V40L308 24 336 40V80L307 91Z" fill="#587985">
</path>
<path d="M308 24V91L336 80V40Z" fill="#2b4755">
</path>
<path d="M255 191L286 177V216L255 231ZM332 189L355 178V218L332 229Z" fill="#102431">
</path>
<path d="M282 275V239L307 230V286" fill="#132d3b">
</path>
<path d="M149 274V218L205 196 239 213V282L194 302Z" fill="#4a6471">
</path>
<path d="M194 214V302L239 282V213L205 196Z" fill="#263f4d">
</path>
<path d="M139 218L198 188 249 212 194 240Z" fill="#68848a">
</path>
<path d="M386 264V226L430 211 467 229V278L424 299Z" fill="#43616e">
</path>
<path d="M424 244V299L467 278V229Z" fill="#284150">
</path>
<path d="M375 224L426 203 478 228 424 252Z" fill="#789194">
</path>
</g>
<g fill="#718f99">
<circle cx="308" cy="25" r="3" class="pulse">
</circle>
<circle cx="192" cy="307" r="2">
</circle>
<circle cx="424" cy="299" r="2">
</circle>
</g>
<path d="M95 352Q300 460 497 352" stroke="#718f99" opacity=".1" fill="none">
</path>
</svg>
""",
"""
<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="920" viewBox="0 0 600 460" aria-hidden="true">
<defs>
<linearGradient id="rock1" x2=".4" y2="1">
<stop stop-color="#34505e">
</stop>
<stop offset="1" stop-color="#0b1420">
</stop>
</linearGradient>
<linearGradient id="wall1" x2="1" y2=".8">
<stop stop-color="#829482">
</stop>
<stop offset="1" stop-color="#253e4e">
</stop>
</linearGradient>
<radialGradient id="glow1">
<stop stop-color="#829482" stop-opacity=".15">
</stop>
<stop offset="1" stop-color="#829482" stop-opacity="0">
</stop>
</radialGradient>
</defs>
<ellipse cx="300" cy="245" rx="294" ry="190" fill="url(#glow1)">
</ellipse>
<ellipse cx="300" cy="319" rx="240" ry="80" fill="none" stroke="#829482" opacity=".12">
</ellipse>
<ellipse cx="300" cy="319" rx="263" ry="90" fill="none" stroke="#829482" opacity=".06">
</ellipse>
<path d="M75 272L195 227 398 225 518 274 456 337 310 405 173 355Z" fill="url(#rock1)">
</path>
<path d="M75 272L232 205 412 218 518 274 341 339 187 315Z" fill="#213a47" stroke="#829482" stroke-opacity=".4">
</path>
<path d="M187 315L310 405M341 339L310 405M456 299L420 351M135 296L173 355" fill="none" stroke="#55707c" opacity=".27">
</path>
<path d="M135 277L291 222 446 270 307 319Z" fill="#344b54" opacity=".6">
</path>
<path d="M156 284L310 231M256 306L411 253M222 250L362 299" stroke="#829396" opacity=".18">
</path>
<g fill="url(#wall1)" stroke="#829482" stroke-opacity=".3">
<path d="M173 277V208L212 191 248 208V292L210 308Z">
</path>
<path d="M280 292V143L312 130 343 144V303L310 319Z">
</path>
<path d="M376 269V198L410 181 445 197V281L410 295Z">
</path>
<path d="M202 195Q308 58 414 187L408 201Q309 97 217 213Z">
</path>
<path d="M250 271V227L278 213V287Z">
</path>
<path d="M343 273V217L370 226V286Z">
</path>
</g>
<ellipse cx="310" cy="211" rx="42" ry="64" fill="none" stroke="#adbea3" opacity=".5">
</ellipse>
<path d="M309 152V274M271 211h78" stroke="#adbea3" opacity=".3">
</path>
<g fill="#829482">
<circle cx="308" cy="25" r="3" class="pulse">
</circle>
<circle cx="192" cy="307" r="2">
</circle>
<circle cx="424" cy="299" r="2">
</circle>
</g>
<path d="M95 352Q300 460 497 352" stroke="#829482" opacity=".1" fill="none">
</path>
</svg>
""",
"""
<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="920" viewBox="0 0 600 460" aria-hidden="true">
<defs>
<linearGradient id="rock2" x2=".4" y2="1">
<stop stop-color="#34505e">
</stop>
<stop offset="1" stop-color="#0b1420">
</stop>
</linearGradient>
<linearGradient id="wall2" x2="1" y2=".8">
<stop stop-color="#827f9c">
</stop>
<stop offset="1" stop-color="#253e4e">
</stop>
</linearGradient>
<radialGradient id="glow2">
<stop stop-color="#827f9c" stop-opacity=".15">
</stop>
<stop offset="1" stop-color="#827f9c" stop-opacity="0">
</stop>
</radialGradient>
</defs>
<ellipse cx="300" cy="245" rx="294" ry="190" fill="url(#glow2)">
</ellipse>
<ellipse cx="300" cy="319" rx="240" ry="80" fill="none" stroke="#827f9c" opacity=".12">
</ellipse>
<ellipse cx="300" cy="319" rx="263" ry="90" fill="none" stroke="#827f9c" opacity=".06">
</ellipse>
<path d="M75 272L195 227 398 225 518 274 456 337 310 405 173 355Z" fill="url(#rock2)">
</path>
<path d="M75 272L232 205 412 218 518 274 341 339 187 315Z" fill="#213a47" stroke="#827f9c" stroke-opacity=".4">
</path>
<path d="M187 315L310 405M341 339L310 405M456 299L420 351M135 296L173 355" fill="none" stroke="#55707c" opacity=".27">
</path>
<path d="M135 277L291 222 446 270 307 319Z" fill="#344b54" opacity=".6">
</path>
<path d="M156 284L310 231M256 306L411 253M222 250L362 299" stroke="#829396" opacity=".18">
</path>
<g fill="url(#wall2)" stroke="#827f9c" stroke-opacity=".4">
<path d="M152 274V215L218 186 278 213V295L215 322Z">
</path>
<path d="M330 291V191L398 159 461 190V281L397 311Z">
</path>
<path d="M226 221V118L308 80 382 115V240L307 274Z">
</path>
<path d="M245 115L310 23 367 112 308 144Z">
</path>
<path d="M308 80V274L382 240V115Z" fill="#25374a">
</path>
</g>
<path d="M268 181L307 163 344 180M268 202L307 185 344 202M268 223L307 206 344 223" fill="none" stroke="#a1a3bc" opacity=".4">
</path>
<g fill="#827f9c">
<circle cx="308" cy="25" r="3" class="pulse">
</circle>
<circle cx="192" cy="307" r="2">
</circle>
<circle cx="424" cy="299" r="2">
</circle>
</g>
<path d="M95 352Q300 460 497 352" stroke="#827f9c" opacity=".1" fill="none">
</path>
</svg>
"""
]
