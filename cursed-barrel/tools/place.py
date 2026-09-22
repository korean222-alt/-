"""Lossless Roblox binary chunk reader/source patcher (preserves unrelated chunks)."""
from pathlib import Path
import struct,ctypes,ctypes.util,json
u32=lambda b,p=0:struct.unpack_from('<I',b,p)[0]
def string(b,p):
 n=u32(b,p);return b[p+4:p+4+n],p+4+n
def s(v):
 if isinstance(v,str):v=v.encode()
 return struct.pack('<I',len(v))+v
def refs(b,n):
 out=[];last=0
 for i in range(n):
  v=int.from_bytes(bytes(b[i+j*n] for j in range(4)),'big');last+=(v>>1)^-(v&1);out.append(last)
 return out
class Place:
 def __init__(self,path):
  self.raw=Path(path).read_bytes();self.header=self.raw[:32];self.chunks=[];self.classes={};self.nodes={};p=32
  lib=ctypes.CDLL(ctypes.util.find_library('lz4'));lib.LZ4_decompress_safe.argtypes=[ctypes.c_char_p,ctypes.c_void_p,ctypes.c_int,ctypes.c_int]
  while p<len(self.raw):
   tag,cl,ul,res=struct.unpack_from('<4sIII',self.raw,p);raw=self.raw[p:p+16+(cl or ul)];d=raw[16:];p+=len(raw)
   if cl:
    if d[:4]==b'\x28\xb5\x2f\xfd':
     import zstandard;d=zstandard.ZstdDecompressor().decompress(d,max_output_size=ul)
    else:
     buf=ctypes.create_string_buffer(ul);assert lib.LZ4_decompress_safe(d,buf,cl,ul)==ul;d=buf.raw
   self.chunks.append([tag,d,raw])
   if tag==b'INST':
    cid=u32(d);name,q=string(d,4);fmt=d[q];n=u32(d,q+1);rr=refs(d[q+5:q+5+4*n],n);self.classes[cid]={'name':name.decode(),'refs':rr}
    for r in rr:self.nodes[r]={'class':name.decode(),'cid':cid}
  for tag,d,raw in self.chunks:
   if tag==b'PROP':
    cid=u32(d);name,p=string(d,4);typ=d[p];p+=1
    if name in (b'Name',b'Source') and typ==1:
     for r in self.classes[cid]['refs']:
      val,p=string(d,p);self.nodes[r][name.decode()]=val.decode()
   elif tag==b'PRNT':
    n=u32(d,1);ch=refs(d[5:5+4*n],n);pa=refs(d[5+4*n:],n)
    for r,parent in zip(ch,pa):self.nodes[r]['parent']=parent
 def path(self,r):
  n=self.nodes[r];p=n.get('parent',-1)
  return (self.path(p)+'/' if p in self.nodes else '')+n.get('Name',n['class'])
 def extract(self,root):
  manifest=[]
  for r,n in self.nodes.items():
   if 'Source' in n:
    ext={'Script':'.server.lua','LocalScript':'.client.lua','ModuleScript':'.lua'}[n['class']];p=Path(root)/(self.path(r)+ext);p.parent.mkdir(parents=True,exist_ok=True);p.write_text(n['Source']);manifest.append({'ref':r,'path':str(p),'class':n['class']})
  return manifest
 def build(self,root,dest):
  changes={}
  for r,n in self.nodes.items():
   if 'Source' in n:
    ext={'Script':'.server.lua','LocalScript':'.client.lua','ModuleScript':'.lua'}[n['class']];changes[r]=(Path(root)/(self.path(r)+ext)).read_text()
  out=bytearray(self.header)
  for tag,d,raw in self.chunks:
   if tag==b'PROP':
    cid=u32(d);name,p=string(d,4)
    if name==b'Source':
     assert d[p]==1;d=d[:p+1]+b''.join(s(changes[r]) for r in self.classes[cid]['refs']);raw=struct.pack('<4sIII',tag,0,len(d),0)+d
   out+=raw
  Path(dest).write_bytes(out)
if __name__=='__main__':
 import sys
 p=Place(sys.argv[2])
 if sys.argv[1]=='extract':
  manifest=p.extract(sys.argv[3]);Path('tools/manifest.json').write_text(json.dumps(manifest,indent=2));print(json.dumps(manifest,indent=2));print('Instances:',len(p.nodes))
 elif sys.argv[1]=='build':p.build(sys.argv[3],sys.argv[4])
