// let emitInstruction = (instr: IR.instr): string => {
//   switch instr {
//   | IR.Def(name, operand) =>
//     switch operand {
//     | IR.DefNum(n) => "define " ++ name ++ Int.toString(n) ++ "\n"
//     | IR.DefHash(h) => "define " ++ name ++ " " ++ h ++ "\n"
//     }
//   | IR.Move(r, value) => "move " ++ (arg1) ++ ", " ++ string_of_int(arg2) ++ "\n"
//   | IR.InstrC => "C\n"
//   }
// }
//
// let emitBlock = (node: IR.block): string => {
//   let rec loop = instructions => {
//     switch instructions {
//     | list{instr, ...rest} => emitInstruction(instr)
//     }
//   }
//
//   let result = loop(ir)
// }
//
// let emit = (ir: IR.t): string => {
//   let rec loop = ir => {
//     switch ir {
//     | list{node, ...rest} => loop(rest) ++ emitBlock(node)
//     }
//   }
//
//   let result = loop(ir)
// }

