/* TypeScript file generated from Compiler.res by genType. */

/* eslint-disable */
/* tslint:disable */

import * as CompilerJS from './Compiler.res.js';

import type {compilerOptions as CodegenTypes_compilerOptions} from './CodegenTypes.gen';

export const compile: (source:string, options:(undefined | CodegenTypes_compilerOptions), param:void) => 
    { TAG: "Ok"; _0: string }
  | { TAG: "Error"; _0: string } = CompilerJS.compile as any;
