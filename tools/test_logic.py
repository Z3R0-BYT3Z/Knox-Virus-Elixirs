#!/usr/bin/env python3
"""Run Lua 5.1 syntax checks and mocked gameplay regression tests (pip install lupa).
This does not execute Project Zomboid or validate native timed-action networking.
"""
from pathlib import Path
from lupa.lua51 import LuaRuntime
ROOT = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
compile_lua = lua.eval('function(s) local f,e=loadstring(s); return f,e end')
files = list((ROOT / 'src').rglob('*.lua'))
for path in files:
    fn, error = compile_lua(path.read_text())
    if fn is None:
        raise RuntimeError(f'{path}: {error}')
print(f'Lua 5.1 syntax: {len(files)} files passed')
shared = ROOT / 'src/common/media/lua/shared'
client = ROOT / 'src/common/media/lua/client'
server = ROOT / 'src/common/media/lua/server'
lua.globals().TEST_LUA_PATH = ';'.join(str(d / '?.lua') for d in [shared, client, server])
lua.execute((ROOT / 'tests/gameplay.lua').read_text())
print(f'Gameplay regression cases: {lua.globals().TEST_PASSED} passed')
