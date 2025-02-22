import Path from "node:path"
import FS from "node:fs/promises"
import Civet from "@danielx/civet"
import * as swc from "@swc/core"
import config from "./config"

current = ->
  [ major ] = process.versions.node.split "."
  major

loadModule = ->
  do ({ path, pkg } = {}) ->
    path = Path.resolve "./package.json"
    pkg = await FS.readFile path, "utf8"
    JSON.parse pkg

Presets =

  node: do ({ module } = {}) ->
    ( context ) ->
      do ({ source, input, js, code } = {}) ->
        { source, input } = context
        module ?= await do loadModule 
        js = Civet.compile input,
          sync: true
          js: true
          inlineMap: true
          filename: "/#{ module.name }/#{ source.path }"
          parseOptions: config
        { code } = await swc.transform js,
            inputSourceMap: true  
            sourceMaps: "inline" 
            jsc:
              parser:
                syntax: "ecmascript"
            module:
              type: "commonjs"
            env:
              targets:
                node: current()
        code

  browser: do ({ module, mode, path } = {}) ->
    ({ build, source, input }) ->
      { mode } = build
      if source?.path?
        module ?= await do loadModule 
        path = "/#{ module.name }/#{ source.path }"
      mode ?= "debug"
      js = Civet.compile input,
        sync: true
        js: true
        inlineMap: mode == "debug"
        filename: path
        parseOptions: config
      { code } = await swc.transform js,
        inputSourceMap: mode == "debug"
        sourceMaps: if mode == "debug" then "inline" else false
        jsc:
          parser:
            syntax: "ecmascript"
          experimental:
            keepImportAssertions: true
        env:
          targets: "last 2 chrome versions,
            last 2 firefox versions,
            last 2 safari versions,
            last 2 ios_saf versions"
      code

civet = ( context ) ->
  if ( preset = Presets[ context.build.preset ])?
    ( preset context )
  else
    throw new Error "masonry: unknown CivetScript preset
      #{ context.build.preset }"

export default civet
export { civet }