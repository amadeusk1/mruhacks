"""Every movable part must export at rest: no rotation, and at its manifest pivot.
  python3 art/blender/check_parts.py   -> lists offenders, exit 1 if any"""
import json, struct, glob, os, sys
M = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "Models")
bad = n = 0
for man in glob.glob(os.path.join(M, "*", "manifest.json")):
    for a in json.load(open(man)):
        parts = a.get("parts") or {}
        if not parts:
            continue
        f = open(os.path.join(M, a["file"]), "rb").read()
        j = json.loads(f[20:20 + struct.unpack("<I", f[12:16])[0]])
        nodes = {nd["name"]: nd for nd in j["nodes"]}
        for pname, p in parts.items():
            nd = nodes.get(pname)
            if nd is None:
                continue
            n += 1
            x, y, z = p["pivot"]
            t = nd.get("translation", [0, 0, 0])
            want = [x, z, -y]  # Blender Z-up -> glTF Y-up
            rot = nd.get("rotation", [0, 0, 0, 1])
            if any(abs(t[i] - want[i]) > 1e-3 for i in range(3)) or abs(abs(rot[3]) - 1) > 1e-4:
                bad += 1
                print(f"NOT AT REST {a['id']} {pname} t={[round(v,3) for v in t]} want={[round(v,3) for v in want]} rot={rot}")
print(f"PARTS checked={n} not_at_rest={bad}")
sys.exit(1 if bad else 0)
