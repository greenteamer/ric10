# GEMINI.md - Project Context

## Project Overview

This project is a Visual Studio Code extension that provides a compiler for a subset of the ReScript language, targeting the "ic10" assembly language used in the game Stationeers.

The core compiler logic (lexer, parser, code generator) is written in **ReScript**, located in the `src/compiler/` directory. A **TypeScript** wrapper in `src/extension.ts` integrates this compiler into VSCode, providing a command (`rescript-ic10.compile`) to compile the currently open ReScript file.

The ReScript code is configured to generate CommonJS modules with a `.res.js` suffix, and `gentype` is used to create TypeScript definition files (`.gen.ts`) for type-safe interaction between the TypeScript and ReScript parts of the extension.

## Building and Running

**1. Install Dependencies:**
```bash
npm install
```

**2. Build the Project:**
The build process is two-fold:

*   **Compile ReScript to JavaScript:**
    ```bash
    npm run res:build
    ```
*   **Compile the TypeScript wrapper:**
    ```bash
    npm run compile
    ```

**3. Run the Extension:**
This is a VSCode extension. To run it:
1.  Open the project root directory in Visual Studio Code.
2.  Press `F5` to open a new Extension Development Host window.
3.  In the new window, create or open a ReScript file (e.g., `testing/test.res`).
4.  Open the command palette (`Cmd+Shift+P` or `Ctrl+Shift+P`) and run the command "Compile ReScript to IC10".
5.  The compiled ic10 assembly code will appear in a new editor tab.

## Development Conventions

*   **Core Logic:** All compiler logic resides in ReScript files (`.res`) within `src/compiler/`.
*   **VSCode Integration:** The TypeScript file `src/extension.ts` handles all interactions with the VSCode API.
*   **Type Generation:** ReScript types are exposed to TypeScript via `gentype`. The configuration can be found in `rescript.json`.
*   **Testing:** The `testing/test.res` file provides a sample input for manual testing of the compiler.
