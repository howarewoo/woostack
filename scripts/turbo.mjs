import { createHash } from 'node:crypto'
import { spawnSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'
import path from 'node:path'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const identity = `node:${process.version};platform:${process.platform};arch:${process.arch}`
const runtimeHash = createHash('sha256').update(identity).digest('hex').slice(0, 16)

const turboBin = path.join(root, 'node_modules', '.bin', 'turbo')

const result = spawnSync(turboBin, process.argv.slice(2), {
  cwd: process.cwd(),
  env: {
    ...process.env,
    TURBO_RUNTIME_HASH: runtimeHash,
  },
  stdio: 'inherit',
})

if (result.error) {
  console.error(result.error)
  process.exit(1)
}
if (result.signal) {
  process.exit(1)
}
process.exit(result.status ?? 1)
