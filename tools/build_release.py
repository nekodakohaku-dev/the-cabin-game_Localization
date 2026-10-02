"""Validate and repackage reviewed release payloads; Python standard library only."""
from pathlib import Path
import json,hashlib,zipfile
ROOT=Path(__file__).resolve().parent.parent
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
for language in ('zhTW','zhCN','ja'):
    package=ROOT/'packages'/language
    manifest=json.loads((package/'data/manifest.json').read_text(encoding='utf8'))
    assert manifest['language']==language
    translations=json.loads((package/'data/translations.json').read_text(encoding='utf8'))
    assert len(translations)==manifest['translationCount']
    assert len({(r['namespace'],r['key']) for r in translations})==len(translations)
    files=['data/manifest.json']
    for row in manifest['payloadFiles']:
        relative=Path(row['path'])
        path=(package/relative).resolve()
        assert path.is_relative_to(package.resolve()),'Invalid payload path'
        assert path.suffix.lower() not in ('.dll','.pak','.ucas','.utoc','.locres'),path
        assert sha(path)==row['sha256'],f'Changed payload: {path}; rebuild and verify before publishing'
        files.append(row['path'])
    out=ROOT/'dist';out.mkdir(exist_ok=True)
    name=f'TheCabinGame_{language}_v{manifest["version"]}'
    archive=out/(name+'.zip')
    with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
        for relative in sorted(files):z.write(package/relative,name+'/'+relative)
    archive.with_suffix('.sha256.txt').write_text(sha(archive)+'  '+archive.name+'\n',encoding='ascii')
    print(f'Validated {language}: {len(translations)} entries -> {archive.name}')
