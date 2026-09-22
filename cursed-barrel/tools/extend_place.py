from place import *
def encode_refs(values):
 last=0;ints=[]
 for v in values:
  d=v-last;last=v;ints.append(((d<<1)^(d>>31))&0xffffffff)
 return bytes((v>>shift)&255 for shift in (24,16,8,0) for v in ints)
def build(source,root,dest):
 p=Place(source);original={p.path(r):r for r in p.nodes};extras={};nextref=max(p.nodes)+1
 for path in sorted(Path(root).rglob('*.lua')):
  rel=path.relative_to(root).as_posix();ext=next(x for x in ['.server.lua','.client.lua','.lua'] if rel.endswith(x));name=rel[:-len(ext)]
  if name in original:continue
  parent,_,leaf=name.rpartition('/');assert parent in original,parent
  cls={'.lua':'ModuleScript','.server.lua':'Script','.client.lua':'LocalScript'}[ext];cid=next(k for k,v in p.classes.items() if v['name']==cls)
  extras.setdefault(cid,[]).append((nextref,leaf,path.read_text(),original[parent]));nextref+=1
 out=bytearray(p.header);struct.pack_into('<I',out,20,len(p.nodes)+sum(map(len,extras.values())))
 for tag,d,raw in p.chunks:
  changed=False
  if tag==b'INST':
   cid=u32(d)
   if cid in extras:
    name,q=string(d,4);assert d[q]==0
    rr=p.classes[cid]['refs']+[x[0] for x in extras[cid]];d=d[:q+1]+struct.pack('<I',len(rr))+encode_refs(rr);changed=True
  elif tag==b'PROP':
   cid=u32(d);name,q=string(d,4)
   if name==b'Source':
    ext={'Script':'.server.lua','LocalScript':'.client.lua','ModuleScript':'.lua'}[p.classes[cid]['name']]
    vals=[(Path(root)/(p.path(r)+ext)).read_text() for r in p.classes[cid]['refs']]+[x[2] for x in extras.get(cid,[])]
    d=d[:q+1]+b''.join(s(v) for v in vals);changed=True
   elif cid in extras:
    assert name==b'Name',name;d+=b''.join(s(x[1]) for x in extras[cid]);changed=True
  elif tag==b'PRNT':
   n=u32(d,1);ch=refs(d[5:5+4*n],n);pa=refs(d[5+4*n:],n)
   for group in extras.values():
    for r,_,_,parent in group:ch.append(r);pa.append(parent)
   d=b'\0'+struct.pack('<I',len(ch))+encode_refs(ch)+encode_refs(pa);changed=True
   # Streaming is a Studio-only setting: serialize it into the place.
   cid=next(k for k,v in p.classes.items() if v['name']=='Workspace')
   prop=struct.pack('<I',cid)+s('StreamingEnabled')+b'\x02\x01'
   out+=struct.pack('<4sIII',b'PROP',0,len(prop),0)+prop
  if changed:raw=struct.pack('<4sIII',tag,0,len(d),0)+d
  out+=raw
 Path(dest).write_bytes(out)
 q=Place(dest);assert len(q.nodes)==len(p.nodes)+sum(map(len,extras.values()))
 print('Built',dest,'instances',len(q.nodes),'scripts',sum('Source' in n for n in q.nodes.values()))
if __name__=='__main__':
 import sys;build(*sys.argv[1:])
