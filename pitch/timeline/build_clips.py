"""Builds clip-2022.html (police tape) and clip-now.html (friends drift apart).

The penguins are the same original drawings as the deck's Now slide, written into
the HTML as static SVG so every element is in the markup, not made by script.
Run: python -I build_clips.py
"""

HATS = {
    "beanie": """<path d="M46 84C42 40 70 22 100 22C130 22 158 40 154 84Z" fill="#d93a2f"/>
      <rect x="40" y="70" width="120" height="24" rx="12" fill="#b82b22"/>
      <path d="M58 72v20M74 71v22M90 70v24M106 70v24M122 71v22M138 72v20" stroke="rgba(0,0,0,.18)" stroke-width="3"/>
      <circle cx="100" cy="20" r="14" fill="#ea4b3f"/>""",
    "frog": """<path d="M100 26C150 26 180 70 178 128C176 150 168 160 160 162C150 120 132 84 100 84C68 84 50 120 40 162C32 160 24 150 22 128C20 70 50 26 100 26Z" fill="#5cb544"/>
      <path d="M40 160C50 120 68 86 100 86C132 86 150 120 160 160" fill="none" stroke="#efe3b0" stroke-width="6" stroke-linecap="round"/>
      <circle cx="66" cy="36" r="17" fill="#5cb544"/><circle cx="134" cy="36" r="17" fill="#5cb544"/>
      <circle cx="66" cy="34" r="10" fill="#fff"/><circle cx="134" cy="34" r="10" fill="#fff"/>
      <circle cx="67" cy="35" r="5" fill="#1b1d22"/><circle cx="133" cy="35" r="5" fill="#1b1d22"/>""",
    "wizard": """<path d="M54 74C70 50 86 14 108 -22C112 -28 120 -26 120 -18C122 14 134 46 148 74Z" fill="#6c45b8"/>
      <ellipse cx="100" cy="76" rx="74" ry="15" fill="#5a379e"/>
      <path d="M104 22l5 11 12 1-9 8 3 12-11-6-11 6 3-12-9-8 12-1z" fill="#ffd54a"/>""",
    "cowboy": """<path d="M56 66C50 20 68 2 86 6Q100 18 114 6C132 2 150 20 144 66Z" fill="#9a6538"/>
      <path d="M54 48H146V64H54Z" fill="#5f3b1f"/>
      <path d="M6 42Q30 74 100 70Q170 74 194 42Q194 86 100 92Q6 86 6 42Z" fill="#8b5a34"/>""",
    "none": "",
}


def penguin(body, dark, hat, cls="peng", pid=""):
    idattr = f' id="{pid}"' if pid else ""
    return f"""<svg{idattr} class="{cls}" viewBox="0 -40 200 270" aria-hidden="true">
      <ellipse cx="100" cy="222" rx="66" ry="9" fill="rgba(4,18,27,.3)"/>
      <ellipse cx="74" cy="212" rx="22" ry="10" fill="#f39a2b"/>
      <ellipse cx="126" cy="212" rx="22" ry="10" fill="#f39a2b"/>
      <ellipse cx="34" cy="142" rx="15" ry="40" fill="{dark}" transform="rotate(20 34 142)"/>
      <ellipse cx="166" cy="142" rx="15" ry="40" fill="{dark}" transform="rotate(-20 166 142)"/>
      <path d="M100 36C152 36 178 86 178 140C178 192 146 216 100 216C54 216 22 192 22 140C22 86 48 36 100 36Z" fill="{body}"/>
      <path d="M100 70C136 70 156 102 156 142C156 184 132 206 100 206C68 206 44 184 44 142C44 102 64 70 100 70Z" fill="#fbf4e6"/>
      <ellipse cx="80" cy="110" rx="7.5" ry="9.5" fill="#1b1d22"/>
      <ellipse cx="120" cy="110" rx="7.5" ry="9.5" fill="#1b1d22"/>
      <circle cx="82.5" cy="106.5" r="2.6" fill="#fff"/>
      <circle cx="122.5" cy="106.5" r="2.6" fill="#fff"/>
      <path d="M87 122Q100 117 113 122Q105 137 100 138Q95 137 87 122Z" fill="#f39a2b"/>
      <ellipse cx="64" cy="130" rx="9" ry="5" fill="#ff8f8f" opacity=".35"/>
      <ellipse cx="136" cy="130" rx="9" ry="5" fill="#ff8f8f" opacity=".35"/>
      {HATS[hat]}
    </svg>"""


