import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, resolve, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
const project = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const deveco = process.env.DEVECO_HOME || '/Applications/DevEco-Studio.app/Contents';
const ts = require(join(deveco, 'sdk/default/openharmony/ets/build-tools/ets-loader/node_modules/typescript'));

export function moduleUrl(path, replacements = []) {
  let source = readFileSync(join(project, path), 'utf8');
  for (const [from, to] of replacements) source = source.replaceAll(from, to);
  const output = ts.transpileModule(source, {
    fileName: path.replace(/\.ets$/, '.ts'),
    compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.ESNext }
  });
  return 'data:text/javascript;base64,' + Buffer.from(output.outputText).toString('base64');
}

