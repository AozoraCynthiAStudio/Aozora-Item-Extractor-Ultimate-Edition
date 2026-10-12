from pathlib import Path
import zipfile,struct,hashlib,shutil,json
r=Path(__file__).resolve().parents[1];version=(r/'VERSION.txt').read_text().strip();out=r/'package/formal';out.mkdir(parents=True,exist_ok=True)
dll = r/'Data/F4SE/Plugins/AozoraItemExtractor.dll'
if b'PreviewSpike07' in dll.read_bytes():
 raise RuntimeError('Experimental 3D preview detected in runtime DLL. Rebuild with --preview_spike=n before packaging.')
coreName=f'Aozora Item Extractor Ultimate Edition v{version}'
patchName=f'Aozora Item Extractor Ultimate Edition CHS Patch v{version}'
sourceName=f'Aozora Item Extractor Ultimate Edition Source v{version}'
shutil.copytree(r/'mcm/MCM',r/'Data/MCM',dirs_exist_ok=True)
shutil.copyfile(r/'translations/AozoraItemExtractor_en.txt',r/'Data/Interface/Translations/AozoraItemExtractor_en.txt')
tex={'mark-a417.dds','watermark-nav-a418.dds','watermark-left-a418.dds','watermark-right-a418.dds',*[f'peek{i}-a419.dds' for i in range(1,4)],*[f'corner{i}-a419.dds' for i in range(1,5)]}
files=[]
for p in (r/'Data').rglob('*'):
 if not p.is_file() or 'Source' in p.parts:continue
 n=p.relative_to(r/'Data').as_posix()
 if n.startswith('Textures/') and p.name not in tex:continue
 if n.startswith('Interface/Translations/') and p.name!='AozoraItemExtractor_en.txt':continue
 files.append((n,p))
for file in ['README_Installation.txt','README_安装说明.txt','LICENSE.md','THIRD_PARTY_NOTICES.md']:files.append((file,r/file))
for p in (r/'licenses').rglob('*'):
 if p.is_file():files.append((p.relative_to(r).as_posix(),p))
core=out/coreName;core.mkdir(exist_ok=True)
for n,p in files:
 dest=core/n;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,dest)
def writezip(folder,path):
 with zipfile.ZipFile(path,'w',zipfile.ZIP_DEFLATED) as z:
  for p in sorted(folder.rglob('*')):
   if p.is_file():z.write(p,p.relative_to(folder).as_posix())
writezip(core,out/(coreName+'.zip'))
def table(path):return dict(l.split('\t',1) for l in path.read_text(encoding='utf-16').splitlines() if '\t' in l)
en=table(r/'translations/AozoraItemExtractor_en.txt');cn=table(r/'translations/AozoraItemExtractor_cn.txt');assert set(en)<=set(cn)
original=(r/'Data/AozoraItemExtractor.esp').read_bytes();edits=[]
def records(blob):
 result=bytearray();i=0
 while i<len(blob):
  sig=blob[i:i+4];head=bytearray(blob[i:i+24]);size=struct.unpack_from('<I',head,4)[0]
  if sig==b'GRUP':
   body=records(blob[i+24:i+size]);struct.pack_into('<I',head,4,len(body)+24);result+=head+body;i+=size;continue
  body=blob[i+24:i+24+size]
  if sig in [b'ALCH',b'MGEF']:
   new=bytearray();j=0
   while j<len(body):
    tag=body[j:j+4];length=struct.unpack_from('<H',body,j+4)[0];value=body[j+6:j+6+length]
    if tag==b'FULL':
     value=('Aozora 物品提取器' if sig==b'ALCH' else '打开 Aozora 物品提取器').encode('utf-8')+b'\0';edits.append(sig.decode())
    new+=tag+struct.pack('<H',len(value))+value;j+=6+length
   body=bytes(new);struct.pack_into('<I',head,4,len(body))
  result+=head+body;i+=24+size
 return bytes(result)
translated=records(original);assert edits==['MGEF','ALCH'] or edits==['ALCH','MGEF']
patch=out/patchName;patch.mkdir(exist_ok=True)
text=('\r\n'.join(k+'\t'+cn[k] for k in en)+'\r\n').encode('utf-16')
for lang in ['en','cn']:
 p=patch/f'Interface/Translations/AozoraItemExtractor_{lang}.txt';p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(text)
(patch/'AozoraItemExtractor.esp').write_bytes(translated);shutil.copyfile(r/'README_汉化补丁.txt',patch/'README_汉化补丁.txt');writezip(patch,out/(patchName+'.zip'))
with zipfile.ZipFile(out/(sourceName+'.zip'),'w',zipfile.ZIP_DEFLATED) as z:
 for folder in ['src','assets','Data','mcm','translations','tools','docs','licenses','发布物料']:
  for p in sorted((r/folder).rglob('*')):
   if p.is_file() and not (folder == '发布物料' and p.suffix.lower() in {'.mp4','.mov','.mkv','.webm','.avi'}) and not any(v in ['build','.xmake','__pycache__'] for v in p.relative_to(r/folder).parts):z.write(p,p.relative_to(r).as_posix())
 for p in r.iterdir():
  if p.is_file() and (p.suffix in ['.md','.txt'] or p.name in ['.gitignore','.gitattributes']):z.write(p,p.name)
lines=[]
for name in [coreName,patchName,sourceName]:
 p=out/(name+'.zip');lines.append(hashlib.sha256(p.read_bytes()).hexdigest().upper()+'  '+p.name)
(out/'SHA256SUMS.txt').write_text('\n'.join(lines)+'\n',encoding='utf-8')
(out/'MANIFEST.json').write_text(json.dumps({'version':version,'translationKeys':len(en),'coreFiles':[n for n,p in files],'patchEspChanges':edits,'runtimeBaseline':'v1.0.0 plus LT/RT category input update','runtimeChanged':True},ensure_ascii=False,indent=2),encoding='utf-8')
print('\n'.join(lines))
