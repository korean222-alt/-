// 만들어진 .rbxl 을 다시 읽어 구조 · 태그 · Attribute · 배치를 검사한다.
#[path = "../geom.rs"]
mod geom;

use geom::Frame;
use rbx_dom_weak::{ustr, WeakDom};
use rbx_types::{Ref, Variant};

struct Report {
    pass: usize,
    fail: usize,
}

impl Report {
    fn check(&mut self, ok: bool, label: &str) {
        if ok {
            self.pass += 1;
            println!("  OK   {}", label);
        } else {
            self.fail += 1;
            println!("  FAIL {}", label);
        }
    }
    fn info(&self, label: &str) {
        println!("  ..   {}", label);
    }
}

fn child(dom: &WeakDom, parent: Ref, name: &str) -> Option<Ref> {
    dom.get_by_ref(parent)?
        .children()
        .iter()
        .copied()
        .find(|r| dom.get_by_ref(*r).map(|i| i.name == name).unwrap_or(false))
}

fn service(dom: &WeakDom, name: &str) -> Option<Ref> {
    dom.root()
        .children()
        .iter()
        .copied()
        .find(|r| dom.get_by_ref(*r).map(|i| i.name == name).unwrap_or(false))
}

fn class_of(dom: &WeakDom, r: Ref) -> String {
    dom.get_by_ref(r).map(|i| i.class.to_string()).unwrap_or_default()
}

fn prop<'a>(dom: &'a WeakDom, r: Ref, name: &str) -> Option<&'a Variant> {
    dom.get_by_ref(r)?.properties.get(&ustr(name))
}

fn number(dom: &WeakDom, r: Ref, name: &str) -> Option<f32> {
    match prop(dom, r, name) {
        Some(Variant::Float32(v)) => Some(*v),
        Some(Variant::Float64(v)) => Some(*v as f32),
        _ => None,
    }
}

fn frame_of(dom: &WeakDom, r: Ref) -> Option<Frame> {
    match prop(dom, r, "CFrame") {
        Some(Variant::CFrame(cf)) => Some(Frame::from_cframe(cf)),
        _ => None,
    }
}

fn size_of(dom: &WeakDom, r: Ref) -> Option<[f32; 3]> {
    for key in ["size", "Size"] {
        if let Some(Variant::Vector3(v)) = prop(dom, r, key) {
            return Some([v.x, v.y, v.z]);
        }
    }
    None
}

fn has_tag(dom: &WeakDom, r: Ref, tag: &str) -> bool {
    matches!(prop(dom, r, "Tags"), Some(Variant::Tags(t)) if t.iter().any(|x| x == tag))
}

fn attr_num(dom: &WeakDom, r: Ref, key: &str) -> Option<f32> {
    match prop(dom, r, "Attributes") {
        Some(Variant::Attributes(a)) => match a.get(key) {
            Some(Variant::Float32(v)) => Some(*v),
            Some(Variant::Float64(v)) => Some(*v as f32),
            _ => None,
        },
        _ => None,
    }
}

fn attr_bool(dom: &WeakDom, r: Ref, key: &str) -> Option<bool> {
    match prop(dom, r, "Attributes") {
        Some(Variant::Attributes(a)) => match a.get(key) {
            Some(Variant::Bool(v)) => Some(*v),
            _ => None,
        },
        _ => None,
    }
}

fn attr_text(dom: &WeakDom, r: Ref, key: &str) -> Option<String> {
    match prop(dom, r, "Attributes") {
        Some(Variant::Attributes(a)) => match a.get(key) {
            Some(Variant::BinaryString(b)) => Some(String::from_utf8_lossy(b.as_ref()).to_string()),
            Some(Variant::String(s)) => Some(s.clone()),
            _ => None,
        },
        _ => None,
    }
}

fn attr_present(dom: &WeakDom, r: Ref, key: &str) -> bool {
    match prop(dom, r, "Attributes") {
        Some(Variant::Attributes(a)) => a.get(key).is_some(),
        _ => false,
    }
}

fn descendants(dom: &WeakDom, r: Ref, out: &mut Vec<Ref>) {
    for c in dom.get_by_ref(r).unwrap().children() {
        out.push(*c);
        descendants(dom, *c, out);
    }
}

