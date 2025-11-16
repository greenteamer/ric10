import * as vscode from "vscode";
import * as Compiler from "./compiler/Compiler.gen";
/**
 * Activate the extension. This function is called when the extension is activated.
 */
export function activate(context: vscode.ExtensionContext) {
  console.log("ReScript to IC10 Compiler extension is now active!");

  // Register the compile command
  const compileCommand = vscode.commands.registerCommand(
    "rescript-ic10.compile",
    async () => {
      await compileReScriptToIC10();
    }
  );

  context.subscriptions.push(compileCommand);
}

/**
 * Compile ReScript code to IC10 assembly
 */
async function compileReScriptToIC10() {
  const editor = vscode.window.activeTextEditor;

  if (!editor) {
    vscode.window.showErrorMessage(
      "No active editor found. Please open a ReScript file."
    );
    return;
  }

  const document = editor.document;
  const sourceCode = document.getText();

  // Use the ReScript compiler with IC10 backend by default
  const compileResult = Compiler.compile(sourceCode, {
    includeComments: false,
    debugAST: false,
    backend: "IC10",
  });

  if (compileResult.TAG === "Ok") {
    const content = compileResult._0;
    const doc = await vscode.workspace.openTextDocument({
      content,
      language: "ic10",
    });
    await vscode.window.showTextDocument(doc, vscode.ViewColumn.Beside);
  } else if (compileResult.TAG === "Error") {
    vscode.window.showErrorMessage(compileResult._0);
    return;
  }
}

/**
 * Deactivate the extension. This function is called when the extension is deactivated.
 */
export function deactivate() {
  // Clean up resources if needed
}
