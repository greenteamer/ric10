/* TypeScript file generated from CodegenTypes.res by genType. */

/* eslint-disable */
/* tslint:disable */

export type backend = "IC10" | "WASM";

export type compilerOptions = {
  readonly debugAST: boolean; 
  readonly includeComments: boolean; 
  readonly backend: backend
};