fn main() {
    let input = std::env::args().nth(1).expect("경로");
    let file = std::io::BufReader::new(std::fs::File::open(&input).unwrap());
    let dom = rbx_binary::from_reader(file).unwrap();
    let mut rep = Report { pass: 0, fail: 0 };

    println!("\n=== 1. 스크립트 / RemoteEvent ===");
    let rs = service(&dom, "ReplicatedStorage").unwrap();
    let cb = child(&dom, rs, "CursedBarrel").unwrap();
    let shared = child(&dom, cb, "Shared").unwrap();
    for name in ["GameConfig", "TableConfig", "Utility"] {
        let r = child(&dom, shared, name);
        let ok = r.map(|r| class_of(&dom, r) == "ModuleScript"
            && matches!(prop(&dom, r, "Source"), Some(Variant::String(s)) if s.len() > 200))
            .unwrap_or(false);
        rep.check(ok, &format!("Shared/{} (ModuleScript, 소스 있음)", name));
    }

    let remotes = child(&dom, cb, "Remotes");
    rep.check(remotes.is_some(), "ReplicatedStorage/CursedBarrel/Remotes 폴더");
    if let Some(remotes) = remotes {
        let select = child(&dom, remotes, "SelectSlot");
        rep.check(
            select.map(|r| class_of(&dom, r) == "RemoteEvent").unwrap_or(false),
            "Remotes/SelectSlot (RemoteEvent)",
        );
    }

    let sss = service(&dom, "ServerScriptService").unwrap();
    let server_root = child(&dom, sss, "CursedBarrel").unwrap();
    rep.check(
        child(&dom, server_root, "Main")
            .map(|r| class_of(&dom, r) == "Script")
            .unwrap_or(false),
        "ServerScriptService/CursedBarrel/Main (Script)",
    );
    let services = child(&dom, server_root, "Services").unwrap();
    for name in [
        "GameTable",
        "TableService",
        "RoundService",
        "SlotBuilder",
        "RankingService",
    ] {
        let ok = child(&dom, services, name)
            .map(|r| class_of(&dom, r) == "ModuleScript"
                && matches!(prop(&dom, r, "Source"), Some(Variant::String(s)) if s.len() > 200))
            .unwrap_or(false);
        rep.check(ok, &format!("Services/{} (ModuleScript, 소스 있음)", name));
    }

    let sp = service(&dom, "StarterPlayer").unwrap();
    let sps = child(&dom, sp, "StarterPlayerScripts").unwrap();
    let controllers = child(&dom, sps, "Controllers").unwrap();
    for name in ["TableController", "LightingController", "KnifeController"] {
        let ok = child(&dom, controllers, name)
            .map(|r| class_of(&dom, r) == "LocalScript"
                && matches!(prop(&dom, r, "Source"), Some(Variant::String(s)) if s.len() > 200))
            .unwrap_or(false);
        rep.check(ok, &format!("Controllers/{} (LocalScript, 소스 있음)", name));
    }

    println!("\n=== 2. 테이블 6개 : 태그 · Attribute · 좌석 · 의자 방향 · 칼 슬롯 · 등불 ===");
    let workspace = service(&dom, "Workspace").unwrap();
    let game_tables = child(&dom, workspace, "GameTables").unwrap();
    let tables: Vec<Ref> = dom
        .get_by_ref(game_tables)
        .unwrap()
        .children()
        .iter()
        .copied()
        .filter(|r| has_tag(&dom, *r, "CursedBarrel_Table"))
        .collect();
    rep.check(tables.len() == 6, &format!("CursedBarrel_Table 태그 테이블 {}개", tables.len()));

    for table in tables {
        let table_name = dom.get_by_ref(table).unwrap().name.clone();
        let table_type = attr_text(&dom, table, "TableType").unwrap_or_default();
        let expected_slots = if table_type == "Duo2" { 10 } else { 16 };
        println!("\n  [{} · {}]", table_name, table_type);

        for key in [
            "TableId", "TableType", "SeatCount", "SeatedCount", "MinPlayers", "State",
            "CountdownEndsAt", "CountdownDuration", "RoundId", "ParticipantCount", "TurnCount",
            "TurnIndex", "CurrentTurnUserId", "CurrentTurnName", "TurnEndsAt",
            "KnifeSlotCount", "SlotsRemaining", "BarrelCycle", "LastPickSlot", "LastPickUserId",
            "LastPickName", "LastPickSafe", "WinnerUserId", "WinnerName", "ResetEndsAt",
        ] {
            if !attr_present(&dom, table, key) {
                rep.check(false, &format!("{} Attribute 누락: {}", table_name, key));
            }
        }
        rep.check(
            attr_num(&dom, table, "KnifeSlotCount") == Some(expected_slots as f32),
            &format!("{} KnifeSlotCount = {}", table_name, expected_slots),
        );

        // 통 중심
        let barrel = child(&dom, table, "Barrel").unwrap();
        let body = child(&dom, barrel, "Body").unwrap();
        let center = frame_of(&dom, body).unwrap().pos;
        let body_size = size_of(&dom, body).unwrap();
        let radius = body_size[1] * 0.5;

        // ---- 의자 방향 ----
        let seats_folder = child(&dom, table, "Seats").unwrap();
        let chairs: Vec<Ref> = dom.get_by_ref(seats_folder).unwrap().children().to_vec();
        let mut facing_ok = true;
        let mut back_ok = true;
        let mut seat_attr_ok = true;
        for chair in &chairs {
            let parts: Vec<Ref> = dom.get_by_ref(*chair).unwrap().children().to_vec();
            let seat = parts.iter().copied().find(|r| class_of(&dom, *r) == "Seat");
            let back = parts
                .iter()
                .copied()
                .find(|r| dom.get_by_ref(*r).unwrap().name == "Back");
            if let Some(seat) = seat {
                let f = frame_of(&dom, seat).unwrap();
                let look = f.look_vector();
                let to_center = [center[0] - f.pos[0], 0.0, center[2] - f.pos[2]];
                if look[0] * to_center[0] + look[2] * to_center[2] <= 0.0 {
                    facing_ok = false;
                }
                for key in ["SeatIndex", "OccupantUserId", "TurnOrder", "Alive"] {
                    if !attr_present(&dom, seat, key) {
                        seat_attr_ok = false;
                    }
                }
                if !has_tag(&dom, seat, "CursedBarrel_Seat") {
                    seat_attr_ok = false;
                }
                // 등받이는 좌석보다 테이블에서 멀어야 한다.
                if let Some(back) = back {
                    let bp = frame_of(&dom, back).unwrap().pos;
                    let seat_dist = ((f.pos[0] - center[0]).powi(2) + (f.pos[2] - center[2]).powi(2)).sqrt();
                    let back_dist = ((bp[0] - center[0]).powi(2) + (bp[2] - center[2]).powi(2)).sqrt();
                    if back_dist <= seat_dist {
                        back_ok = false;
                    }
                }
            }
        }
        rep.check(facing_ok, &format!("{} 의자 {}개가 모두 테이블을 바라봄", table_name, chairs.len()));
        rep.check(back_ok, &format!("{} 등받이가 모두 테이블 바깥쪽", table_name));
        rep.check(seat_attr_ok, &format!("{} 좌석 태그/Attribute(Alive 포함) 유지", table_name));

        // ---- 칼 슬롯 ----
        let slots_folder = child(&dom, table, "KnifeSlots");
        rep.check(slots_folder.is_some(), &format!("{} KnifeSlots 폴더", table_name));
        if let Some(folder) = slots_folder {
            let slots: Vec<Ref> = dom.get_by_ref(folder).unwrap().children().to_vec();
            rep.check(
                slots.len() == expected_slots,
                &format!("{} 칼 슬롯 {}개 (기대 {})", table_name, slots.len(), expected_slots),
            );

            let mut indices: Vec<i32> = Vec::new();
            let mut knives_ok = true;
            let mut attrs_ok = true;
            let mut tag_ok = true;
            let mut radius_ok = true;
            let mut positions: Vec<[f32; 3]> = Vec::new();

            for slot in &slots {
                let index = attr_num(&dom, *slot, "SlotIndex").unwrap_or(-1.0) as i32;
                indices.push(index);
                if attr_bool(&dom, *slot, "Used") != Some(false)
                    || attr_num(&dom, *slot, "UsedByUserId") != Some(0.0)
                {
                    attrs_ok = false;
                }
                if !has_tag(&dom, *slot, "CursedBarrel_Slot") {
                    tag_ok = false;
                }

                let f = frame_of(&dom, *slot).unwrap();
                positions.push(f.pos);
                let dist = ((f.pos[0] - center[0]).powi(2) + (f.pos[2] - center[2]).powi(2)).sqrt();
                if (dist - (radius + 0.06)).abs() > 0.02 {
                    radius_ok = false;
                }
                // 슬롯 정면은 통 안쪽을 향해야 한다.
                let look = f.look_vector();
                let inward = [center[0] - f.pos[0], 0.0, center[2] - f.pos[2]];
                if look[0] * inward[0] + look[2] * inward[2] <= 0.0 {
                    radius_ok = false;
                }

                let knife = child(&dom, *slot, "Knife");
                match knife {
                    Some(knife) => {
                        let blade = child(&dom, knife, "Blade");
                        let handle = child(&dom, knife, "Handle");
                        let hidden = [blade, handle].iter().all(|p| {
                            p.map(|p| number(&dom, p, "Transparency") == Some(1.0)).unwrap_or(false)
                        });
                        if blade.is_none() || handle.is_none() || !hidden {
                            knives_ok = false;
                        }
                    }
                    None => knives_ok = false,
                }
            }

            indices.sort();
            let expected: Vec<i32> = (1..=expected_slots as i32).collect();
            rep.check(indices == expected, &format!("{} SlotIndex 가 1..{} 로 빠짐없이", table_name, expected_slots));
            rep.check(attrs_ok, &format!("{} 모든 슬롯 Used=false / UsedByUserId=0", table_name));
            rep.check(tag_ok, &format!("{} 모든 슬롯에 CursedBarrel_Slot 태그", table_name));
            rep.check(radius_ok, &format!("{} 슬롯이 통 표면에 붙고 안쪽을 향함", table_name));
            rep.check(knives_ok, &format!("{} 모든 슬롯에 숨겨진 칼(Blade+Handle)", table_name));

            // 슬롯끼리 너무 붙어 있지 않은지
            let mut min_gap = f32::MAX;
            for i in 0..positions.len() {
                for j in (i + 1)..positions.len() {
                    let d = ((positions[i][0] - positions[j][0]).powi(2)
                        + (positions[i][1] - positions[j][1]).powi(2)
                        + (positions[i][2] - positions[j][2]).powi(2))
                    .sqrt();
                    min_gap = min_gap.min(d);
                }
            }
            rep.check(min_gap > 0.4, &format!("{} 슬롯 최소 간격 {:.2} 스터드", table_name, min_gap));
        }

        // ---- 등불이 현황판을 가리지 않는지 ----
        let anchor = child(&dom, table, "StatusAnchor").unwrap();
        let anchor_y = frame_of(&dom, anchor).unwrap().pos[1];
        let board_top = anchor_y + 4.4 / 2.0; // BillboardGui 높이 4.4 스터드
        let lantern = child(&dom, table, "Lantern").unwrap();
        let lantern_y = frame_of(&dom, lantern).unwrap().pos[1];
        let lantern_size = size_of(&dom, lantern).unwrap();
        let lantern_bottom = lantern_y - lantern_size[1] / 2.0;
        rep.check(
            lantern_bottom > board_top,
            &format!(
                "{} 등불 밑면 {:.2} > 현황판 위쪽 {:.2} (가림 없음)",
                table_name, lantern_bottom, board_top
            ),
        );

        let rope = child(&dom, table, "LanternRope").unwrap();
        let rope_f = frame_of(&dom, rope).unwrap();
        let rope_size = size_of(&dom, rope).unwrap();
        let rope_bottom = rope_f.pos[1] - rope_size[1] / 2.0;
        rep.check(
            rope_bottom > board_top,
            &format!("{} 등불 줄 밑면 {:.2} > 현황판 위쪽 {:.2}", table_name, rope_bottom, board_top),
        );
        rep.info(&format!(
            "{} 현황판 {:.2}~{:.2} · 등불 {:.2}~{:.2} · 줄 {:.2}~{:.2}",
            table_name,
            anchor_y - 2.2,
            board_top,
            lantern_bottom,
            lantern_y + lantern_size[1] / 2.0,
            rope_bottom,
            rope_f.pos[1] + rope_size[1] / 2.0
        ));
    }

    println!("\n=== 3. 로비 : 스폰 · 아티팩트 전시 · 랭킹판 · 안내판 ===");
    let lobby = child(&dom, workspace, "Lobby").unwrap();
    let floor = child(&dom, lobby, "Floor").unwrap();
    let floor_top = frame_of(&dom, floor).unwrap().pos[1] + size_of(&dom, floor).unwrap()[1] / 2.0;

    // 스폰 발판
    let spawn = child(&dom, lobby, "LobbySpawn").unwrap();
    let spawn_f = frame_of(&dom, spawn).unwrap();
    let spawn_size = size_of(&dom, spawn).unwrap();
    let spawn_bottom = spawn_f.pos[1] - spawn_size[1] / 2.0;
    let spawn_top = spawn_f.pos[1] + spawn_size[1] / 2.0;
    rep.check(
        spawn_bottom > floor_top + 0.02,
        &format!("스폰 발판 밑면 {:.2} > 바닥 윗면 {:.2} (Z-파이팅 해소)", spawn_bottom, floor_top),
    );
    let base = child(&dom, lobby, "SpawnBase").unwrap();
    let base_f = frame_of(&dom, base).unwrap();
    let base_size = size_of(&dom, base).unwrap();
    let base_top = base_f.pos[1] + base_size[1] / 2.0;
    rep.check(
        (spawn_bottom - base_top).abs() > 0.01,
        &format!("스폰 발판 밑면 {:.2} 과 받침 윗면 {:.2} 이 같은 평면이 아님", spawn_bottom, base_top),
    );
    rep.info(&format!(
        "스폰 발판 {:.2}~{:.2} · 받침 {:.2}~{:.2} · 바닥 윗면 {:.2}",
        spawn_bottom, spawn_top, base_f.pos[1] - base_size[1] / 2.0, base_top, floor_top
    ));

    // 간판들이 방을 바라보는지
    let room_center = [0.0f32, 0.0, 0.0];
    let shop = child(&dom, lobby, "ShopDisplay").unwrap();
    for (parent, name) in [(shop, "ShopSign"), (lobby, "HowToPlay")] {
        let sign = child(&dom, parent, name).unwrap();
        let f = frame_of(&dom, sign).unwrap();
        let look = f.look_vector();
        let to_room = [room_center[0] - f.pos[0], 0.0, room_center[2] - f.pos[2]];
        rep.check(
            look[0] * to_room[0] + look[2] * to_room[2] > 0.0,
            &format!("{} 이 방 안쪽을 바라봄", name),
        );
        let gui = dom
            .get_by_ref(sign)
            .unwrap()
            .children()
            .iter()
            .copied()
            .find(|r| class_of(&dom, *r) == "SurfaceGui");
        rep.check(gui.is_some(), &format!("{} 에 SurfaceGui", name));
    }

    // 아티팩트 전시 구역
    let artifact = child(&dom, lobby, "ArtifactDisplay");
    rep.check(artifact.is_some(), "Lobby/ArtifactDisplay 폴더");
    if let Some(artifact) = artifact {
        let kids: Vec<Ref> = dom.get_by_ref(artifact).unwrap().children().to_vec();
        let count_named = |prefix: &str| {
            kids.iter()
                .filter(|r| dom.get_by_ref(**r).unwrap().name.starts_with(prefix))
                .count()
        };
        rep.check(count_named("Pedestal_") == 6, &format!("전시 진열대 {}개", count_named("Pedestal_")));
        rep.check(count_named("PedestalTop_") == 6, "진열대 금색 상판 6개");
        rep.check(count_named("DisplayAnchor_") == 6, "전시물 부착점(DisplayAnchor) 6개");
        rep.check(count_named("Runner_") == 2, "전시 구역 러너 2개");
        rep.check(count_named("ArtifactSign") == 1, "아티팩트 안내판");

        // 통로가 비어 있는지 : 스폰(가로 ±8) 앞 통로 ±11 안에 전시물이 없어야 한다
        let mut clear = true;
        for r in &kids {
            let name = dom.get_by_ref(*r).unwrap().name.clone();
            if !name.starts_with("Pedestal") && !name.starts_with("DisplayAnchor") {
                continue;
            }
            let f = frame_of(&dom, *r).unwrap();
            let s = size_of(&dom, *r).unwrap();
            let half_x = s[1].max(s[2]) / 2.0; // 세운 원통이라 지름이 Y/Z
            if f.pos[0].abs() - half_x < 11.0 {
                clear = false;
            }
        }
        rep.check(clear, "스폰 앞 통로(가로 22스터드)에 전시물이 없음");
    }

    // 랭킹판
    let ranking_area = child(&dom, lobby, "RankingArea");
    rep.check(ranking_area.is_some(), "Lobby/RankingArea 폴더");
    if let Some(area) = ranking_area {
        let board = child(&dom, area, "RankingBoard");
        rep.check(board.is_some(), "RankingBoard 파트");
        if let Some(board) = board {
            rep.check(has_tag(&dom, board, "CursedBarrel_RankingBoard"), "랭킹판 태그(CursedBarrel_RankingBoard)");
            let gui = child(&dom, board, "RankingGui");
            rep.check(gui.is_some(), "RankingGui (SurfaceGui)");
            if let Some(gui) = gui {
                let panel = child(&dom, gui, "Panel").unwrap();
                for name in ["Title", "Subtitle", "Rows", "Footer"] {
                    rep.check(child(&dom, panel, name).is_some(), &format!("랭킹판 {} 라벨/틀", name));
                }
                let rows = child(&dom, panel, "Rows").unwrap();
                let has_layout = dom
                    .get_by_ref(rows)
                    .unwrap()
                    .children()
                    .iter()
                    .any(|r| class_of(&dom, *r) == "UIListLayout");
                rep.check(has_layout, "랭킹판 Rows 안에 UIListLayout");
            }

            // 스폰을 바라보는지
            let f = frame_of(&dom, board).unwrap();
            let look = f.look_vector();
            let to_spawn = [spawn_f.pos[0] - f.pos[0], 0.0, spawn_f.pos[2] - f.pos[2]];
            rep.check(
                look[0] * to_spawn[0] + look[2] * to_spawn[2] > 0.0,
                "랭킹판이 스폰 쪽을 바라봄",
            );
        }
        let names: Vec<String> = dom
            .get_by_ref(area)
            .unwrap()
            .children()
            .iter()
            .map(|r| dom.get_by_ref(*r).unwrap().name.clone())
            .collect();
        rep.info(&format!("RankingArea: {}", names.join(", ")));
    }

    // 스폰 발판 위에 방해물이 없는지 (받침/발판 자신은 제외)
    let mut all: Vec<Ref> = Vec::new();
    descendants(&dom, lobby, &mut all);
    let mut blockers: Vec<String> = Vec::new();
    for r in all {
        if size_of(&dom, r).is_none() || frame_of(&dom, r).is_none() {
            continue;
        }
        let name = dom.get_by_ref(r).unwrap().name.clone();
        if name == "LobbySpawn" || name == "SpawnBase" || name == "Floor" {
            continue;
        }
        let f = frame_of(&dom, r).unwrap();
        let s = size_of(&dom, r).unwrap();
        // 회전까지 반영한 정확한 월드 AABB
        let half = [s[0] / 2.0, s[1] / 2.0, s[2] / 2.0];
        let mut extent = [0.0f32; 3];
        for i in 0..3 {
            extent[i] = f.rot[i][0].abs() * half[0]
                + f.rot[i][1].abs() * half[1]
                + f.rot[i][2].abs() * half[2];
        }
        let overlaps_x = (f.pos[0] - extent[0]) < 8.0 && (f.pos[0] + extent[0]) > -8.0;
        let overlaps_z = (f.pos[2] - extent[2]) < 60.0 && (f.pos[2] + extent[2]) > 44.0;
        let low = (f.pos[1] - extent[1]) < 8.0;
        if overlaps_x && overlaps_z && low {
            blockers.push(name);
        }
    }
    rep.check(
        blockers.is_empty(),
        &format!("스폰 발판 위가 비어 있음 (겹치는 파트: {:?})", blockers),
    );

    println!("\n=== 결과 : 통과 {} · 실패 {} ===", rep.pass, rep.fail);
    if rep.fail > 0 {
        std::process::exit(1);
    }
}
