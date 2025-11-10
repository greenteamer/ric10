const fs = require("fs");
const Compiler = require("../out/compiler/Compiler.res.js");

const code = fs.readFileSync("./test_direct_branch.res", "utf8");
const result = Compiler.compile(code);

if (result.TAG === "Ok") {
  console.log("Compiled successfully:");
  console.log(result._0);
} else {
  console.log("Compilation error:");
  console.log(result._0);
}

