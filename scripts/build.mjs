import { spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { dirname, join, delimiter } from 'node:path';
import { fileURLToPath } from 'node:url';

const project = dirname(dirname(fileURLToPath(import.meta.url)));
const deveco = process.env.DEVECO_HOME || '/Applications/DevEco-Studio.app/Contents';
const env = {
  ...process.env,
  PATH: [join(deveco, 'tools/node/bin'), join(deveco, 'tools/ohpm/bin'), process.env.PATH].join(delimiter),
  JAVA_HOME: join(deveco, 'jbr'),
  DEVECO_SDK_HOME: join(deveco, 'sdk')
};
for (const [tool, args] of [
  ['tools/ohpm/bin/ohpm', ['install']],
  ['tools/hvigor/bin/hvigorw', ['assembleHap', '--mode', 'module', '-p', 'product=default', '-p', 'buildMode=release', '--no-daemon']]
]) {
  const executable = join(deveco, tool);
  if (!existsSync(executable)) throw new Error(`缺少构建工具 ${executable}`);
  const result = spawnSync(executable, args, { cwd: project, env, stdio: 'inherit' });
  if (result.error) throw result.error;
  if (result.status !== 0) process.exit(result.status || 1);
}
