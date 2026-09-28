// 최소 Luau 실행기: 인자로 받은 .luau 파일을 실행한다. readfile/print 제공.
use mlua::prelude::*;
use std::fs;

fn main() -> LuaResult<()> {
    let args: Vec<String> = std::env::args().collect();
    let lua = Lua::new();
    let readfile = lua.create_function(|_, path: String| {
        fs::read_to_string(&path).map_err(|e| LuaError::RuntimeError(format!("{}: {}", path, e)))
    })?;
    lua.globals().set("readfile", readfile)?;
    let writefile = lua.create_function(|_, (path, data): (String, String)| {
        fs::write(&path, data).map_err(|e| LuaError::RuntimeError(format!("{}: {}", path, e)))
    })?;
    lua.globals().set("writefile", writefile)?;
    let loadsrc = lua.create_function(|lua, (src, name): (String, String)| {
        lua.load(&src).set_name(name).into_function()
    })?;
    lua.globals().set("loadsource", loadsrc)?;
    let src = fs::read_to_string(&args[1]).expect("read script");
    let result = lua.load(&src).set_name(args[1].as_str()).exec();
    if let Err(e) = result {
        eprintln!("LUA ERROR: {}", e);
        std::process::exit(1);
    }
    Ok(())
}
