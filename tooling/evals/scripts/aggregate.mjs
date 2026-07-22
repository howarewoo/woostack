import path from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  aggregate,
  runAggregateCli,
  sanitizeMessage,
  writeCreateNew,
} from './aggregate/core.mjs';

const entrypoint = process.argv[1] ? path.resolve(process.argv[1]) : null;
if (entrypoint && fileURLToPath(import.meta.url) === entrypoint) {
  runAggregateCli(process.argv.slice(2)).catch((error) => {
    process.stderr.write(`aggregate: ${sanitizeMessage(error?.message ?? error)}\n`);
    process.exitCode = 1;
  });
}

export { aggregate, writeCreateNew };
