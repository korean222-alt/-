mod geom;

use geom::Frame;
use rbx_dom_weak::{ustr, InstanceBuilder, WeakDom};
use rbx_types::{
    Attributes, Color3uint8, Enum as RbxEnum, Font, Ref, Tags, UDim, UDim2, Variant, Vector3,
};
use std::f32::consts::PI;

// ---------- 머티리얼 / 열거형 값 (Phase 2 파일에서 쓰던 값과 같다) ----------
const MAT_SMOOTH_PLASTIC: u32 = 272;
const MAT_NEON: u32 = 288;
const MAT_WOOD: u32 = 512;
const MAT_WOOD_PLANKS: u32 = 528;
const MAT_MARBLE: u32 = 784;
const MAT_METAL: u32 = 1088;

const SHAPE_BLOCK: u32 = 1;
const SHAPE_CYLINDER: u32 = 2;
const SURFACE_SMOOTH: u32 = 0;
const NORMAL_FRONT: u32 = 5;
const SIZING_PIXELS_PER_STUD: u32 = 1;
const SORT_LAYOUT_ORDER: u32 = 2;
const XALIGN_LEFT: u32 = 0;
const XALIGN_RIGHT: u32 = 1;
const XALIGN_CENTER: u32 = 2;

const TAG_TABLE: &str = "CursedBarrel_Table";
const TAG_SLOT: &str = "CursedBarrel_Slot";
const TAG_RANKING: &str = "CursedBarrel_RankingBoard";

// 슬롯 배치 규칙 — SlotBuilder.lua 의 GameConfig.SlotLayout 과 같은 값
const SLOT_MAX_PER_RING: usize = 8;
const SLOT_RING_SPREAD: f32 = 0.155;
const SLOT_SURFACE_GAP: f32 = 0.06;
const SLOT_KNIFE_TILT: f32 = 14.0;

// ---------- 색 ----------
const C_WOOD_DARK: (u8, u8, u8) = (52, 34, 23);
const C_WOOD: (u8, u8, u8) = (94, 62, 40);
const C_GOLD: (u8, u8, u8) = (198, 154, 74);
const C_PANEL: (u8, u8, u8) = (46, 33, 25);
const C_STONE: (u8, u8, u8) = (188, 184, 176);
const C_SLOT: (u8, u8, u8) = (28, 20, 15);
const C_BLADE: (u8, u8, u8) = (206, 210, 214);
const C_HANDLE: (u8, u8, u8) = (64, 42, 28);
const C_INVISIBLE: (u8, u8, u8) = (163, 162, 165);

// =====================================================================
// DOM 헬퍼
// =====================================================================

fn child(dom: &WeakDom, parent: Ref, name: &str) -> Option<Ref> {
    dom.get_by_ref(parent)?
        .children()
        .iter()
        .copied()
        .find(|r| dom.get_by_ref(*r).map(|i| i.name == name).unwrap_or(false))
}

fn service(dom: &WeakDom, name: &str) -> Ref {
    dom.root()
        .children()
        .iter()
        .copied()
        .find(|r| dom.get_by_ref(*r).map(|i| i.name == name).unwrap_or(false))
        .unwrap_or_else(|| panic!("서비스를 찾지 못했습니다: {}", name))
}

fn path(dom: &WeakDom, parts: &[&str]) -> Ref {
    let mut current = service(dom, parts[0]);
    for name in &parts[1..] {
        current = child(dom, current, name)
            .unwrap_or_else(|| panic!("경로를 찾지 못했습니다: {} / {}", parts[0], name));
    }
    current
}

fn set(dom: &mut WeakDom, r: Ref, name: &str, value: Variant) {
    if let Some(inst) = dom.get_by_ref_mut(r) {
        inst.properties.insert(ustr(name), value);
    }
}

fn get_cframe(dom: &WeakDom, r: Ref) -> Frame {
    match dom.get_by_ref(r).and_then(|i| i.properties.get(&ustr("CFrame"))) {
        Some(Variant::CFrame(cf)) => Frame::from_cframe(cf),
        _ => panic!("CFrame 이 없습니다"),
    }
}

fn get_size(dom: &WeakDom, r: Ref) -> [f32; 3] {
    match dom.get_by_ref(r).and_then(|i| i.properties.get(&ustr("size"))) {
        Some(Variant::Vector3(v)) => [v.x, v.y, v.z],
        _ => match dom.get_by_ref(r).and_then(|i| i.properties.get(&ustr("Size"))) {
            Some(Variant::Vector3(v)) => [v.x, v.y, v.z],
            _ => panic!("Size 가 없습니다"),
        },
    }
}

fn set_cframe(dom: &mut WeakDom, r: Ref, frame: &Frame) {
    set(dom, r, "CFrame", Variant::CFrame(frame.to_cframe()));
}

fn set_size(dom: &mut WeakDom, r: Ref, size: [f32; 3]) {
    // 파일에 이미 있는 이름은 "Size" 다. 소문자 "size" 로 넣으면 키가 둘이 되어 무시된다.
    if let Some(inst) = dom.get_by_ref_mut(r) {
        inst.properties.remove(&ustr("size"));
    }
    set(
        dom,
        r,
        "Size",
        Variant::Vector3(Vector3::new(size[0], size[1], size[2])),
    );
}

