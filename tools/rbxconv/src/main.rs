use std::fs::File;
use std::io::{BufReader, BufWriter};

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let mode = &args[1];
    let input = &args[2];
    let output = &args[3];
    match mode.as_str() {
        "tox" => {
            let f = BufReader::new(File::open(input).unwrap());
            let dom = rbx_binary::from_reader(f).unwrap();
            let root = dom.root();
            let refs: Vec<_> = root.children().to_vec();
            let out = BufWriter::new(File::create(output).unwrap());
            rbx_xml::to_writer_default(out, &dom, &refs).unwrap();
        }
        "tob" => {
            let f = BufReader::new(File::open(input).unwrap());
            let dom = rbx_xml::from_reader_default(f).unwrap();
            let root = dom.root();
            let refs: Vec<_> = root.children().to_vec();
            let out = BufWriter::new(File::create(output).unwrap());
            rbx_binary::to_writer(out, &dom, &refs).unwrap();
        }
        _ => panic!("unknown mode"),
    }
}
