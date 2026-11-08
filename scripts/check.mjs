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
const timingCases=[];
for(const item of catalog){
  assert.equal(item.path,`TAS FILES/${item.name}`);
  const bytes=fs.readFileSync(path.join(root,item.path));
  if(item.name.endsWith('.json')){
    const data=JSON.parse(bytes);assert(Array.isArray(data)&&data.length>0,item.name);frames+=data.length;
    let previous=0, repairs=0;
    for(const frame of data){
      for(const [field,size] of [['CCFrame',6],['CCameraCFrame',6],['VVelocity',3]])assert(Array.isArray(frame[field])&&frame[field].length===size&&frame[field].every(Number.isFinite),`${item.name}: ${field}`);
      assert(Number.isFinite(frame.time),item.name);
      assert(frame.time>=0,`${item.name}: negative timestamp`);
      if(frame.time<previous){assert(previous-frame.time<=0.01,`${item.name}: unsupported timestamp reversal`);repairs++;}
      previous=Math.max(previous,frame.time);
    }
    if(repairs)timingCases.push({name:item.name,times:data.map(frame=>frame.time),repairs});
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
const service=fs.readFileSync(path.join(root,'ui/service.luau'),'utf8');
assert(service.includes('Runtime.run("ui/kavo.luau")')&&!service.includes('vendor/airflow.luau'),'Active UI must use the Kavo renderer');
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
assert(fetched[1]:match('^https://raw%.githubusercontent%.com/tomatotxt/FloodGUI/live/runtime%.luau%?v=.+$'))
local offline=assert(environment.loadstring(source));assert(offline({localOnly=true})=='started' and #fetched==1)
assert(not pcall(offline,{root='../outside'}))
for _,invalid in ipairs({'partial/../outside','partial/CON','a//b','a./b'}) do
  local before=0;for _ in pairs(folders)do before+=1 end
  assert(not pcall(offline,{root=invalid}))
  local after=0;for _ in pairs(folders)do after+=1 end
  assert(before==after,'Invalid root created partial folders')
end
assert(not pcall(offline,{localOnly='true'}))
print('PASS: actual online/local loader entry points and invalid root rejection')
`;
const temp=fs.mkdtempSync(path.join(os.tmpdir(),'floodgui-check-'));
try{
  const file=path.join(temp,'loader.spec.luau');fs.writeFileSync(file,harness);execFileSync(tool('luau'),[file],{stdio:'inherit'});
  const modules=['ui/main.luau','ui/creator.luau','ui/recordings.luau','ui/player.luau'];
  const literal=text=>`[====[${text}]====]`;
  const sources=modules.map(name=>`[${JSON.stringify(name)}]=${literal(fs.readFileSync(path.join(root,name),'utf8'))}`).join(',\n');
  const uiTest=fs.readFileSync(path.join(root,'tests/ui-harness.luau'),'utf8');
  const uiFile=path.join(temp,'ui.spec.luau');
  fs.writeFileSync(uiFile,`local test=assert(loadstring(${literal(uiTest)}))()\ntest({${sources}})`);
  execFileSync(tool('luau'),[uiFile],{stdio:'inherit'});
  const airflowSource=fs.readFileSync(path.join(root,'vendor/airflow.luau'),'utf8');
  const iconPatterns=[/Icon\s*=\s*"([a-z][a-z0-9-]*)"/g, /\btab\(\s*"[^"]*",\s*"[^"]*",\s*"([^"]*)"/g, /\b(?:action|button)\(\s*[^,]+,\s*"[^"]*",\s*"[^"]*",\s*(?:nil|"[^"]*"),\s*"([^"]*)"/g];
  const iconNames=[...new Set(modules.concat('ui/service.luau').flatMap(name=>iconPatterns.flatMap(pattern=>[...fs.readFileSync(path.join(root,name),'utf8').matchAll(pattern)].map(match=>match[1]))))];
  const airflowTest=fs.readFileSync(path.join(root,'tests/airflow-harness.luau'),'utf8');
  const airflowFile=path.join(temp,'airflow.spec.luau');
  fs.writeFileSync(airflowFile,`local test=assert(loadstring(${literal(airflowTest)}))()\ntest(${literal(airflowSource)}, {${iconNames.map(JSON.stringify).join(',')}})`);
  execFileSync(tool('luau'),[airflowFile],{stdio:'inherit'});
  const kavoTest=fs.readFileSync(path.join(root,'tests/kavo-harness.luau'),'utf8');
  const kavoFile=path.join(temp,'kavo.spec.luau');
  fs.writeFileSync(kavoFile,`local test=assert(loadstring(${literal(kavoTest)}))()\ntest(${literal(fs.readFileSync(path.join(root,'vendor/kavo.luau'),'utf8'))},${literal(fs.readFileSync(path.join(root,'ui/kavo.luau'),'utf8'))},${literal(fs.readFileSync(path.join(root,'vendor/input.luau'),'utf8'))})`);
  execFileSync(tool('luau'),[kavoFile],{stdio:'inherit'});
  const enginesTest=fs.readFileSync(path.join(root,'tests/tas-engines-harness.luau'),'utf8');
  const enginesFile=path.join(temp,'tas-engines.spec.luau');
  fs.writeFileSync(enginesFile,`local test=assert(loadstring(${literal(enginesTest)}))()\ntest(${literal(fs.readFileSync(path.join(root,'TAS/CREATOR/creator.luau'),'utf8'))},${literal(fs.readFileSync(path.join(root,'TAS/PLAYER/newtasplayer.luau'),'utf8'))})`);
  execFileSync(tool('luau'),[enginesFile],{stdio:'inherit'});
  const appTest=fs.readFileSync(path.join(root,'tests/app-harness.luau'),'utf8');
  const appFile=path.join(temp,'app.spec.luau');
  fs.writeFileSync(appFile,`local test=assert(loadstring(${literal(appTest)}))()\ntest(${literal(fs.readFileSync(path.join(root,'FloodGUI.luau'),'utf8'))})`);
  execFileSync(tool('luau'),[appFile],{stdio:'inherit'});
  const orderFile=path.join(temp,'legacy-time.spec.luau');
  const orderCases=timingCases.map(item=>`do local function check()
local zero={0,0,0,0,0,0};local velocity={0,0,0};local frames={}
for _,t in ipairs({${item.times.join(',')}})do table.insert(frames,{time=t,CCFrame=zero,CCameraCFrame=zero,VVelocity=velocity})end
local normalized,repairs=Codec.normalizeLegacy(frames)
assert(repairs==${item.repairs},${JSON.stringify(item.name)})
for i=2,#normalized do assert(normalized[i].time>=normalized[i-1].time)end
end check() end`).join('\n');
  fs.writeFileSync(orderFile,`local Codec=assert(loadstring(${literal(fs.readFileSync(path.join(root,'TAS/codec.luau'),'utf8'))}))()\n${orderCases}\nprint('PASS: actual codec normalizes timestamp jitter for all ${timingCases.length} affected bundled runs without rewriting them')`);
  execFileSync(tool('luau'),[orderFile],{stdio:'inherit'});
  const serviceTest=fs.readFileSync(path.join(root,'tests/ui-service-harness.luau'),'utf8');
  const serviceFile=path.join(temp,'ui-service.spec.luau');
  fs.writeFileSync(serviceFile,`local test=assert(loadstring(${literal(serviceTest)}))()\ntest(${literal(fs.readFileSync(path.join(root,'ui/service.luau'),'utf8'))},${literal(fs.readFileSync(path.join(root,'TAS/CREATOR/touch-controls.luau'),'utf8'))})`);
  execFileSync(tool('luau'),[serviceFile],{stdio:'inherit'});
}
finally{assert(path.resolve(temp).startsWith(path.resolve(os.tmpdir())+path.sep)&&path.basename(temp).startsWith('floodgui-check-'));fs.rmSync(temp,{recursive:true,force:true});}
console.log(`PASS: ${scripts.length} Luau files, ${catalog.length} recordings (${frames} JSON frames), loader references and dependency paths.`);
