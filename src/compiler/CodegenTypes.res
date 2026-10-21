// Compiler options shared by the API and the CLI.

type compilerOptions = {
  debug?: bool, // print IR before/after optimization to the console
  maxLines?: int, // warn when the program is longer (IC10 chips run 128 lines)
  aliases?: bool, // emit `alias name dX` for named devices (shows on the IC housing screws)
}

let ic10MaxLines = 128
let ic10MaxLineLength = 90
