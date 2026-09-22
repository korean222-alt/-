"""Offline Lua 5.4 compatibility harness. NOT a Luau compiler or Roblox engine.
Translates the project's simple compound assignments only; tests production module bodies.
"""
from pathlib import Path
import ctypes,ctypes.util,re,json,sys
root=Path(__file__).resolve().parents[1]
lua=ctypes.CDLL(ctypes.util.find_library('lua5.4'))
state_t=ctypes.c_void_p
lua.luaL_newstate.restype=state_t
lua.luaL_openlibs.argtypes=[state_t]
lua.luaL_loadbufferx.argtypes=[state_t,ctypes.c_char_p,ctypes.c_size_t,ctypes.c_char_p,ctypes.c_char_p]
lua.lua_pcallk.argtypes=[state_t,ctypes.c_int,ctypes.c_int,ctypes.c_int,ctypes.c_longlong,ctypes.c_void_p]
lua.lua_tolstring.argtypes=[state_t,ctypes.c_int,ctypes.c_void_p];lua.lua_tolstring.restype=ctypes.c_char_p
lua.lua_settop.argtypes=[state_t,ctypes.c_int];lua.lua_close.argtypes=[state_t]
def translate(src):
 return re.sub(r'([A-Za-z_][\w.]*(?:\[[^\]\n]+\])?)\s*([+*/-])=',lambda m:f'{m[1]} = {m[1]} {m[2]}',src)
def run(src,name,execute=True):
 L=lua.luaL_newstate();lua.luaL_openlibs(L);b=src.encode()
 try:
  code=lua.luaL_loadbufferx(L,b,len(b),name.encode(),b't')
  if not code and execute:code=lua.lua_pcallk(L,0,-1,0,0,None)
  if code:raise RuntimeError(lua.lua_tolstring(L,-1,None).decode())
 finally:lua.lua_close(L)
modules={}
for p in sorted((root/'game').rglob('*.lua')):
 src=translate(p.read_text());run(src,str(p.relative_to(root)),False);modules[p.stem]=src
print(f'PASS: {len(modules)} source files parsed by Lua 5.4 after compound-assignment translation')
def literal(s):
 marker='===='
 while ']'+marker+']' in s:marker+='='
 return '['+marker+'['+s+']'+marker+']'
module_loader='SOURCES={\n'+',\n'.join('[ '+literal(k)+' ]='+literal(v) for k,v in modules.items())+'}\n'
harness=(root/'tests/behavior.lua').read_text()
run(module_loader+harness,'behavior')