HEAD = """<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=1920, height=1080" />
    <script src="https://cdn.jsdelivr.net/npm/gsap@3.14.2/dist/gsap.min.js"></script>
    <style>
      * { margin: 0; padding: 0; box-sizing: border-box; }
      html, body { width: 1920px; height: 1080px; overflow: hidden; background: #050e15; }
      #root {
        position: relative;
        width: 1920px;
        height: 1080px;
        overflow: hidden;
        font-family: "Inter", sans-serif;
        background: radial-gradient(ellipse 70% 60% at 50% 48%, #0d2a3a 0%, #071a26 55%, #040c12 100%);
      }
      .year {
        position: absolute;
        left: 120px;
        top: 96px;
        font: 800 30px/1 "Inter", sans-serif;
        letter-spacing: 0.24em;
        color: #7fd3e6;
        z-index: 20;
      }
      .year::after { content: ""; display: block; width: 44px; height: 3px; margin-top: 14px; background: #7fd3e6; opacity: 0.7; }
"""


# ---------------------------------------------------------------- 2022
def build_2022():
    walkers = [
        ("#3b7dd8", "#2b5ea6", "beanie", 330, 395, 150),
        ("#f2c64a", "#d3a530", "cowboy", 640, 430, 170),
        ("#8a63d2", "#6b48b0", "frog", 900, 380, 140),
        ("#f29bb8", "#d27795", "wizard", 520, 300, 115),
    ]
    pengs = "\n".join(
        f'<div class="walker" id="w{i}" style="left:{x}px; top:{y}px; width:{w}px">{penguin(b, d, h)}</div>'
        for i, (b, d, h, x, y, w) in enumerate(walkers)
    )
    # Deterministic snowflakes inside the window
    flakes = []
    seed = 11
    for i in range(26):
        seed = (seed * 16807) % 2147483647
        fx = seed % 1180
        seed = (seed * 16807) % 2147483647
        fy = seed % 560
        seed = (seed * 16807) % 2147483647
        r = 3 + seed % 4
        flakes.append(f'<i class="flake" id="f{i}" style="left:{fx}px; top:{fy - 40}px; width:{r*2}px; height:{r*2}px"></i>')
    tapes = [
        # id, top offset from centre, angle, start time, rolls from
        ("t1", 20, -6, 0.6, "left"),
    ]
    tape_html = "\n".join(
        f'<div class="tape-wrap" id="{tid}-wrap" style="top:{540 + dy - 48}px"><div class="tape" id="{tid}"></div></div>'
        for tid, dy, *_ in tapes
    )
    tape_js = []
    for tid, dy, ang, t0, side in tapes:
        start_clip = "inset(0 100% 0 0)" if side == "left" else "inset(0 0 0 100%)"
        tape_js.append(f"""
      tl.set("#{tid}-wrap", {{ rotation: {ang} }}, 0);
      tl.fromTo("#{tid}", {{ clipPath: "{start_clip}", scaleY: 1.3 }}, {{ clipPath: "inset(0 0% 0 0%)", scaleY: 1, duration: 0.17, ease: "power3.out" }}, {t0});
      shake({t0 + 0.12});""")
    html = HEAD + """
      #win {
        position: absolute;
        left: 360px;
        top: 150px;
        width: 1200px;
        height: 760px;
        border-radius: 20px;
        overflow: hidden;
        background: #0d1f2a;
        box-shadow: 0 0 0 2px rgba(127, 211, 230, 0.18), 0 40px 90px rgba(0, 0, 0, 0.55);
      }
      #bar {
        height: 60px;
        display: flex;
        align-items: center;
        gap: 12px;
        padding: 0 24px;
        background: #0a1821;
        color: #a9c3d0;
        font: 600 24px/1 "Inter", sans-serif;
      }
      #bar span { width: 14px; height: 14px; border-radius: 50%; background: #2c4552; }
      #bar b { margin-left: 14px; font-weight: 600; }
      #view {
        position: absolute;
        left: 0;
        top: 60px;
        width: 1200px;
        height: 700px;
        overflow: hidden;
        background: linear-gradient(180deg, #a9dcf0 0%, #d6eef8 55%, #eaf6fb 100%);
      }
      .hill { position: absolute; border-radius: 50%; background: #f7fbfd; box-shadow: inset 0 18px 30px rgba(120, 170, 200, 0.18); }
      .walker { position: absolute; }
      .walker svg { width: 100%; display: block; }
      .flake { position: absolute; border-radius: 50%; background: #fff; box-shadow: 0 0 6px rgba(120, 180, 210, 0.6); }
      #off { position: absolute; inset: 0; background: #020709; opacity: 0; }
      .tape-wrap { position: absolute; left: -340px; width: 2600px; height: 96px; z-index: 10; }
      .tape {
        width: 100%;
        height: 100%;
        background:
          linear-gradient(180deg, rgba(255, 255, 255, 0.28) 0%, rgba(255, 255, 255, 0) 22%, rgba(0, 0, 0, 0) 75%, rgba(0, 0, 0, 0.3) 100%),
          repeating-linear-gradient(-45deg, #ffcd16 0 48px, #141414 48px 96px);
        box-shadow: 0 16px 28px rgba(0, 0, 0, 0.55);
      }
    </style>
  </head>
  <body>
    <div id="root" data-composition-id="clip2022" data-start="0" data-duration="2.2" data-width="1920" data-height="1080">
      <div class="year">2022</div>
      <div id="stage">
        <div id="win">
          <div id="bar"><span></span><span></span><span></span><b>Club Penguin Rewritten</b></div>
          <div id="view">
            <div class="hill" style="left:-200px; top:330px; width:900px; height:520px"></div>
            <div class="hill" style="left:420px; top:300px; width:1100px; height:560px"></div>
            """ + pengs + "\n" + "\n".join(flakes) + """
            <div id="off"></div>
          </div>
        </div>
        """ + tape_html + """
      </div>
    </div>
    <script>
      window.__timelines = window.__timelines || {};
      const tl = gsap.timeline({ paused: true });
      // Penguins waddle: a few finite rocks and a slow drift, all a function of time.
      [["#w0", 40], ["#w1", -30], ["#w2", 24], ["#w3", -18]].forEach(([id, dx], i) => {
        tl.fromTo(id, { x: 0 }, { x: dx, duration: 2.2, ease: "none" }, 0);
        tl.fromTo(id + " svg", { rotation: -5 }, { rotation: 5, duration: 0.3, ease: "sine.inOut", repeat: 10, yoyo: true, transformOrigin: "50% 90%" }, i * 0.08);
      });
      document.querySelectorAll(".flake").forEach((f, i) => {
        tl.fromTo(f, { y: 0 }, { y: 80 + (i % 5) * 14, duration: 2.2, ease: "none" }, 0);
      });
      function shake(t) {
        [[12, -7], [-9, 5], [6, -3], [-3, 2], [0, 0]].forEach((xy, i) => tl.set("#stage", { x: xy[0], y: xy[1] }, t + i * 0.033));
      }
""" + "".join(tape_js) + """
      // The fan site goes dark: a hard cut with a two-frame flicker.
      tl.set("#off", { opacity: 1 }, 1.15);
      tl.set("#off", { opacity: 0.35 }, 1.217);
      tl.set("#off", { opacity: 1 }, 1.283);
      tl.to("#bar", { color: "#4d6672", duration: 0.4, ease: "power2.out" }, 1.15);
      window.__timelines["clip2022"] = tl;
    </script>
  </body>
</html>
"""
    open("clip-2022.html", "w", encoding="utf-8").write(html)


