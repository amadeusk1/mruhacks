"""Package the exported clients and generate the page's actual-file manifest."""
import datetime, hashlib, json, os, shutil, subprocess, tarfile, zipfile
from pathlib import Path
root = Path(__file__).resolve().parent.parent
os.chdir(root)
version = os.environ.get('DESKTOP_VERSION', subprocess.check_output(['git','rev-parse','--short','HEAD'],text=True).strip()+'-desktop.1')
out = root/'builds/web/download'
release = out/version
release.mkdir(parents=True,exist_ok=True)
shutil.copy2('deploy/download/index.html',out/'index.html')
readme = '''PENGLOO PARTY — desktop preview

Extract the entire archive. Open Pengloo Party, press Play, then choose
Pengloo Party > Join world. Connects automatically to https://pengloo.party.
Desktop and browser users play on the same server. Internet is required online.
Practice Island is solo play. Keep included data and libraries with the app.

These preview builds do not auto-update. Download a new copy after server updates.
Local settings/saves are not cloud-synced accounts.
Windows: unsigned build; extract the ZIP before running the EXE.
macOS: ad-hoc signed, not Apple-notarized. Move to Applications. If blocked,
review the app in System Settings > Privacy & Security, or use the browser version.
Linux: x86_64; allow PenglooParty.x86_64 to execute (chmod +x), then run it.
Android: install PenglooParty-Android.apk. Allow your browser to install apps if asked.

Game: https://pengloo.party/   Downloads: https://pengloo.party/download/
Godot engine license and notices: https://godotengine.org/license/
Voice extension notices: TWO-VOIP-LICENSE.md
'''
license_text=Path('addons/twovoip/LICENSE.md').read_text()
for platform in ['windows','linux']:
 folder=root/'builds/desktop'/platform
 (folder/'README.txt').write_text(readme)
 (folder/'TWO-VOIP-LICENSE.md').write_text(license_text)
 shutil.copy2('deploy/download/GODOT-LICENSE.txt',folder/'GODOT-LICENSE.txt')
win=release/'PenglooParty-Windows-x86_64.zip'
with zipfile.ZipFile(win,'w',zipfile.ZIP_DEFLATED) as z:
 for p in (root/'builds/desktop/windows').rglob('*'):
  if p.is_file():z.write(p,Path('PenglooParty')/p.relative_to(root/'builds/desktop/windows'))
mac=release/'PenglooParty-macOS-universal.zip'
shutil.copy2('builds/desktop/macos/PenglooParty.zip',mac)
with zipfile.ZipFile(mac,'a',zipfile.ZIP_DEFLATED) as z:
 z.writestr('README.txt',readme);z.writestr('TWO-VOIP-LICENSE.md',license_text)
 z.write('deploy/download/GODOT-LICENSE.txt','GODOT-LICENSE.txt')
 helper=zipfile.ZipInfo('pengloo-cinema');helper.external_attr=0o755<<16  # beside PenglooParty.app (LobbyLink.helper_path)
 z.writestr(helper,Path('builds/desktop/macos/pengloo-cinema').read_bytes(),zipfile.ZIP_DEFLATED)
linux=release/'PenglooParty-Linux-x86_64.tar.gz'
with tarfile.open(linux,'w:gz') as t:t.add('builds/desktop/linux',arcname='PenglooParty')
shutil.copy2('deploy/download/GODOT-LICENSE.txt','builds/desktop/server/GODOT-LICENSE.txt')
server=release/'PenglooParty-Server-Linux-x86_64.tar.gz'
with tarfile.open(server,'w:gz') as t:t.add('builds/desktop/server',arcname='PenglooParty-Server')
rows=[]
entries=[
 (win,'Windows','64-bit Intel / AMD','Exported preview; Windows runtime testing is still pending.','ZIP' if win.suffix=='.zip' else 'TAR.GZ'),
 (mac,'macOS','Apple silicon + Intel','Ad-hoc signed preview; not Apple-notarized.','ZIP'),
 (linux,'Linux','64-bit Intel / AMD','Preview build; graphical Linux testing is still pending.','TAR.GZ')]
apk_src=root/'builds/desktop/android/PenglooParty.apk'
if apk_src.is_file():
 apk=release/'PenglooParty-Android.apk'
 shutil.copy2(apk_src,apk)
 entries.append((apk,'Android','Phones and tablets','Install the APK. Allow your browser to install apps if Android asks.','APK'))
for path,name,arch,note,fmt in entries:
 digest=hashlib.sha256(path.read_bytes()).hexdigest()
 rows.append(dict(name=name,arch=arch,validation=note,url=version+'/'+path.name,bytes=path.stat().st_size,sha256=digest,format=fmt))
srv=dict(url=version+'/'+server.name,bytes=server.stat().st_size,sha256=hashlib.sha256(server.read_bytes()).hexdigest())
(release/'SHA256SUMS.txt').write_text(''.join(x['sha256']+'  '+Path(x['url']).name+'\n' for x in rows+[srv]))
(out/'manifest.json').write_text(json.dumps(dict(version=version,date=datetime.date.today().isoformat(),builds=rows,server=srv,checksums=version+'/SHA256SUMS.txt'),indent=2)+'\n')
print('Packaged',version,[(x['name'],x['bytes']) for x in rows])
