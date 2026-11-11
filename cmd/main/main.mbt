///|
/// Entry point for the CLI or runnable program in this template.
/// Keep main focused; move logic into the library package.
/// Run with `moon run cmd/main` from the project root.
fn main {
  let data = [0.0, 1.0, 0.0, -1.0, 0.0, 1.0, 0.0, -1.0, 3.0, -2.0, 5.0, 1.0]
  match @mp.matrix_profile(data, 4) {
    Err(e) => println(e.message)
    Ok(p) => {
      println("MoonMatrixProfile / sample offsets are zero-based")
      for hit in @mp.motifs(p, 1).unwrap() {
        println(
          "motif: \{hit.index} <-> \{hit.neighbor}, distance \{hit.distance}",
        )
      }
      for hit in @mp.discords(p, 1) {
        println(
          "discord: \{hit.index}, nearest \{hit.neighbor}, distance \{hit.distance}",
        )
      }
    }
  }
}