fn add_tag(dom: &mut WeakDom, r: Ref, tag: &str) {
    let mut tags: Vec<String> = match dom.get_by_ref(r).and_then(|i| i.properties.get(&ustr("Tags"))) {
        Some(Variant::Tags(t)) => t.iter().map(|s| s.to_string()).collect(),
        _ => Vec::new(),
    };
    if !tags.iter().any(|t| t == tag) {
        tags.push(tag.to_string());
    }
    set(dom, r, "Tags", Variant::Tags(Tags::from(tags)));
}

fn attrs_of(dom: &WeakDom, r: Ref) -> Attributes {
    match dom.get_by_ref(r).and_then(|i| i.properties.get(&ustr("Attributes"))) {
        Some(Variant::Attributes(a)) => a.clone(),
        _ => Attributes::new(),
    }
}

fn attr_string(text: &str) -> Variant {
    // Phase 2 파일과 같은 표현을 쓴다. (rbx-dom 은 Attribute 문자열을 BinaryString 으로 읽고 쓴다)
    Variant::BinaryString(text.as_bytes().to_vec().into())
}

fn set_attrs(dom: &mut WeakDom, r: Ref, values: &[(&str, Variant)]) {
    let mut attrs = attrs_of(dom, r);
    for (name, value) in values {
        attrs.insert(name.to_string(), value.clone());
    }
    set(dom, r, "Attributes", Variant::Attributes(attrs));
}

struct PartSpec<'a> {
    name: &'a str,
    size: [f32; 3],
    frame: Frame,
    color: (u8, u8, u8),
    material: u32,
    shape: u32,
    transparency: f32,
    can_collide: bool,
    can_query: bool,
}

impl<'a> PartSpec<'a> {
    fn new(name: &'a str, size: [f32; 3], frame: Frame) -> Self {
        PartSpec {
            name,
            size,
            frame,
            color: C_WOOD,
            material: MAT_SMOOTH_PLASTIC,
            shape: SHAPE_BLOCK,
            transparency: 0.0,
            can_collide: true,
            can_query: true,
        }
    }
    fn color(mut self, c: (u8, u8, u8)) -> Self {
        self.color = c;
        self
    }
    fn material(mut self, m: u32) -> Self {
        self.material = m;
        self
    }
    fn cylinder(mut self) -> Self {
        self.shape = SHAPE_CYLINDER;
        self
    }
    fn transparency(mut self, t: f32) -> Self {
        self.transparency = t;
        self
    }
    fn no_collide(mut self) -> Self {
        self.can_collide = false;
        self
    }
    fn no_query(mut self) -> Self {
        self.can_query = false;
        self
    }
}

fn add_part(dom: &mut WeakDom, parent: Ref, spec: PartSpec) -> Ref {
    let builder = InstanceBuilder::new("Part")
        .with_name(spec.name)
        .with_property("Size", Vector3::new(spec.size[0], spec.size[1], spec.size[2]))
        .with_property("CFrame", spec.frame.to_cframe())
        .with_property(
            "Color",
            Color3uint8::new(spec.color.0, spec.color.1, spec.color.2),
        )
        .with_property("Material", RbxEnum::from_u32(spec.material))
        .with_property("Shape", RbxEnum::from_u32(spec.shape))
        .with_property("Anchored", true)
        .with_property("CanCollide", spec.can_collide)
        .with_property("CanQuery", spec.can_query)
        .with_property("CanTouch", false)
        .with_property("Transparency", spec.transparency)
        .with_property("TopSurface", RbxEnum::from_u32(SURFACE_SMOOTH))
        .with_property("BottomSurface", RbxEnum::from_u32(SURFACE_SMOOTH));
    dom.insert(parent, builder)
}

fn gotham(weight: u16) -> Font {
    let mut font = Font::default();
    font.family = "rbxasset://fonts/families/GothamSSm.json".to_string();
    font.weight = match weight {
        500 => rbx_types::FontWeight::Medium,
        700 => rbx_types::FontWeight::Bold,
        _ => rbx_types::FontWeight::Regular,
    };
    font.style = rbx_types::FontStyle::Normal;
    font.cached_face_id = None;
    font
}

fn udim2(sx: f32, ox: i32, sy: f32, oy: i32) -> UDim2 {
    UDim2::new(UDim::new(sx, ox), UDim::new(sy, oy))
}

#[allow(clippy::too_many_arguments)]
fn add_text_label(
    dom: &mut WeakDom,
    parent: Ref,
    name: &str,
    text: &str,
    size: UDim2,
    position: UDim2,
    color: (u8, u8, u8),
    align: u32,
    weight: u16,
) -> Ref {
    let builder = InstanceBuilder::new("TextLabel")
        .with_name(name)
        .with_property("Text", text.to_string())
        .with_property("Size", size)
        .with_property("Position", position)
        .with_property("BackgroundTransparency", 1.0f32)
        .with_property("TextScaled", true)
        .with_property("TextWrapped", true)
        .with_property("FontFace", gotham(weight))
        .with_property(
            "TextColor3",
            rbx_types::Color3::new(
                color.0 as f32 / 255.0,
                color.1 as f32 / 255.0,
                color.2 as f32 / 255.0,
            ),
        )
        .with_property("TextXAlignment", RbxEnum::from_u32(align));
    dom.insert(parent, builder)
}

