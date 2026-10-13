import glob, os, subprocess, sys, zipfile

src, project = sys.argv[1], sys.argv[2]
bt = sorted(glob.glob(r'C:\development\android-sdk\build-tools\*'))[-1]
props = dict(l.strip().split('=', 1) for l in open(os.path.join(project, 'android', 'key.properties')) if '=' in l)

tmp, aligned = src + '.tmp', src + '.aligned'
with zipfile.ZipFile(src) as zin, zipfile.ZipFile(tmp, 'w') as zout:
    for info in zin.infolist():
        n = info.filename
        if n.startswith('lib/') and not n.startswith('lib/arm64-v8a/'):
            continue
        if n.startswith('META-INF/') and n.rsplit('.', 1)[-1] in ('SF', 'RSA', 'MF'):
            continue
        zout.writestr(info, zin.read(n))

subprocess.run([os.path.join(bt, 'zipalign.exe'), '-P', '16', '-f', '4', tmp, aligned], check=True)
env = dict(os.environ, KS_PASS=props['storePassword'], KEY_PASS=props['keyPassword'])
subprocess.run([os.path.join(bt, 'apksigner.bat'), 'sign', '--ks', props['storeFile'], '--ks-key-alias', props['keyAlias'],
                '--ks-pass', 'env:KS_PASS', '--key-pass', 'env:KEY_PASS', '--out', src, aligned], check=True, env=env)
os.remove(tmp); os.remove(aligned)
for f in glob.glob(src + '.idsig'): os.remove(f)
print('ok', src)
