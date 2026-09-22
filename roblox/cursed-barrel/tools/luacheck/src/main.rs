fn main() {
    let mut bad = 0;
    for path in std::env::args().skip(1) {
        let src = std::fs::read_to_string(&path).unwrap();
        match full_moon::parse(&src) {
            Ok(_) => println!("OK   {}", path),
            Err(errors) => {
                bad += 1;
                println!("FAIL {}", path);
                for e in errors {
                    println!("     {}", e);
                }
            }
        }
    }
    if bad > 0 {
        std::process::exit(1);
    }
}