// =====================================================================
// 1) 스크립트 넣기
// =====================================================================

fn read_source(relative: &str) -> String {
    let base = std::env::var("PHASE3_SRC").expect("PHASE3_SRC 환경변수가 필요합니다");
    let full = format!("{}/{}", base, relative);
    std::fs::read_to_string(&full).unwrap_or_else(|e| panic!("{} 을 읽지 못했습니다: {}", full, e))
}

fn replace_source(dom: &mut WeakDom, target: Ref, relative: &str) {
    let source = read_source(relative);
    set(dom, target, "Source", Variant::String(source));
}

fn add_script(dom: &mut WeakDom, parent: Ref, class: &str, name: &str, relative: &str) -> Ref {
    if let Some(existing) = child(dom, parent, name) {
        replace_source(dom, existing, relative);
        return existing;
    }
    let source = read_source(relative);
    let builder = InstanceBuilder::new(class)
        .with_name(name)
        .with_property("Source", source);
    dom.insert(parent, builder)
}

fn install_scripts(dom: &mut WeakDom) {
    // ReplicatedStorage > CursedBarrel > Shared
    let shared = path(dom, &["ReplicatedStorage", "CursedBarrel", "Shared"]);
    for (name, file) in [
        ("GameConfig", "Shared/GameConfig.lua"),
        ("TableConfig", "Shared/TableConfig.lua"),
        ("Utility", "Shared/Utility.lua"),
    ] {
        add_script(dom, shared, "ModuleScript", name, file);
    }

    // ReplicatedStorage > CursedBarrel > Remotes > SelectSlot
    let root = path(dom, &["ReplicatedStorage", "CursedBarrel"]);
    let remotes = match child(dom, root, "Remotes") {
        Some(r) => r,
        None => dom.insert(root, InstanceBuilder::new("Folder").with_name("Remotes")),
    };
    if child(dom, remotes, "SelectSlot").is_none() {
        dom.insert(
            remotes,
            InstanceBuilder::new("RemoteEvent").with_name("SelectSlot"),
        );
    }

    // ServerScriptService > CursedBarrel
    let server = path(dom, &["ServerScriptService", "CursedBarrel"]);
    add_script(dom, server, "Script", "Main", "Server/Main.server.lua");

    let services = child(dom, server, "Services").expect("Services 폴더가 없습니다");
    for (name, file) in [
        ("GameTable", "Server/Services/GameTable.lua"),
        ("TableService", "Server/Services/TableService.lua"),
        ("RoundService", "Server/Services/RoundService.lua"),
        ("SlotBuilder", "Server/Services/SlotBuilder.lua"),
        ("RankingService", "Server/Services/RankingService.lua"),
    ] {
        add_script(dom, services, "ModuleScript", name, file);
    }

    // StarterPlayer > StarterPlayerScripts > Controllers
    let controllers = path(
        dom,
        &["StarterPlayer", "StarterPlayerScripts", "Controllers"],
    );
    for (name, file) in [
        ("TableController", "Client/Controllers/TableController.lua"),
        (
            "LightingController",
            "Client/Controllers/LightingController.lua",
        ),
        ("KnifeController", "Client/Controllers/KnifeController.lua"),
    ] {
        add_script(dom, controllers, "LocalScript", name, file);
    }
}

fn main() {
    let input = std::env::args().nth(1).expect("입력 .rbxl 경로");
    let output = std::env::args().nth(2).expect("출력 .rbxl 경로");

    let file = std::io::BufReader::new(std::fs::File::open(&input).unwrap());
    let mut dom = rbx_binary::from_reader(file).unwrap();

    install_scripts(&mut dom);
    let tables = fix_tables(&mut dom);
    build_plaza(&mut dom);

    let out = std::io::BufWriter::new(std::fs::File::create(&output).unwrap());
    let root_children: Vec<Ref> = dom.root().children().to_vec();
    rbx_binary::to_writer(out, &dom, &root_children).unwrap();

    println!("완료: {} (테이블 {}개)", output, tables);
}

// =====================================================================
// 2) 테이블 고치기 : 의자 방향 · 등불 높이 · 칼 슬롯
// =====================================================================

fn fix_tables(dom: &mut WeakDom) -> usize {
    let workspace = service(dom, "Workspace");
    let game_tables = child(dom, workspace, "GameTables").expect("GameTables 폴더가 없습니다");
    let table_refs: Vec<Ref> = dom
        .get_by_ref(game_tables)
        .unwrap()
        .children()
        .iter()
        .copied()
        .collect();

    let mut count = 0;
    for table in table_refs {
        let is_table = matches!(
            dom.get_by_ref(table).and_then(|i| i.properties.get(&ustr("Tags"))),
            Some(Variant::Tags(t)) if t.iter().any(|tag| tag == TAG_TABLE)
        );
        if !is_table {
            continue;
        }
        count += 1;

        let center = table_center(dom, table);
        fix_chairs(dom, table, center);
        raise_lantern(dom, table);
        let slots = build_knife_slots(dom, table);
        write_table_attributes(dom, table, slots);
    }

    count
}

