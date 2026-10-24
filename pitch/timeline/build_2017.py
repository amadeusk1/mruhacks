"""Builds clip-2017.html from the registry's vfx-shatter block.

Panel A (the glass) holds the glowing Club Penguin logo; panel B (behind) is the
empty dark that is left. An overlay above the WebGL canvas carries the Disney
wordmark, its light trail, the impact flash and the "2017" label.
Run: python -I build_2017.py
"""
import re

src = open("compositions/vfx-shatter.html", encoding="utf-8").read()
path_d = re.search(r'd="([^"]+)"', open("assets/disney-wordmark.svg", encoding="utf-8").read()).group(1)

DURATION = 3.6
IMPACT = 0.85

s = src.replace('data-composition-id="glass-shatter"', 'data-composition-id="clip2017"')
s = s.replace('window.__timelines["glass-shatter"]', 'window.__timelines["clip2017"]')
s = s.replace('data-duration="12"', f'data-duration="{DURATION}"')
s = s.replace("var DURATION = 12;", f"var DURATION = {DURATION};")
s = s.replace("var CRACK_START = 2.0;", f"var CRACK_START = {IMPACT};")
s = s.replace("var CRACK_END = 4.0;", "var CRACK_END = 1.2;")
s = s.replace("var SHATTER_START = 4.0;", "var SHATTER_START = 1.2;")
s = s.replace("var SHATTER_SETTLE = 10.0;", "var SHATTER_SETTLE = 2.6;")
s = s.replace("<title>HTML Glass Shatter</title>", "<title>2017</title>")

panel_a = """<section class="panel" id="panel-a" data-panel-a style="width: 1920px; height: 1080px">
          <div class="a-scene"><img class="a-logo" src="assets/cp-logo.png" alt="" /></div>
        </section>"""
panel_b = """<section class="panel" id="panel-b" data-panel-b style="width: 1920px; height: 1080px">
          <div class="b-scene"></div>
        </section>"""
s = re.sub(r'<section class="panel" id="panel-a".*?</section>', panel_a, s, count=1, flags=re.S)
s = re.sub(r'<section class="panel" id="panel-b".*?</section>', panel_b, s, count=1, flags=re.S)

css = """
      .a-scene {
        width: 100%;
        height: 100%;
        background: radial-gradient(ellipse 60% 55% at 50% 50%, #12425a 0%, #0a2433 55%, #061520 100%);
        display: grid;
        place-items: center;
      }
      .a-logo { width: 820px; filter: drop-shadow(0 0 60px rgba(90, 190, 230, 0.45)); }
      .b-scene {
        width: 100%;
        height: 100%;
        background: radial-gradient(ellipse 70% 60% at 50% 45%, #0a1f2c 0%, #050e15 100%);
      }
      #ov { position: absolute; inset: 0; z-index: 10; pointer-events: none; }
      #ov-year {
        position: absolute;
        left: 120px;
        top: 96px;
        font: 800 30px/1 "Inter", system-ui, sans-serif;
        letter-spacing: 0.24em;
        color: #7fd3e6;
      }
      #ov-year::after { content: ""; display: block; width: 44px; height: 3px; margin-top: 14px; background: #7fd3e6; opacity: 0.7; }
      #ov-trail { position: absolute; inset: 0; }
      #ov-flash {
        position: absolute;
        left: 960px;
        top: 540px;
        width: 1400px;
        height: 1400px;
        margin: -700px 0 0 -700px;
        border-radius: 50%;
        background: radial-gradient(circle, rgba(235, 248, 255, 0.95) 0%, rgba(127, 211, 230, 0.35) 25%, rgba(127, 211, 230, 0) 60%);
        opacity: 0;
      }
      #ov-disney {
        position: absolute;
        left: 0;
        top: 0;
        width: 440px;
        filter: drop-shadow(0 0 22px rgba(127, 211, 230, 0.9));
      }
"""
s = s.replace("    </style>", css + "    </style>", 1)

overlay = f"""
      <!-- Overlay above the glass: Disney streak, light trail, impact flash, year -->
      <div id="ov">
        <svg id="ov-trail" viewBox="0 0 1920 1080" width="1920" height="1080">
          <defs>
            <linearGradient id="trail-g" x1="0" y1="1" x2="1" y2="0">
              <stop offset="0" stop-color="#7fd3e6" stop-opacity="0" />
              <stop offset="1" stop-color="#eaf8ff" stop-opacity="1" />
            </linearGradient>
          </defs>
          <path id="trail" d="M -260 980 Q 420 900 960 540" fill="none" stroke="url(#trail-g)" stroke-width="10" stroke-linecap="round" />
        </svg>
        <div id="ov-flash"></div>
        <svg id="ov-disney" viewBox="0 0 700 294.4"><path fill="#eaf6fc" d="{path_d}" /></svg>
        <div id="ov-year">2017</div>
      </div>

      <!-- Driver clip -->"""
s = s.replace("\n      <!-- Driver clip -->", overlay, 1)

