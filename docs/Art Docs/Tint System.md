# Tint System

How colour works in the asset pack: one mesh per item, and the engine sets the colours. Hub: [Art Pipeline](../Art%20Pipeline.md).

## The rule

Any region that may be recoloured uses a material named:

```
tint_<role>__<default>
```

- `<role>` is the key the game uses, for example `body`, `roof`, `wall`, `trim`, `door`, `cloth_primary`, `cloth_secondary`, `upholstery`, `team`, `awning_a` or `hull`.
- `<default>` is the colour it ships with: a palette name (`tint_door__teal`) or hex without `#` (`tint_roof__F07E66`).
- Everything else, such as wood grain, stone, snow, glow, glass and `insert_*` graphics, is a fixed material and isn't meant to be recoloured.
- No model is exported once per colour. The 5 arcade cabinet colours are one cabinet; the coral/teal team flag is one flag.

## Baked shade (why recolouring still looks hand-made)

A roof is made of many tiles in slightly different shades. If each shade were its own tint, recolouring the roof would mean setting three colours that then had to match. Instead:

1. All shades of a family collapse into **one** tint material. Its colour is the family's brightest shade.
2. Each tile's relative brightness is baked as a **greyscale vertex colour** named `shade`, exported as glTF `COLOR_0`. 1.0 means unchanged; 0.85 means 15 % darker.
3. glTF multiplies `COLOR_0` by `baseColorFactor`. Set the roof to blue and you get blue tiles that still vary subtly.

Families are merged automatically at build time (`common.apply_tint_families`):

| Source | Becomes |
| --- | --- |
| palette `roof`, `roof_b`, `roof_c` | `tint_roof` |
| palette `plaster`, `plaster_shade` | `tint_wall` |
| tint roles `<role>`, `<role>_b`, `<role>_c` of the **same hue** | `tint_<role>` |
| tint roles of **different** hue (`awning_a` coral and `awning_b` cream stripes) | stay separate slots |

The shade is greyscale on purpose. A per-channel ratio would drag the original coral hue into a blue roof.

## In the manifest

Each asset in `Models/<kit>/manifest.json` lists:
- `tints`: `{role: "#default"}` for every tint slot on the asset.
- `color_variants`: suggested colours from the concept sheets. Some kits write a flat list of hex strings and others `{role: [hex, ...]}` or `{name: hex}`; read all three.

## Applying tints in an engine

The animation checklist names **Godot** as the review engine, so Godot comes first. Other engines are included for reference.

**three.js (GLTFLoader).** COLOR_0 turns `vertexColors` on automatically. Clone materials per instance so recolouring one house doesn't recolour all of them:

```js
function applyTints(root, colors) {           // colors: { roof: '#4a7bd0', wall: '#f3e2c5' }
  root.traverse(o => {
    if (!o.isMesh) return;
    o.material = Array.isArray(o.material) ? o.material.map(m => m.clone()) : o.material.clone();
    for (const m of [].concat(o.material)) {
      if (!m.name.startsWith('tint_')) continue;
      const role = m.name.slice(5).split('__')[0];
      if (colors[role]) m.color.set(colors[role]);
    }
  });
}
```

**Godot 4 (the target engine).** Use the shipped helper, `art/godot/tints.gd`: `Tints.prepare(node)` once per instance, then `Tints.apply(node, {"roof": Color(...)})`. `prepare` duplicates the tint materials per instance and forces **Vertex Color → Use as Albedo** on. In testing, the importer left that flag off on two shaded assets. Details and test results: [Godot Integration](Godot%20Integration.md).

**Unity (glTFast).** glTFast's shaders multiply vertex colour by base colour. Set `baseColorFactor` through a `MaterialPropertyBlock` per renderer, so instances don't share the change.

## Adding a tint in a kit script

```python
from common import tint
b.box(1, 1, 1, mat=tint("upholstery", "coral"))      # recolourable seat fabric
b.box(1, 1, 1, mat=tint("upholstery_b", "red_dark")) # darker same-hue shade: merged into 'upholstery'
```

**Glow regions:** a role named `<role>_glow` (for example `team_glow` on the respawn pad rim) is an emissive tint. `Tints.apply` recolours both its albedo and emission, and it follows `<role>` unless you set `<role>_glow` explicitly.

Pick roles a designer would recognise. Reuse existing role names (`wall`, `roof`, `trim`, `door`, `body`, `cloth_primary`) so a theme can recolour many assets at once.