// 통 몸통의 위치를 테이블 중심으로 본다.
fn table_center(dom: &WeakDom, table: Ref) -> [f32; 3] {
    let barrel = child(dom, table, "Barrel").expect("Barrel 이 없습니다");
    let body = child(dom, barrel, "Body").expect("Barrel.Body 가 없습니다");
    get_cframe(dom, body).pos
}

/// 의자가 테이블을 등지고 있으면(좌석 LookVector 가 중심 반대쪽) 의자 전체를 180도 돌린다.
fn fix_chairs(dom: &mut WeakDom, table: Ref, center: [f32; 3]) {
    let seats_folder = match child(dom, table, "Seats") {
        Some(r) => r,
        None => return,
    };

    let chairs: Vec<Ref> = dom
        .get_by_ref(seats_folder)
        .unwrap()
        .children()
        .iter()
        .copied()
        .collect();

    for chair in chairs {
        // 의자 안의 Seat 파트를 찾는다.
        let parts: Vec<Ref> = dom
            .get_by_ref(chair)
            .unwrap()
            .children()
            .iter()
            .copied()
            .collect();

        let seat = parts.iter().copied().find(|r| {
            dom.get_by_ref(*r)
                .map(|i| i.class.as_str() == "Seat")
                .unwrap_or(false)
        });
        let seat = match seat {
            Some(s) => s,
            None => continue,
        };

        let seat_frame = get_cframe(dom, seat);
        let look = seat_frame.look_vector();
        let to_center = [
            center[0] - seat_frame.pos[0],
            0.0,
            center[2] - seat_frame.pos[2],
        ];
        let dot = look[0] * to_center[0] + look[2] * to_center[2];

        if dot >= 0.0 {
            continue; // 이미 테이블을 바라보고 있다
        }

        // 좌석 위치를 지나는 수직축 기준으로 의자 전체를 180도 돌린다.
        let (px, pz) = (seat_frame.pos[0], seat_frame.pos[2]);
        for part in parts {
            if dom
                .get_by_ref(part)
                .map(|i| i.properties.contains_key(&ustr("CFrame")))
                .unwrap_or(false)
            {
                let frame = get_cframe(dom, part).spin_180_about(px, pz);
                set_cframe(dom, part, &frame);
            }
        }
    }
}

/// 등불이 현황판(StatusAnchor) 글자를 가리지 않도록 천장 쪽으로 올린다.
fn raise_lantern(dom: &mut WeakDom, table: Ref) {
    let lantern_y = 15.8f32;

    for name in ["Lantern", "Flame"] {
        if let Some(part) = child(dom, table, name) {
            let mut frame = get_cframe(dom, part);
            frame.pos[1] = lantern_y;
            set_cframe(dom, part, &frame);
        }
    }

    // 줄은 등불 위에서 천장 장식(y≈17.4)까지만 짧게 남긴다.
    if let Some(rope) = child(dom, table, "LanternRope") {
        let size = get_size(dom, rope);
        let top = 17.4f32;
        let bottom = lantern_y + 0.9;
        let height = (top - bottom).max(0.4);
        let mut frame = get_cframe(dom, rope);
        frame.pos[1] = bottom + height / 2.0;
        set_cframe(dom, rope, &frame);
        set_size(dom, rope, [size[0], height, size[2]]);
    }
}

// =====================================================================
// 3) 칼 슬롯 만들기 (SlotBuilder.lua 와 같은 계산)
// =====================================================================

struct SlotSpot {
    index: usize,
    frame: Frame,
}

fn slot_layout(count: usize, center: [f32; 3], radius: f32, height: f32) -> Vec<SlotSpot> {
    let rings = ((count as f32) / (SLOT_MAX_PER_RING as f32)).ceil().max(1.0) as usize;
    let base = count / rings;
    let extra = count % rings;

    let spread = height * SLOT_RING_SPREAD;
    let mut result = Vec::new();
    let mut index = 0usize;

    for ring in 1..=rings {
        let ring_count = base + if ring <= extra { 1 } else { 0 };
        if ring_count == 0 {
            continue;
        }

        let offset_y = if rings == 1 {
            0.0
        } else {
            let t = (ring - 1) as f32 / (rings - 1) as f32;
            spread - t * spread * 2.0
        };
        let angle_offset = (ring - 1) as f32 * PI / ring_count as f32;

        for slot in 1..=ring_count {
            index += 1;
            let angle = (slot - 1) as f32 / ring_count as f32 * PI * 2.0 + angle_offset;
            let outward = [angle.sin(), 0.0, angle.cos()];
            let position = [
                center[0] + outward[0] * (radius + SLOT_SURFACE_GAP),
                center[1] + offset_y,
                center[2] + outward[2] * (radius + SLOT_SURFACE_GAP),
            ];
            result.push(SlotSpot {
                index,
                frame: Frame::yaw(position, angle),
            });
        }
    }

    result
}

fn table_type(dom: &WeakDom, table: Ref) -> String {
    let attrs = attrs_of(dom, table);
    match attrs.get("TableType") {
        Some(Variant::BinaryString(bytes)) => String::from_utf8_lossy(bytes.as_ref()).to_string(),
        Some(Variant::String(text)) => text.clone(),
        _ => "Standard4".to_string(),
    }
}

