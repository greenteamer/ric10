// init.res - Project initialization logic

// Node.js bindings
@scope("process") @val external argv: array<string> = "argv"
@scope("process") @val external cwd: unit => string = "cwd"

type mkdirOptions = {"recursive": bool}

@module("fs")
external mkdirSync: (string, mkdirOptions) => unit = "mkdirSync"

@module("fs")
external writeFileSync: (string, string, string) => unit = "writeFileSync"

@module("fs")
external existsSync: string => bool = "existsSync"

// Use @variadic for path.join which takes varargs
@module("path") @variadic
external join: array<string> => string = "join"

// Validate project name (npm package name rules)
let validateProjectName = (name: string): bool => {
  // Check for empty name
  if String.length(name) == 0 {
    Console.error("Error: Project name cannot be empty")
    false
  } else if String.startsWith(name, ".") || String.startsWith(name, "_") {
    Console.error("Error: Project name cannot start with '.' or '_'")
    false
  } else if String.includes(name, " ") {
    Console.error("Error: Project name cannot contain spaces. Use hyphens instead.")
    false
  } else if String.toUpperCase(name) == name {
    Console.error("Error: Project name should be lowercase")
    false
  } else {
    true
  }
}

// Create project structure and files
let createProject = (projectName: string) => {
  let projectPath = join([cwd(), projectName])

  // Check if directory already exists
  if existsSync(projectPath) {
    Console.error("Error: Directory '" ++ projectName ++ "' already exists!")
    %raw("process.exit(1)")
  }

  // Create directory structure
  Console.log("Creating project: " ++ projectName ++ "...")

  mkdirSync(projectPath, {"recursive": true})
  mkdirSync(join([projectPath, "src"]), {"recursive": true})

  // Write template files
  Console.log("  Creating src/IC10.res...")
  writeFileSync(
    join([projectPath, "src", "IC10.res"]),
    TemplateFiles.ic10Bindings,
    "utf8"
  )

  Console.log("  Creating src/Example.res...")
  writeFileSync(
    join([projectPath, "src", "Example.res"]),
    TemplateFiles.exampleCode,
    "utf8"
  )

  Console.log("  Creating rescript.json...")
  writeFileSync(
    join([projectPath, "rescript.json"]),
    TemplateFiles.rescriptConfig(projectName),
    "utf8"
  )

  Console.log("  Creating package.json...")
  writeFileSync(
    join([projectPath, "package.json"]),
    TemplateFiles.packageJson(projectName),
    "utf8"
  )

  Console.log("  Creating README.md...")
  writeFileSync(
    join([projectPath, "README.md"]),
    TemplateFiles.readme(projectName),
    "utf8"
  )

  Console.log("  Creating .gitignore...")
  writeFileSync(
    join([projectPath, ".gitignore"]),
    TemplateFiles.gitignore,
    "utf8"
  )

  // Success message
  Console.log("")
  Console.log("✓ Project created successfully!")
  Console.log("")
  Console.log("Next steps:")
  Console.log("  1. cd " ++ projectName)
  Console.log("  2. npm install")
  Console.log("  3. npm run dev          (watch mode)")
  Console.log("  4. ric10 src/Example.res")
  Console.log("")
  Console.log("Happy coding! 🚀")
}

// Main entry point
switch argv[3] {
| Some(projectName) =>
    if validateProjectName(projectName) {
      createProject(projectName)
    }
| None => {
    Console.error("Error: Project name is required")
    Console.log("")
    Console.log("Usage: ric10 init <project-name>")
    Console.log("Example: ric10 init my-ic10-project")
    %raw("process.exit(1)")
  }
}
