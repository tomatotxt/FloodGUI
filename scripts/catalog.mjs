import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const files=fs.readdirSync(path.join(root,'TAS FILES')).filter(name=>/\.(json|fe2tomatas)$/.test(name)).sort();
const catalog=files.map(name=>({name,path:`TAS FILES/${name}`}));
fs.writeFileSync(path.join(root,'tas-catalog.json'),JSON.stringify(catalog,null,2)+'\n');
console.log(`Catalog updated: ${catalog.length} recordings.`);