fn build_knife_slots(dom: &mut WeakDom, table: Ref) -> usize {
    let count = if table_type(dom, table) == "Duo2" { 10 } else { 16 };

    let barrel = child(dom, table, "Barrel").expect("Barrel 이 없습니다");
    let body = child(dom, barrel, "Body").expect("Barrel.Body 가 없습니다");
    let body_size = get_size(dom, body);
    let center = get_cframe(dom, body).pos;
    let radius = body_size[1] * 0.5; // 원통 파트는 지름이 Y
    let height = body_size[0]; // 길이는 X

    // 이미 있으면 지우고 다시 만든다.
    if let Some(existing) = child(dom, table, "KnifeSlots") {
        dom.destroy(existing);
    }

    let folder = dom.insert(table, InstanceBuilder::new("Folder").with_name("KnifeSlots"));
    let tilt = Frame::rot_x(-SLOT_KNIFE_TILT.to_radians());

    for spot in slot_layout(count, center, radius, height) {
        let name = format!("Slot_{:02}", spot.index);
        let marker = add_part(
            dom,
            folder,
            PartSpec::new(&name, [0.34, 0.52, 0.12], spot.frame)
                .color(C_SLOT)
                .material(MAT_SMOOTH_PLASTIC)
                .no_collide(),
        );
        set_attrs(
            dom,
            marker,
            &[
                ("SlotIndex", Variant::Float32(spot.index as f32)),
                ("Used", Variant::Bool(false)),
                ("UsedByUserId", Variant::Float32(0.0)),
            ],
        );
        add_tag(dom, marker, TAG_SLOT);

        // 칼은 평소에 투명하다. 누가 그 자리를 고르면 서버가 보이게 만든다.
        let knife = dom.insert(marker, InstanceBuilder::new("Model").with_name("Knife"));
        let knife_base = spot.frame.rotated(tilt);

        add_part(
            dom,
            knife,
            PartSpec::new("Blade", [0.12, 0.5, 1.6], knife_base.translated([0.0, 0.0, 0.2]))
                .color(C_BLADE)
                .material(MAT_METAL)
                .transparency(1.0)
                .no_collide()
                .no_query(),
        );
        add_part(
            dom,
            knife,
            PartSpec::new("Handle", [0.26, 0.34, 0.7], knife_base.translated([0.0, 0.0, 1.35]))
                .color(C_HANDLE)
                .material(MAT_WOOD)
                .transparency(1.0)
                .no_collide()
                .no_query(),
        );
    }

    count
}

fn write_table_attributes(dom: &mut WeakDom, table: Ref, slots: usize) {
    set_attrs(
        dom,
        table,
        &[
            ("KnifeSlotCount", Variant::Float32(slots as f32)),
            ("SlotsRemaining", Variant::Float32(slots as f32)),
            ("BarrelCycle", Variant::Float32(0.0)),
            ("LastPickSlot", Variant::Float32(0.0)),
            ("LastPickUserId", Variant::Float32(0.0)),
            ("LastPickName", attr_string("")),
            ("LastPickSafe", Variant::Bool(true)),
            ("WinnerUserId", Variant::Float32(0.0)),
            ("WinnerName", attr_string("")),
            ("ResetEndsAt", Variant::Float32(0.0)),
        ],
    );

    // 좌석에도 Phase 3 표시(Alive)를 미리 만들어 둔다.
    if let Some(seats_folder) = child(dom, table, "Seats") {
        let chairs: Vec<Ref> = dom
            .get_by_ref(seats_folder)
            .unwrap()
            .children()
            .to_vec();
        for chair in chairs {
            let parts: Vec<Ref> = dom.get_by_ref(chair).unwrap().children().to_vec();
            for part in parts {
                let is_seat = dom
                    .get_by_ref(part)
                    .map(|i| i.class.as_str() == "Seat")
                    .unwrap_or(false);
                if is_seat {
                    set_attrs(dom, part, &[("Alive", Variant::Bool(false))]);
                }
            }
        }
    }
}

// =====================================================================
// 4) 스폰 광장 : 스폰 발판 · 아티팩트 전시대 · 랭킹판 · 안내판
// =====================================================================

const FLOOR_TOP: f32 = 1.0;
const SPAWN_Z: f32 = 52.0;

fn build_plaza(dom: &mut WeakDom) {
    let lobby = path(dom, &["Workspace", "Lobby"]);

    fix_spawn(dom, lobby);
    fix_shop_sign(dom, lobby);
    build_artifact_display(dom, lobby);
    build_boards(dom, lobby);
}

/// 스폰 발판이 바닥과 같은 높이라서 겹쳐 보이던 문제를 고친다.
/// 발판을 바닥 위로 띄우고, 아래에 받침을 깔아 경계를 분명하게 만든다.
fn fix_spawn(dom: &mut WeakDom, lobby: Ref) {
    let spawn = child(dom, lobby, "LobbySpawn").expect("LobbySpawn 이 없습니다");

    // 받침 (바닥 위 0.12) — 발판보다 넓어서 테두리처럼 보인다.
    add_part(
        dom,
        lobby,
        PartSpec::new(
            "SpawnBase",
            [22.0, 0.12, 22.0],
            Frame::new([0.0, FLOOR_TOP + 0.06, SPAWN_Z]),
        )
        .color(C_WOOD_DARK)
        .material(MAT_WOOD_PLANKS)
        .no_collide(),
    );

    // 금색 발판 — 받침보다 0.03 더 띄워서 어떤 면도 바닥과 같은 높이에 놓이지 않는다.
    let mut frame = get_cframe(dom, spawn);
    frame.pos = [0.0, FLOOR_TOP + 0.25, SPAWN_Z];
    set_cframe(dom, spawn, &frame);
    set_size(dom, spawn, [16.0, 0.2, 16.0]);
    set(dom, spawn, "Transparency", Variant::Float32(0.35));
    set(dom, spawn, "Material", Variant::Enum(RbxEnum::from_u32(MAT_NEON)));
    set(
        dom,
        spawn,
        "Color",
        Variant::Color3uint8(Color3uint8::new(C_GOLD.0, C_GOLD.1, C_GOLD.2)),
    );
}

