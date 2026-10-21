const OpenAPIParser = require("./src/openapi/codegen/openapi/OpenAPIParser.res.js");
const Codegen = require("./src/codegen/openapi/Codegen.res.js");
const fs = require("fs");

const doc = JSON.parse(
  fs.readFileSync("./src/codegen/openapi/openapi.json", "utf8"),
);
const result = OpenAPIParser.parseDocument(doc);

if (result._tag === "Ok") {
  const code = Codegen.generateModule(result._0);
  fs.writeFileSync("./src/codegen/openapi/Generated.res", code);
  console.log("Generated " + result._0.length + " types to Generated.res");
} else {
  console.error("Error:", result._0);
}
