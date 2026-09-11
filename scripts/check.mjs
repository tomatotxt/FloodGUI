import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const arg=process.argv.indexOf('--luau-dir');
const bin=arg>=0?path.resolve(process.argv[arg+1]):'';
const tool=name=>bin?path.join(bin,name+(process.platform==='win32'?'.exe':'')):name;
function walk(dir){return fs.readdirSync(dir,{withFileTypes:true}).flatMap(e=>e.name==='.git'?[]:e.isDirectory()?walk(path.join(dir,e.name)):[path.join(dir,e.name)]);}
const files=walk(root);
const scripts=files.filter(file=>/\.lua(u)?$/.test(file));
execFileSync(tool('luau-compile'),['--null',...scripts],{stdio:'inherit'});
for(const file of scripts.filter(file=>file.endsWith('.spec.luau'))){execFileSync(tool('luau'),[file],{stdio:'inherit'});}
const catalog=JSON.parse(fs.readFileSync(path.join(root,'tas-catalog.json')));
const actual=files.filter(file=>file.startsWith(path.join(root,'TAS FILES')+path.sep)&&/\.(json|fe2tomatas)$/.test(file)).map(file=>path.basename(file)).sort();
assert.deepEqual(catalog.map(x=>x.name).sort(),actual,'Run scripts/catalog.mjs after changing bundled recordings');
let frames=0;
for(const item of catalog){
  assert.equal(item.path,`TAS FILES/${item.name}`);
  const bytes=fs.readFileSync(path.join(root,item.path));
  if(item.name.endsWith('.json')){
    const data=JSON.parse(bytes);assert(Array.isArray(data)&&data.length>0,item.name);frames+=data.length;
    for(const frame of data){
      for(const [field,size] of [['CCFrame',6],['CCameraCFrame',6],['VVelocity',3]])assert(Array.isArray(frame[field])&&frame[field].length===size&&frame[field].every(Number.isFinite),`${item.name}: ${field}`);
      assert(Number.isFinite(frame.time),item.name);
    }
  }else{assert.equal(bytes.subarray(0,4).toString(),'FE2T');assert([2,3].includes(bytes[4]));}
}
for(const file of scripts.filter(file=>!file.includes(`${path.sep}tests${path.sep}`))){
  const source=fs.readFileSync(file,'utf8');
  assert(!/tomatotxt\/Flood-GUI\//.test(source),`Stale repository URL in ${file}`);
  assert(!source.includes('Misc Scripts/'),`Archived import in ${file}`);
  for(const match of source.matchAll(/(?:[Rr]untime\.run\(\s*|\b[A-Z_]+_PATH\s*=\s*)["']([^"']+)["']/g)){
    assert(fs.existsSync(path.join(root,match[1])),`Missing dependency: ${match[1]}`);
  }
}
const loader=fs.readFileSync(path.join(root,'loader.lua'),'utf8');
assert(loader.includes('https://raw.githubusercontent.com/tomatotxt/FloodGUI/live/'));
assert(loader.includes('runtime.run("FloodGUI.luau")'));
// Execute the actual loader source with mocked filesystem/network/runtime, not Roblox.
const harness=`local source=[====[${loader}]====]
local calls, folders, fetched = {}, {}, {}
local environment = setmetatable({getgenv=function()return {}end}, {__index=getfenv()})
environment.isfile=function()return true end
environment.isfolder=function(p)return folders[p]end
environment.makefolder=function(p)folders[p]=true end
environment.writefile=function()end
local runtimeSource="return function(root,options) assert(root=='FloodGUI'); return {run=function(p) assert(p=='FloodGUI.luau'); return 'started' end} end"
environment.readfile=function(p)assert(p=='FloodGUI/runtime.luau');return runtimeSource end
environment.game={HttpGet=function(_,url)table.insert(fetched,url);return runtimeSource end}
environment.getfenv=function()return environment end
environment.loadstring=function(text,name)local fn,err=loadstring(text,name);if fn then setfenv(fn,environment)end;return fn,err end
local online=assert(environment.loadstring(source));assert(online()=='started')
assert(fetched[1]=='https://raw.githubusercontent.com/tomatotxt/FloodGUI/live/runtime.luau')
local offline=assert(environment.loadstring(source));assert(offline({localOnly=true})=='started' and #fetched==1)
assert(not pcall(offline,{root='../outside'}))
print('PASS: actual online/local loader entry points and invalid root rejection')
`;
const temp=fs.mkdtempSync(path.join(os.tmpdir(),'floodgui-check-'));
try{const file=path.join(temp,'loader.spec.luau');fs.writeFileSync(file,harness);execFileSync(tool('luau'),[file],{stdio:'inherit'});}
finally{assert(path.resolve(temp).startsWith(path.resolve(os.tmpdir())+path.sep)&&path.basename(temp).startsWith('floodgui-check-'));fs.rmSync(temp,{recursive:true,force:true});}
console.log(`PASS: ${scripts.length} Luau files, ${catalog.length} recordings (${frames} JSON frames), loader references and dependency paths.`);