/// 가게 간판이 벽을 향해 돌아 있어 글자가 보이지 않았다. 방을 향해 돌린다.
fn fix_shop_sign(dom: &mut WeakDom, lobby: Ref) {
    let shop = match child(dom, lobby, "ShopDisplay") {
        Some(r) => r,
        None => return,
    };
    let sign = match child(dom, shop, "ShopSign") {
        Some(r) => r,
        None => return,
    };

    // 북쪽 벽에 걸린 간판이므로 방(+Z)을 바라봐야 한다.
    let frame = get_cframe(dom, sign);
    let fixed = Frame::look_at(frame.pos, [0.0, 0.0, 1.0]);
    set_cframe(dom, sign, &fixed);
}

/// 스폰 좌우에 아티팩트(유물) 전시 자리를 만든다.
/// 가운데 통로(가로 22스터드)는 비워 둬서 지나다니는 데 방해가 없다.
fn build_artifact_display(dom: &mut WeakDom, lobby: Ref) {
    if let Some(existing) = child(dom, lobby, "ArtifactDisplay") {
        dom.destroy(existing);
    }
    let folder = dom.insert(
        lobby,
        InstanceBuilder::new("Folder").with_name("ArtifactDisplay"),
    );

    for (side_name, x) in [("West", -17.0f32), ("East", 17.0f32)] {
        // 전시 구역 표시용 얇은 러너 (바닥 위 0.12)
        add_part(
            dom,
            folder,
            PartSpec::new(
                &format!("Runner_{}", side_name),
                [12.0, 0.12, 36.0],
                Frame::new([x, FLOOR_TOP + 0.06, 40.0]),
            )
            .color(C_PANEL)
            .material(MAT_WOOD_PLANKS)
            .no_collide(),
        );

        for (index, z) in [28.0f32, 40.0, 52.0].iter().enumerate() {
            let number = index + 1;
            let vertical = [[0.0, -1.0, 0.0], [1.0, 0.0, 0.0], [0.0, 0.0, 1.0]]; // 원통을 세운다

            add_part(
                dom,
                folder,
                PartSpec::new(
                    &format!("Pedestal_{}_{:02}", side_name, number),
                    [2.6, 5.0, 5.0],
                    Frame::with_rot([x, FLOOR_TOP + 1.42, *z], vertical),
                )
                .color(C_STONE)
                .material(MAT_MARBLE)
                .cylinder(),
            );

            add_part(
                dom,
                folder,
                PartSpec::new(
                    &format!("PedestalTop_{}_{:02}", side_name, number),
                    [0.4, 5.6, 5.6],
                    Frame::with_rot([x, FLOOR_TOP + 2.92, *z], vertical),
                )
                .color(C_GOLD)
                .material(MAT_METAL)
                .cylinder(),
            );

            // 나중에 아티팩트 모델이나 안내판을 붙일 자리. (투명 · 충돌 없음)
            add_part(
                dom,
                folder,
                PartSpec::new(
                    &format!("DisplayAnchor_{}_{:02}", side_name, number),
                    [1.0, 1.0, 1.0],
                    Frame::new([x, FLOOR_TOP + 3.9, *z]),
                )
                .color(C_INVISIBLE)
                .transparency(1.0)
                .no_collide()
                .no_query(),
            );
        }
    }

    // 남쪽 벽 안내판 : 이 구역이 무엇인지 알려준다.
    let sign = add_part(
        dom,
        folder,
        PartSpec::new(
            "ArtifactSign",
            [34.0, 8.0, 1.0],
            Frame::look_at([0.0, 9.0, 69.2], [0.0, 0.0, -1.0]),
        )
        .color(C_PANEL)
        .material(MAT_SMOOTH_PLASTIC)
        .no_collide(),
    );
    add_surface_text(
        dom,
        sign,
        "ArtifactLabel",
        "유물 전시 구역 (준비 중)\n좌우 진열대에 아티팩트가 놓입니다",
        C_GOLD,
    );
}

