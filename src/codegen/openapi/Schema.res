// Schema.res - JSON Schema AST types and parser

// Field type for object properties
type rec field = {
  name: string,
  type_: schemaType,
  required: bool,
}

// Output AST types
and schemaType =
  | @as("String") String
  | @as("Number") Number
  | @as("Integer") Integer
  | @as("Boolean") Boolean
  | @as("Null") Null
  | Optional(schemaType)
  | Object(array<field>)

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

// Forward declaration for recursive parsing
let rec parseSchema = (json: JSON.t): result<schemaType, Errors.errors> => {
  switch json {
  | Object(dict) => parseObject(dict)
  | _ => Error([Errors.makeError(~kind=InvalidJson("expected object"), ())])
  }
}

// Helper: parse primitive type from object
and parsePrimitiveType = (dict: Dict.t<JSON.t>): result<schemaType, Errors.errors> => {
  switch dict->Dict.get("type") {
  | Some(String("string")) => Ok(String)
  | Some(String("number")) => Ok(Number)
  | Some(String("integer")) => Ok(Integer)
  | Some(String("boolean")) => Ok(Boolean)
  | Some(String("null")) => Ok(Null)
  | Some(String("object")) => parseObjectType(dict)
  | Some(String(unknown)) => Error([Errors.unknownType(~value=unknown, ())])
  | Some(_) => Error([Errors.makeError(~kind=InvalidJson("type must be a string"), ())])
  | None => Error([Errors.missingField(~field="type", ())])
  }
}

// Helper: parse anyOf (nullable pattern)
and parseAnyOf = (items: array<JSON.t>): result<schemaType, Errors.errors> => {
  if Array.length(items) == 2 {
    let hasNull = items->Array.some(isNullType)
    if hasNull {
      let nonNullItem = items->Array.find(item => !isNullType(item))
      switch nonNullItem {
      | Some(Object(dict)) =>
        switch parsePrimitiveType(dict) {
        | Ok(innerType) => Ok(Optional(innerType))
        | Error(e) => Error(e)
        }
      | Some(_) => Error([Errors.makeError(~kind=InvalidJson("anyOf item must be object"), ())])
      | None => Error([Errors.makeError(~kind=InvalidJson("anyOf with only null types"), ())])
      }
    } else {
      Error([Errors.makeError(~kind=UnsupportedFeature("anyOf without null (union types)"), ())])
    }
  } else {
    Error([Errors.makeError(~kind=UnsupportedFeature("anyOf with more than 2 items"), ())])
  }
}

// Helper: parse object type with properties
and parseObjectType = (dict: Dict.t<JSON.t>): result<schemaType, Errors.errors> => {
  // Get required fields array
  let requiredFields = switch dict->Dict.get("required") {
  | Some(Array(arr)) =>
    arr->Array.filterMap(item =>
      switch item {
      | String(s) => Some(s)
      | _ => None
      }
    )
  | _ => []
  }

  // Get properties
  switch dict->Dict.get("properties") {
  | Some(Object(propsDict)) =>
    let entries = propsDict->Dict.toArray
    let results = entries->Array.map(((name, propSchema)) => {
      switch parseSchema(propSchema) {
      | Ok(propType) =>
        Ok({
          name,
          type_: propType,
          required: requiredFields->Array.includes(name),
        })
      | Error(e) => Error(e)
      }
    })

    // Collect all errors or all successes
    let errors = results->Array.filterMap(r =>
      switch r {
      | Error(e) => Some(e)
      | Ok(_) => None
      }
    )->Array.flat

    if Array.length(errors) > 0 {
      Error(errors)
    } else {
      let fields = results->Array.filterMap(r =>
        switch r {
        | Ok(f) => Some(f)
        | Error(_) => None
        }
      )
      Ok(Object(fields))
    }
  | Some(_) => Error([Errors.makeError(~kind=InvalidJson("properties must be an object"), ())])
  | None => Ok(Object([]))  // Empty object
  }
}

// Main parse object dispatcher
and parseObject = (dict: Dict.t<JSON.t>): result<schemaType, Errors.errors> => {
  // Check for anyOf first
  switch dict->Dict.get("anyOf") {
  | Some(Array(items)) => parseAnyOf(items)
  | Some(_) => Error([Errors.makeError(~kind=InvalidJson("anyOf must be an array"), ())])
  | None => parsePrimitiveType(dict)
  }
}

// Public API
let parse = parseSchema
