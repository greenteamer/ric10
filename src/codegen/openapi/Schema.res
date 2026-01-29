// Schema.res - JSON Schema AST types and parser

// Output AST types
type rec schemaType =
  | @as("String") String
  | @as("Number") Number
  | @as("Integer") Integer
  | @as("Boolean") Boolean
  | @as("Null") Null
  | Optional(schemaType)

// Helper: check if schema is null type
let isNullType = (json: JSON.t): bool => {
  switch json {
  | Object(dict) =>
    switch dict->Dict.get("type") {
    | Some(String("null")) => true
    | _ => false
    }
  | _ => false
  }
}

// Helper: parse primitive type from object
let parsePrimitiveType = (dict: Dict.t<JSON.t>): result<schemaType, Errors.errors> => {
  switch dict->Dict.get("type") {
  | Some(String("string")) => Ok(String)
  | Some(String("number")) => Ok(Number)
  | Some(String("integer")) => Ok(Integer)
  | Some(String("boolean")) => Ok(Boolean)
  | Some(String("null")) => Ok(Null)
  | Some(String(unknown)) =>
    Error([Errors.unknownType(~value=unknown, ())])
  | Some(_) =>
    Error([Errors.makeError(~kind=InvalidJson("type must be a string"), ())])
  | None =>
    Error([Errors.missingField(~field="type", ())])
  }
}

// Helper: parse anyOf (nullable pattern)
let parseAnyOf = (items: array<JSON.t>): result<schemaType, Errors.errors> => {
  // Check for nullable pattern: [SomeType, { type: "null" }]
  if Array.length(items) == 2 {
    let hasNull = items->Array.some(isNullType)
    if hasNull {
      // Find the non-null type
      let nonNullItem = items->Array.find(item => !isNullType(item))
      switch nonNullItem {
      | Some(Object(dict)) =>
        switch parsePrimitiveType(dict) {
        | Ok(innerType) => Ok(Optional(innerType))
        | Error(e) => Error(e)
        }
      | Some(_) =>
        Error([Errors.makeError(~kind=InvalidJson("anyOf item must be object"), ())])
      | None =>
        Error([Errors.makeError(~kind=InvalidJson("anyOf with only null types"), ())])
      }
    } else {
      Error([Errors.makeError(~kind=UnsupportedFeature("anyOf without null (union types)"), ())])
    }
  } else {
    Error([Errors.makeError(~kind=UnsupportedFeature("anyOf with more than 2 items"), ())])
  }
}

// Parse JSON Schema to our AST
let parse = (json: JSON.t): result<schemaType, Errors.errors> => {
  switch json {
  | Object(dict) =>
    // Check for anyOf first
    switch dict->Dict.get("anyOf") {
    | Some(Array(items)) => parseAnyOf(items)
    | Some(_) =>
      Error([Errors.makeError(~kind=InvalidJson("anyOf must be an array"), ())])
    | None =>
      // Fall back to simple type
      parsePrimitiveType(dict)
    }
  | _ =>
    Error([Errors.makeError(~kind=InvalidJson("expected object"), ())])
  }
}