# ---------------------------------------------------------------- Now
def build_now(mode="intro"):
    """intro: huddle bursts into chat windows. revive: starts on intro's last frame, swaps the text to Revitalizing..."""
    friends = [
        ("#3b7dd8", "#2b5ea6", "beanie", 820, 700, (330, 300), -3),
        ("#8a63d2", "#6b48b0", "frog", 960, 690, (960, 215), 1),
        ("#f29bb8", "#d27795", "wizard", 1100, 700, (1590, 300), 3),
        ("#f2c64a", "#d3a530", "cowboy", 885, 775, (420, 830), 2),
        ("#3fb4c9", "#2b8fa2", "none", 1045, 775, (1500, 830), -2),
    ]
    CW, CH, PTOP, PW = 280, 350, 70, 190
    PH = PW * 270 / 200
    cards, js = [], []
    for i, (b, d, h, x, y, to, tilt) in enumerate(friends):
        # Card centre sits on the penguin's centre; y is the feet line.
        left = x - CW / 2
        top = y - PTOP - PH + 10
        cx, cy = left + CW / 2, top + CH / 2
        cards.append(f"""<div class="fr" id="fr{i}" style="left:{left:.0f}px; top:{top:.0f}px">
          <div class="frame" id="fm{i}"><div class="cbar"><i></i><i></i><i></i></div><div class="bubble"><i></i><i></i><i></i></div></div>
          {penguin(b, d, h)}
        </div>""")
        if mode == "revive":
            js.append(f"""
      tl.set("#fm{i}", {{ opacity: 1, scale: 1 }}, 0);
      tl.set("#fr{i}", {{ x: {to[0] - cx:.0f}, y: {to[1] - cy:.0f}, rotation: {tilt}, scale: 0.92 }}, 0);""")
        else:
            js.append(f"""
      tl.fromTo("#fm{i}", {{ opacity: 0, scale: 0.86 }}, {{ opacity: 1, scale: 1, duration: 0.3, ease: "back.out(1.6)" }}, {0.5 + i * 0.05:.2f});
      tl.fromTo("#fr{i}", {{ x: 0, y: 0, rotation: 0, scale: 1 }}, {{ x: {to[0] - cx:.0f}, y: {to[1] - cy:.0f}, rotation: {tilt}, scale: 0.92, duration: 1.4, ease: "power3.out" }}, {0.5 + i * 0.04:.2f});""")
    html = HEAD + """
      #patch {
        position: absolute;
        left: 560px;
        top: 640px;
        width: 800px;
        height: 260px;
        border-radius: 50%;
        background: radial-gradient(ellipse at center, rgba(234, 246, 251, 0.9) 0%, rgba(214, 238, 248, 0.5) 45%, rgba(214, 238, 248, 0) 72%);
      }
      .fr { position: absolute; width: """ + str(CW) + """px; height: """ + str(CH) + """px; }
      .fr svg { position: absolute; left: """ + str((CW - PW) // 2) + """px; top: """ + str(PTOP) + """px; width: """ + str(PW) + """px; }
      .frame {
        position: absolute;
        inset: 0;
        border-radius: 24px;
        background: #0e2430;
        box-shadow: 0 0 0 2px rgba(127, 211, 230, 0.35), 0 24px 50px rgba(0, 0, 0, 0.5);
      }
      .cbar { display: flex; gap: 8px; padding: 16px 18px; }
      .cbar i { width: 11px; height: 11px; border-radius: 50%; background: #2f4a58; }
      .bubble {
        position: absolute;
        right: 18px;
        top: 14px;
        display: flex;
        gap: 6px;
        padding: 9px 12px;
        border-radius: 14px;
        background: #e6f3f9;
      }
      .bubble i { width: 9px; height: 9px; border-radius: 50%; background: #7a93a0; }
      #line {
        position: absolute;
        left: 0;
        right: 0;
        top: 470px;
        text-align: center;
        color: #f5f9fc;
        font: 900 64px/1.15 "Inter", sans-serif;
        z-index: 20;
      }
      /* Same face and size as #line, centred on the same spot */
      #rev { position: absolute; left: 0; right: 0; top: 507px; text-align: center; color: #f5f9fc; font: 900 64px/1.15 "Inter", sans-serif; z-index: 20; }
    </style>
  </head>
  <body>
    <div id="root" data-composition-id="__ID__" data-start="0" data-duration="__DUR__" data-width="1920" data-height="1080">
      <div class="year">Now</div>
      <div id="patch"></div>
      """ + "\n      ".join(cards) + """
      <div id="line"><div id="l1">Group chats everywhere.</div><div id="l2">Nowhere to be together.</div></div>
      __REV__
    </div>
    <script>
      window.__timelines = window.__timelines || {};
      const tl = gsap.timeline({ paused: true });
""" + "".join(js) + """
__ANIM__
      window.__timelines["__ID__"] = tl;
    </script>
  </body>
</html>
"""
    if mode == "revive":
        # Dots type in one at a time on a 1 s loop, then all three stay.
        dots = []
        for k, t in enumerate([0.65 + 0.25 * n for n in range(9)]):
            shown = (k % 4) + 1 if k < 8 else 3
            for d in range(3):
                dots.append(f'tl.set("#d{d}", {{ opacity: {1 if d < shown and shown < 4 else 0} }}, {t:.2f});')
        anim = """      tl.set("#patch", { opacity: 0.15 }, 0);
      tl.set(".bubble i", { opacity: 0.35 }, 0);
      tl.set(".rev-dot", { opacity: 0 }, 0);
      tl.fromTo("#line", { opacity: 1, filter: "blur(0px)" }, { opacity: 0, filter: "blur(10px)", duration: 0.25, ease: "power2.in" }, 0.1);
      tl.fromTo("#rev-word", { opacity: 0, filter: "blur(10px)" }, { opacity: 1, filter: "blur(0px)", duration: 0.3, ease: "power4.out" }, 0.3);
      """ + "\n      ".join(dots)
        rev = '<div id="rev"><span id="rev-word">Revitalizing</span><span class="rev-dot" id="d0">.</span><span class="rev-dot" id="d1">.</span><span class="rev-dot" id="d2">.</span></div>'
        html = html.replace("__ID__", "clipnowrevive").replace("__DUR__", "3.0").replace("__REV__", rev).replace("__ANIM__", anim)
        open("clip-now-revive.html", "w", encoding="utf-8").write(html)
    else:
        anim = """      tl.to("#patch", { opacity: 0.15, duration: 1.2, ease: "power2.inOut" }, 1.0);
      // Typing dots pulse a fixed number of times.
      tl.fromTo(".bubble i", { opacity: 0.35 }, { opacity: 1, duration: 0.25, stagger: 0.08, repeat: 7, yoyo: true, ease: "sine.inOut" }, 0.8);
      tl.fromTo("#l1", { opacity: 0, filter: "blur(10px)" }, { opacity: 1, filter: "blur(0px)", duration: 0.3, ease: "power4.out" }, 2.1);
      tl.fromTo("#l2", { opacity: 0, filter: "blur(10px)" }, { opacity: 1, filter: "blur(0px)", duration: 0.3, ease: "power4.out" }, 2.35);"""
        html = html.replace("__ID__", "clipnow").replace("__DUR__", "3.4").replace("__REV__", "").replace("__ANIM__", anim)
        open("clip-now.html", "w", encoding="utf-8").write(html)


build_2022()
build_now()
build_now("revive")
print("wrote clip-2022.html, clip-now.html, clip-now-revive.html")