# Overlay motion lives on the block's timeline, so every frame is a function of time.
motion = f"""
      // ── Overlay motion ────────────────────────────────────────────────
      (function () {{
        var IMPACT = {IMPACT};
        var trail = document.getElementById("trail");
        var LEN = trail.getTotalLength();
        trail.style.strokeDasharray = LEN;
        var wm = document.getElementById("ov-disney");
        var WM_W = 440, WM_H = 440 * 294.4 / 700;
        function quad(p, a, c, b) {{ var q = 1 - p; return q * q * a + 2 * q * p * c + p * p * b; }}
        var fly = {{ p: 0 }};
        function place() {{
          var p = fly.p, x, y, sc, rot;
          if (p <= 1) {{
            // approach: along the trail into the logo's centre
            x = quad(p, -260, 420, 960); y = quad(p, 980, 900, 540);
            sc = 0.55 + 0.45 * p; rot = -18 + 14 * p;
          }} else {{
            // rebound: up to rest above where the logo was
            var r = p - 1;
            x = quad(r, 960, 1180, 960); y = quad(r, 540, 300, 210);
            sc = 1.0 - 0.15 * r; rot = -4 + 4 * r;
          }}
          wm.style.transform = "translate(" + (x - WM_W / 2) + "px," + (y - WM_H / 2) + "px) scale(" + sc + ") rotate(" + rot + "deg)";
          trail.style.strokeDashoffset = LEN * (1 - Math.min(1, p));
        }}
        tl.fromTo(fly, {{ p: 0 }}, {{ p: 1, duration: IMPACT - 0.3, ease: "power2.in", onUpdate: place, immediateRender: true }}, 0.3);
        tl.to(fly, {{ p: 2, duration: 0.6, ease: "expo.out", onUpdate: place }}, IMPACT);
        tl.fromTo("#ov-disney", {{ opacity: 0 }}, {{ opacity: 1, duration: 0.12 }}, 0.3);
        tl.to("#ov-disney", {{ opacity: 0.85, duration: 1.0, ease: "power2.inOut" }}, IMPACT + 0.9);
        tl.fromTo("#trail", {{ opacity: 1 }}, {{ opacity: 0, duration: 0.6, ease: "power2.out" }}, IMPACT + 0.05);
        tl.fromTo("#ov-flash", {{ opacity: 0, scale: 0.2 }}, {{ opacity: 1, scale: 0.6, duration: 0.08, ease: "power4.out" }}, IMPACT);
        tl.to("#ov-flash", {{ opacity: 0, scale: 1, duration: 0.5, ease: "power2.out" }}, IMPACT + 0.08);
        // Impact shake on the glass only
        var shake = [[14, -8], [-11, 6], [8, -4], [-5, 3], [2, -1], [0, 0]];
        shake.forEach(function (xy, i) {{
          tl.set("#scene-canvas", {{ x: xy[0], y: xy[1] }}, IMPACT + i * 0.033);
        }});
      }})();

      window.__timelines["clip2017"] = tl;"""
s = s.replace('\n      window.__timelines["clip2017"] = tl;', motion, 1)

# The renderer has no html-in-canvas (drawElementImage), so paint both panels
# straight onto their 2D canvases: a gradient, and the logo on panel A.
paint = """      // The logo <img> lives in the page, so the renderer waits for it before frame 0.
      var cpLogo = document.querySelector(".a-logo");

      function capturePanels() {
        var g = ctxA.createRadialGradient(W / 2, H / 2, 0, W / 2, H / 2, W * 0.6);
        g.addColorStop(0, "#12425a");
        g.addColorStop(0.55, "#0a2433");
        g.addColorStop(1, "#061520");
        ctxA.fillStyle = g;
        ctxA.fillRect(0, 0, W, H);
        if (cpLogo.complete && cpLogo.naturalWidth) {
          // Skip the logo's own small "Disney" line (top 52 px of the file) so only one
          // Disney is on screen: the one that hits it.
          var TOP = 60;
          var sh = cpLogo.naturalHeight - TOP;
          var lw = 900, lh = lw * sh / cpLogo.naturalWidth;
          ctxA.save();
          ctxA.shadowColor = "rgba(90, 190, 230, 0.55)";
          ctxA.shadowBlur = 70;
          ctxA.drawImage(cpLogo, 0, TOP, cpLogo.naturalWidth, sh, (W - lw) / 2, (H - lh) / 2, lw, lh);
          ctxA.restore();
        }
        var gb = ctxB.createRadialGradient(W / 2, H * 0.45, 0, W / 2, H * 0.45, W * 0.65);
        gb.addColorStop(0, "#0a1f2c");
        gb.addColorStop(1, "#050e15");
        ctxB.fillStyle = gb;
        ctxB.fillRect(0, 0, W, H);
      }"""
s, n = re.subn(r"      function capturePanels\(\) \{.*?\n      \}", paint, s, count=1, flags=re.S)
assert n == 1, "capturePanels not found"
# The unsupported-feature banner would show on every frame; drop the check.
s = s.replace('if (!isSupported()) {\n        document.getElementById("error-overlay").classList.add("visible");\n      }', "")

open("clip-2017.html", "w", encoding="utf-8").write(s)
print("wrote clip-2017.html", len(s))
