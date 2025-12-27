#!/usr/bin/env node

// CLI router for ric10 commands

const command = process.argv[2];

if (command === 'init') {
  // Project initialization
  require('../dist/init.js');
} else if (command === '--help' || command === '-h') {
  showHelp();
} else if (command === '--version' || command === '-v') {
  showVersion();
} else {
  // Default: compile command (backward compatible)
  require('../dist/compile.js');
}

function showHelp() {
  console.log(`
ric10 - ReScript to IC10 compiler

Usage:
  ric10 <file.res> [backend]    Compile ReScript to IC10/WASM
  ric10 init <project-name>     Create new IC10 project
  ric10 --help                  Show this help
  ric10 --version               Show version

Backends:
  ic10 - IC10 assembly (default)
  wasm - WebAssembly text format

Examples:
  ric10 furnace.res
  ric10 furnace.res wasm
  ric10 init my-ic10-project
  `);
}

function showVersion() {
  const pkg = require('../package.json');
  console.log(`ric10 version ${pkg.version}`);
}
