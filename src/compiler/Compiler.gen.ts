/* TypeScript file generated from Compiler.res by genType. */

/* eslint-disable */
/* tslint:disable */

import * as CompilerJS from './Compiler.res.js';

export const compile: (source:string) => 
    { TAG: "Ok"; _0: string }
  | { TAG: "Error"; _0: string } = CompilerJS.compile as any;
