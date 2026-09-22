use rbx_dom_weak::{WeakDom, Instance};
use rbx_dom_weak::types::{Ref, Variant};
use std::fs::File;
use std::io::BufReader;

fn describe(v: &Variant) -> String {
    match v {
        Variant::String(s) => { let t: String = s.chars().take(80).collect(); format!("String({:?}{})", t, if s.chars().count() > 80 { format!("...<{} chars>", s.chars().count()) } else { String::new() }) },
        Variant::Bool(b) => format!("Bool({})", b),
        Variant::Float32(f) => format!("Float32({})", f),
        Variant::Float64(f) => format!("Float64({})", f),
        Variant::Int32(i) => format!("Int32({})", i),
        Variant::Int64(i) => format!("Int64({})", i),
        Variant::Vector3(v) => format!("Vector3({}, {}, {})", v.x, v.y, v.z),
        Variant::Vector2(v) => format!("Vector2({}, {})", v.x, v.y),
        Variant::CFrame(c) => format!("CFrame(pos {}, {}, {} | rot [{} {} {}][{} {} {}][{} {} {}])",
            c.position.x, c.position.y, c.position.z,
            c.orientation.x.x, c.orientation.x.y, c.orientation.x.z,
            c.orientation.y.x, c.orientation.y.y, c.orientation.y.z,
            c.orientation.z.x, c.orientation.z.y, c.orientation.z.z),
        Variant::Color3(c) => format!("Color3({}, {}, {})", c.r, c.g, c.b),
        Variant::Color3uint8(c) => format!("Color3uint8({}, {}, {})", c.r, c.g, c.b),
        Variant::Enum(e) => format!("Enum({})", e.to_u32()),
        Variant::Tags(t) => format!("Tags({:?})", t.iter().collect::<Vec<_>>()),
        Variant::Attributes(a) => {
            let mut parts: Vec<String> = a.iter().map(|(k, val)| format!("{}={}", k, describe(val))).collect();
            parts.sort();
            format!("Attributes({})", parts.join(", "))
        }
        Variant::UDim2(u) => format!("UDim2({},{} , {},{})", u.x.scale, u.x.offset, u.y.scale, u.y.offset),
        Variant::UDim(u) => format!("UDim({},{})", u.scale, u.offset),
        other => format!("{:?}", other),
    }
}

fn walk(dom: &WeakDom, r: Ref, depth: usize, out: &mut String, path: &str) {
    let inst: &Instance = dom.get_by_ref(r).unwrap();
    let here = format!("{}/{}", path, inst.name);
    if inst.class == "Script" || inst.class == "LocalScript" || inst.class == "ModuleScript" {
        if let Some(Variant::String(src)) = inst.properties.get(&rbx_dom_weak::ustr("Source")) {
            let fname = format!("sources/{}.lua", here.trim_start_matches('/').replace('/', "__"));
            std::fs::create_dir_all("sources").ok();
            std::fs::write(&fname, src).ok();
        }
    }
    out.push_str(&format!("{}- [{}] {} ({} children)\n", "  ".repeat(depth), inst.class, inst.name, inst.children().len()));
    let mut props: Vec<(String, String)> = inst.properties.iter().map(|(k, v)| (k.to_string(), describe(v))).collect();
    props.sort();
    for (k, v) in props {
        out.push_str(&format!("{}    .{} = {}\n", "  ".repeat(depth), k, v));
    }
    for c in inst.children() {
        walk(dom, *c, depth + 1, out, &here);
    }
}

fn main() {
    let path = std::env::args().nth(1).expect("path");
    let f = BufReader::new(File::open(&path).unwrap());
    let dom = rbx_binary::from_reader(f).unwrap();
    let mut out = String::new();
    for c in dom.root().children() {
        walk(&dom, *c, 0, &mut out, "");
    }
    println!("{}", out);
}