/// 파트 앞면에 글자판(SurfaceGui + TextLabel)을 붙인다. Phase 2 간판들과 같은 구성.
fn add_surface_text(dom: &mut WeakDom, part: Ref, name: &str, text: &str, color: (u8, u8, u8)) -> Ref {
    let gui = dom.insert(
        part,
        InstanceBuilder::new("SurfaceGui")
            .with_name(name)
            .with_property("Face", RbxEnum::from_u32(NORMAL_FRONT))
            .with_property("LightInfluence", 0.0f32)
            .with_property("PixelsPerStud", 50.0f32)
            .with_property("SizingMode", RbxEnum::from_u32(SIZING_PIXELS_PER_STUD)),
    );

    let label = add_text_label(
        dom,
        gui,
        "Text",
        text,
        udim2(1.0, 0, 1.0, 0),
        udim2(0.0, 0, 0.0, 0),
        color,
        XALIGN_CENTER,
        700,
    );

    dom.insert(
        label,
        InstanceBuilder::new("UIPadding")
            .with_name("Padding")
            .with_property("PaddingTop", UDim::new(0.08, 0))
            .with_property("PaddingBottom", UDim::new(0.08, 0))
            .with_property("PaddingLeft", UDim::new(0.05, 0))
            .with_property("PaddingRight", UDim::new(0.05, 0)),
    );

    gui
}

/// 큰 판 하나를 세운다. (뒤판 · 다리 · 금색 장식)
fn board_stand(
    dom: &mut WeakDom,
    parent: Ref,
    prefix: &str,
    frame: Frame,
    size: [f32; 3],
    bottom_y: f32,
) {
    let right = [frame.rot[0][0], frame.rot[1][0], frame.rot[2][0]];
    let look = frame.look_vector();

    // 뒤판 : 판보다 조금 크게, 살짝 뒤로.
    add_part(
        dom,
        parent,
        PartSpec::new(
            &format!("{}_Backing", prefix),
            [size[0] + 1.6, size[1] + 1.6, 0.6],
            Frame::with_rot(
                [
                    frame.pos[0] - look[0] * 0.75,
                    frame.pos[1],
                    frame.pos[2] - look[2] * 0.75,
                ],
                frame.rot,
            ),
        )
        .color(C_WOOD_DARK)
        .material(MAT_WOOD)
        .no_collide(),
    );

    // 금색 상단 장식
    add_part(
        dom,
        parent,
        PartSpec::new(
            &format!("{}_Trim", prefix),
            [size[0] + 1.6, 0.7, 1.4],
            Frame::with_rot(
                [frame.pos[0], frame.pos[1] + size[1] / 2.0 + 1.1, frame.pos[2]],
                frame.rot,
            ),
        )
        .color(C_GOLD)
        .material(MAT_METAL)
        .no_collide(),
    );

    // 다리 두 개
    let leg_height = (frame.pos[1] - size[1] / 2.0 - bottom_y).max(0.6);
    let leg_y = bottom_y + leg_height / 2.0;
    for (index, offset) in [-(size[0] / 2.0 - 2.0), size[0] / 2.0 - 2.0].iter().enumerate() {
        add_part(
            dom,
            parent,
            PartSpec::new(
                &format!("{}_Leg_{:02}", prefix, index + 1),
                [1.3, leg_height, 1.3],
                Frame::with_rot(
                    [
                        frame.pos[0] + right[0] * offset,
                        leg_y,
                        frame.pos[2] + right[2] * offset,
                    ],
                    frame.rot,
                ),
            )
            .color(C_WOOD_DARK)
            .material(MAT_WOOD),
        );
    }
}

/// 랭킹판의 글자 구조. 순위 줄은 서버(RankingService)가 채운다.
fn add_ranking_gui(dom: &mut WeakDom, board: Ref) {
    let gui = dom.insert(
        board,
        InstanceBuilder::new("SurfaceGui")
            .with_name("RankingGui")
            .with_property("Face", RbxEnum::from_u32(NORMAL_FRONT))
            .with_property("LightInfluence", 0.0f32)
            .with_property("PixelsPerStud", 50.0f32)
            .with_property("SizingMode", RbxEnum::from_u32(SIZING_PIXELS_PER_STUD)),
    );

    let panel = dom.insert(
        gui,
        InstanceBuilder::new("Frame")
            .with_name("Panel")
            .with_property("Size", udim2(1.0, 0, 1.0, 0))
            .with_property(
                "BackgroundColor3",
                rbx_types::Color3::new(30.0 / 255.0, 21.0 / 255.0, 16.0 / 255.0),
            )
            .with_property("BackgroundTransparency", 0.05f32)
            .with_property("BorderSizePixel", 0i32),
    );

    dom.insert(
        panel,
        InstanceBuilder::new("UIPadding")
            .with_name("Padding")
            .with_property("PaddingTop", UDim::new(0.05, 0))
            .with_property("PaddingBottom", UDim::new(0.05, 0))
            .with_property("PaddingLeft", UDim::new(0.05, 0))
            .with_property("PaddingRight", UDim::new(0.05, 0)),
    );

    add_text_label(
        dom,
        panel,
        "Title",
        "명예의 전당",
        udim2(1.0, 0, 0.13, 0),
        udim2(0.0, 0, 0.0, 0),
        C_GOLD,
        XALIGN_CENTER,
        700,
    );

    add_text_label(
        dom,
        panel,
        "Subtitle",
        "저주받은 통 · 승리 순위",
        udim2(1.0, 0, 0.07, 0),
        udim2(0.0, 0, 0.135, 0),
        (150, 138, 118),
        XALIGN_CENTER,
        500,
    );

    let rows = dom.insert(
        panel,
        InstanceBuilder::new("Frame")
            .with_name("Rows")
            .with_property("Size", udim2(1.0, 0, 0.72, 0))
            .with_property("Position", udim2(0.0, 0, 0.22, 0))
            .with_property("BackgroundTransparency", 1.0f32)
            .with_property("BorderSizePixel", 0i32),
    );

    dom.insert(
        rows,
        InstanceBuilder::new("UIListLayout")
            .with_name("Layout")
            .with_property("Padding", UDim::new(0.012, 0))
            .with_property("SortOrder", RbxEnum::from_u32(SORT_LAYOUT_ORDER)),
    );

    // 서버가 켜지기 전에도 빈 판처럼 보이지 않도록 한 줄을 미리 넣어 둔다.
    let placeholder = dom.insert(
        rows,
        InstanceBuilder::new("Frame")
            .with_name("Row_1")
            .with_property("Size", udim2(1.0, 0, 0.092, 0))
            .with_property(
                "BackgroundColor3",
                rbx_types::Color3::new(36.0 / 255.0, 25.0 / 255.0, 19.0 / 255.0),
            )
            .with_property("BackgroundTransparency", 0.15f32)
            .with_property("BorderSizePixel", 0i32)
            .with_property("LayoutOrder", 1i32),
    );
    dom.insert(
        placeholder,
        InstanceBuilder::new("UICorner")
            .with_name("UICorner")
            .with_property("CornerRadius", UDim::new(0.25, 0)),
    );
    add_text_label(
        dom,
        placeholder,
        "PlayerName",
        "아직 승자가 없습니다",
        udim2(0.72, 0, 0.8, 0),
        udim2(0.0, 0, 0.1, 0),
        (238, 223, 196),
        XALIGN_LEFT,
        700,
    );
    add_text_label(
        dom,
        placeholder,
        "Score",
        "0승 / 0판",
        udim2(0.26, 0, 0.8, 0),
        udim2(0.74, 0, 0.1, 0),
        C_GOLD,
        XALIGN_RIGHT,
        700,
    );

    add_text_label(
        dom,
        panel,
        "Footer",
        "서버가 켜지면 순위가 채워집니다",
        udim2(1.0, 0, 0.055, 0),
        udim2(0.0, 0, 0.945, 0),
        (150, 138, 118),
        XALIGN_CENTER,
        500,
    );
}

