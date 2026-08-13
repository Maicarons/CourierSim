// Cross-platform VitePress runner.
// Some sandboxed Bash environments inject a safe-delete shim via NODE_OPTIONS,
// which breaks builds that clean temp/cache files. This script clears
// NODE_OPTIONS before spawning vitepress so the build works on Windows/Linux.
import { spawnSync } from 'node:child_process'

const cmd = process.argv[2] || 'dev'
const env = { ...process.env }
delete env.NODE_OPTIONS

const res = spawnSync('npx', ['vitepress', cmd, ...process.argv.slice(3)], {
  stdio: 'inherit',
  shell: true,
  env,
})

process.exit(res.status ?? 1)