/// 스폰에서 보이는 두 개의 큰 판 : 왼쪽 랭킹판, 오른쪽 게임 설명판.
fn build_boards(dom: &mut WeakDom, lobby: Ref) {
    let board_size = [26.0f32, 13.0, 1.0];
    let board_y = 9.8f32;
    let board_z = 40.0f32;
    let spawn_point = [0.0f32, board_y, SPAWN_Z];

    // ---------- 랭킹판 (서쪽) ----------
    if let Some(existing) = child(dom, lobby, "RankingArea") {
        dom.destroy(existing);
    }
    let ranking_folder = dom.insert(
        lobby,
        InstanceBuilder::new("Folder").with_name("RankingArea"),
    );

    let ranking_pos = [-30.0f32, board_y, board_z];
    let ranking_look = [
        spawn_point[0] - ranking_pos[0],
        0.0,
        spawn_point[2] - ranking_pos[2],
    ];
    let ranking_frame = Frame::look_at(ranking_pos, ranking_look);

    let board = add_part(
        dom,
        ranking_folder,
        PartSpec::new("RankingBoard", board_size, ranking_frame)
            .color(C_PANEL)
            .material(MAT_SMOOTH_PLASTIC)
            .no_collide(),
    );
    add_tag(dom, board, TAG_RANKING);
    add_ranking_gui(dom, board);
    board_stand(
        dom,
        ranking_folder,
        "Ranking",
        ranking_frame,
        board_size,
        FLOOR_TOP,
    );

    // ---------- 게임 설명판 (동쪽) ----------
    let how_to = child(dom, lobby, "HowToPlay").expect("HowToPlay 가 없습니다");
    let how_pos = [30.0f32, board_y, board_z];
    let how_look = [spawn_point[0] - how_pos[0], 0.0, spawn_point[2] - how_pos[2]];
    let how_frame = Frame::look_at(how_pos, how_look);

    set_cframe(dom, how_to, &how_frame);
    set_size(dom, how_to, board_size);
    set(
        dom,
        how_to,
        "Color",
        Variant::Color3uint8(Color3uint8::new(C_PANEL.0, C_PANEL.1, C_PANEL.2)),
    );

    // 안내 문구를 Phase 3 규칙으로 바꾼다.
    if let Some(gui) = child(dom, how_to, "Instructions") {
        if let Some(label) = child(dom, gui, "Text") {
            set(
                dom,
                label,
                "Text",
                Variant::String(
                    "저주받은 통 · PHASE 3\n\
                     의자에 앉으면 5초 뒤 시작\n\
                     내 차례에 통에 칼을 꽂는다 (E 또는 화면 버튼)\n\
                     터지는 자리를 고른 사람은 탈락\n\
                     마지막까지 살아남으면 승리"
                        .to_string(),
                ),
            );
        }
    }

    if let Some(existing) = child(dom, lobby, "HowToPlayStand") {
        dom.destroy(existing);
    }
    let how_folder = dom.insert(
        lobby,
        InstanceBuilder::new("Folder").with_name("HowToPlayStand"),
    );
    board_stand(dom, how_folder, "HowToPlay", how_frame, board_size, FLOOR_TOP);
}
