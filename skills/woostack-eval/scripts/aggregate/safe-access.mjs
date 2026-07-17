import { createHash, randomBytes as cryptoRandomBytes } from 'node:crypto';
import { constants as fsConstants } from 'node:fs';
import {
  link,
  lstat,
  open,
  opendir,
  readdir,
  realpath,
  unlink,
} from 'node:fs/promises';
import path from 'node:path';
import { isDeepStrictEqual } from 'node:util';

import {
  VARIANTS,
  compareText,
  exactKeys,
  isObject,
  same,
} from './contracts.mjs';

const MAX_MATERIALIZED_BYTES = 1024 * 1024;
const MAX_SNAPSHOT_FILE_BYTES = 16 * 1024 * 1024;
const MAX_SNAPSHOT_TOTAL_BYTES = 128 * 1024 * 1024;
const MAX_SNAPSHOT_ENTRIES = 4096;
const closeHandle = (handle) => handle.close();

function statIdentity(stats) {
  return {
    dev: String(stats.dev),
    ino: String(stats.ino),
    size: String(stats.size),
    mtimeNs: String(stats.mtimeNs),
  };
}

function snapshotFailure(evidencePath, message) {
  const error = new Error(`snapshot-mutation: ${message}`);
  error.code = 'snapshot-mutation';
  error.field = '';
  error.path = evidencePath;
  return error;
}

function snapshotLimitFailure(evidencePath, message) {
  const error = new Error(`snapshot-limit-exceeded: ${message}`);
  error.code = 'snapshot-limit-exceeded';
  error.field = '';
  error.path = evidencePath;
  return error;
}

function combinedFailure(primary, secondary, message) {
  return new AggregateError(
    [primary, secondary],
    `${message}: ${primary.message}; ${secondary.message}`,
    { cause: primary },
  );
}

function preservePrimaryFailure(primary, secondary, message) {
  primary.message = `${primary.message}; ${message}: ${secondary.message}`;
  primary.cleanupErrors = [...(primary.cleanupErrors ?? []), secondary];
  return primary;
}

function toPosix(value) {
  return value.split(path.sep).join('/');
}

function contained(root, candidate) {
  const relative = path.relative(root, candidate);
  return relative === ''
    || (!relative.startsWith(`..${path.sep}`)
      && relative !== '..'
      && !path.isAbsolute(relative));
}

function relativeTo(root, candidate) {
  return toPosix(path.relative(root, candidate));
}

async function requireDirectoryChain(root, candidate, label) {
  if (!contained(root, candidate)) throw new Error(`${label} escapes the run root`);
  const relative = path.relative(root, candidate);
  let cursor = root;
  for (const part of relative ? relative.split(path.sep) : []) {
    cursor = path.join(cursor, part);
    let stats;
    try {
      stats = await lstat(cursor);
    } catch {
      throw new Error(`${label} must already exist as a directory`);
    }
    if (stats.isSymbolicLink() || !stats.isDirectory()) {
      throw new Error(`${label} must not traverse symlinks or non-directories`);
    }
  }
}

async function openedDirectoryIdentity(absolutePath, {
  evidencePath = '',
  closeOpenedHandle = closeHandle,
} = {}) {
  let handle;
  let failure;
  try {
    handle = await open(
      absolutePath,
      fsConstants.O_RDONLY
        | (fsConstants.O_DIRECTORY ?? 0)
        | (fsConstants.O_NOFOLLOW ?? 0),
    );
  } catch (error) {
    if (['ENOENT', 'ENOTDIR', 'ELOOP'].includes(error?.code)) return null;
    throw error;
  }
  try {
    const stats = await handle.stat({ bigint: true });
    return stats.isDirectory() ? statIdentity(stats) : null;
  } catch (error) {
    failure = error;
    throw error;
  } finally {
    try {
      await closeOpenedHandle(handle, evidencePath);
    } catch (error) {
      if (!failure) throw error;
      failure = preservePrimaryFailure(failure, error, 'directory-handle cleanup failed');
    }
  }
}

async function openedNodeIdentity(absolutePath, {
  evidencePath,
  maxFileBytes,
  maxTotalBytes,
  closeOpenedHandle = closeHandle,
}) {
  let handle;
  let failure;
  try {
    handle = await open(
      absolutePath,
      fsConstants.O_RDONLY
        | (fsConstants.O_NONBLOCK ?? 0)
        | (fsConstants.O_NOFOLLOW ?? 0),
    );
  } catch (error) {
    if (['ENOENT', 'ENOTDIR', 'ELOOP'].includes(error?.code)) return null;
    throw error;
  }
  try {
    const before = await handle.stat({ bigint: true });
    if (before.isDirectory()) return { kind: 'directory', identity: statIdentity(before) };
    if (!before.isFile()) return { kind: 'special', identity: statIdentity(before) };
    if (before.size > BigInt(maxFileBytes)) {
      throw snapshotLimitFailure(evidencePath, `Run file exceeds the ${maxFileBytes}-byte snapshot limit`);
    }
    if (before.size > BigInt(maxTotalBytes)) {
      throw snapshotLimitFailure(evidencePath, `Run files exceed the ${MAX_SNAPSHOT_TOTAL_BYTES}-byte cumulative snapshot limit`);
    }
    const hash = createHash('sha256');
    let byteCount = 0;
    for await (const chunk of handle.createReadStream({ autoClose: false })) {
      byteCount += chunk.length;
      if (byteCount > maxFileBytes) {
        throw snapshotLimitFailure(evidencePath, `Run file exceeds the ${maxFileBytes}-byte snapshot limit`);
      }
      if (byteCount > maxTotalBytes) {
        throw snapshotLimitFailure(evidencePath, `Run files exceed the ${MAX_SNAPSHOT_TOTAL_BYTES}-byte cumulative snapshot limit`);
      }
      hash.update(chunk);
    }
    const after = await handle.stat({ bigint: true });
    if (!isDeepStrictEqual(statIdentity(before), statIdentity(after))) {
      throw snapshotFailure(evidencePath, 'A run file changed while its snapshot identity was built');
    }
    return {
      kind: 'file',
      identity: statIdentity(after),
      sha256: `sha256:${hash.digest('hex')}`,
      byteCount,
    };
  } catch (error) {
    failure = error;
    throw error;
  } finally {
    try {
      await closeOpenedHandle(handle, evidencePath);
    } catch (error) {
      if (!failure) throw error;
      failure = preservePrimaryFailure(failure, error, 'file-handle cleanup failed');
    }
  }
}

function indexRunSnapshot(snapshot) {
  return {
    directories: new Map(snapshot.directories),
    entries: new Map(snapshot.entries),
  };
}

function snapshotEntryState(snapshot, relativePath) {
  const entry = snapshot.entries.get(relativePath);
  if (entry) return entry.kind === 'file' ? { kind: 'file', entry } : { kind: 'non-regular' };
  if (snapshot.directories.has(relativePath)) return { kind: 'non-regular' };

  const parts = relativePath.split('/');
  for (let index = 1; index < parts.length; index += 1) {
    const ancestor = parts.slice(0, index).join('/');
    if (snapshot.entries.has(ancestor)) return { kind: 'non-regular' };
    if (!snapshot.directories.has(ancestor)) return { kind: 'missing' };
  }
  return { kind: 'missing' };
}

async function regularFile(root, relativePath, {
  materialize = true,
  maxBytes = MAX_MATERIALIZED_BYTES,
  snapshot = null,
  snapshotPath = relativePath,
} = {}) {
  if (typeof relativePath !== 'string' || relativePath.length === 0 || path.isAbsolute(relativePath)) {
    return { kind: 'unsafe' };
  }
  const canonical = relativePath.replaceAll('\\', '/');
  const parts = canonical.split('/');
  if (canonical !== relativePath || parts.some((part) => part === '' || part === '.' || part === '..')) {
    return { kind: 'unsafe' };
  }
  const absolute = path.resolve(root, ...parts);
  if (!contained(root, absolute) || absolute === root) return { kind: 'unsafe' };
  const expected = snapshot ? snapshotEntryState(snapshot, snapshotPath) : null;
  if (expected && expected.kind !== 'file') return { kind: expected.kind };

  const rootIdentity = await openedDirectoryIdentity(root);
  if (!rootIdentity) return { kind: 'non-regular' };
  const directories = [{ path: root, identity: rootIdentity }];
  let cursor = root;
  for (const part of parts.slice(0, -1)) {
    cursor = path.join(cursor, part);
    const identity = await openedDirectoryIdentity(cursor);
    if (!identity) return { kind: 'non-regular' };
    directories.push({ path: cursor, identity });
  }

  let handle;
  try {
    handle = await open(
      absolute,
      fsConstants.O_RDONLY
        | (fsConstants.O_NONBLOCK ?? 0)
        | (fsConstants.O_NOFOLLOW ?? 0),
    );
  } catch (error) {
    if (['ENOENT', 'ENOTDIR'].includes(error?.code)) return { kind: 'missing' };
    if (['ELOOP', 'EISDIR'].includes(error?.code)) return { kind: 'non-regular' };
    throw error;
  }
  try {
    const before = await handle.stat({ bigint: true });
    if (!before.isFile()) return { kind: 'non-regular' };
    const hash = createHash('sha256');
    const chunks = [];
    let byteCount = 0;
    let tooLarge = false;
    for await (const chunk of handle.createReadStream({ autoClose: false })) {
      byteCount += chunk.length;
      hash.update(chunk);
      if (materialize && !tooLarge) {
        if (byteCount > maxBytes) tooLarge = true;
        else chunks.push(chunk);
      }
    }
    const after = await handle.stat({ bigint: true });
    const identity = statIdentity(after);
    if (!same(statIdentity(before), identity)) return { kind: 'replaced' };
    for (const directory of directories) {
      const directoryIdentity = await openedDirectoryIdentity(directory.path);
      if (!directoryIdentity || !same(directoryIdentity, directory.identity)) return { kind: 'replaced' };
    }
    const digest = `sha256:${hash.digest('hex')}`;
    if (expected && (
      !same(identity, expected.entry.identity)
      || byteCount !== expected.entry.byteCount
      || digest !== expected.entry.sha256
    )) {
      throw snapshotFailure(snapshotPath, 'A consumed run file differs from its immutable snapshot');
    }
    if (tooLarge) return { kind: 'too-large', byteCount };
    return {
      kind: 'file',
      absolute,
      bytes: materialize ? Buffer.concat(chunks, byteCount) : null,
      byteCount,
      sha256: digest,
    };
  } finally {
    await handle.close();
  }
}

async function requireManifestWorkspaces(runRoot, manifest) {
  for (const pair of manifest.pairs) {
    for (const variant of VARIANTS) {
      const workspace = path.resolve(runRoot, ...pair[variant].split('/'));
      await requireDirectoryChain(
        runRoot,
        workspace,
        `manifest ${variant} workspace ${pair.caseId}/${pair.repetition}`,
      );
    }
  }
}

async function requirePrivateRunRoot(runRoot) {
  const state = await lstat(runRoot);
  if (!state.isDirectory() || state.isSymbolicLink() || (state.mode & 0o077) !== 0) {
    throw new Error('run root must be a private mode-0700 non-symlink directory');
  }
}

async function requireQuiescenceProof(runRoot, manifest, snapshot = null) {
  const state = await regularFile(runRoot, 'quiescence.json', { snapshot });
  if (state.kind !== 'file') throw new Error('host quiescence proof is missing or unsafe');
  let proof;
  try {
    proof = JSON.parse(state.bytes.toString('utf8'));
  } catch {
    throw new Error('host quiescence proof is invalid');
  }
  if (!exactKeys(proof, ['schemaVersion', 'runId', 'dispatchClosed'])
    || proof.schemaVersion !== 1
    || proof.runId !== manifest.runId
    || proof.dispatchClosed !== true) {
    throw new Error('host quiescence proof is invalid');
  }
}

async function captureRunSnapshot(runRoot, {
  closeOpenedHandle = closeHandle,
  beforeOpenEntry = null,
} = {}) {
  const directories = new Map();
  const entries = new Map();
  let entryCount = 1;
  let totalBytes = 0;

  async function readNames(absoluteDirectory, relativeDirectory) {
    const names = [];
    for await (const entry of await opendir(absoluteDirectory)) {
      names.push(entry.name);
      if (entryCount + names.length > MAX_SNAPSHOT_ENTRIES) {
        throw snapshotLimitFailure(
          relativeDirectory,
          `Run tree exceeds the ${MAX_SNAPSHOT_ENTRIES}-entry snapshot limit`,
        );
      }
    }
    entryCount += names.length;
    return names.sort(compareText);
  }

  async function walk(absoluteDirectory, relativeDirectory, expectedIdentity = null) {
    const openedDirectory = await openedDirectoryIdentity(absoluteDirectory, {
      evidencePath: relativeDirectory,
      closeOpenedHandle,
    });
    if (!openedDirectory
      || (expectedIdentity && !same(openedDirectory, expectedIdentity))) {
      throw snapshotFailure(relativeDirectory, 'A snapshotted directory is missing, replaced, or unsafe');
    }
    const names = await readNames(absoluteDirectory, relativeDirectory);
    directories.set(relativeDirectory, { identity: openedDirectory, names });
    for (const name of names) {
      const absoluteEntry = path.join(absoluteDirectory, name);
      const relativeEntry = relativeDirectory ? `${relativeDirectory}/${name}` : name;
      let listed;
      try {
        listed = await lstat(absoluteEntry, { bigint: true });
      } catch (error) {
        if (['ENOENT', 'ENOTDIR'].includes(error?.code)) {
          throw snapshotFailure(relativeEntry, 'A run entry changed while the snapshot was built');
        }
        throw error;
      }
      if (beforeOpenEntry) {
        await beforeOpenEntry({ absoluteEntry, relativeEntry });
      }
      if (listed.isSymbolicLink()) {
        entries.set(relativeEntry, { kind: 'symlink', identity: statIdentity(listed) });
        continue;
      }
      if (listed.isDirectory()) {
        await walk(absoluteEntry, relativeEntry, statIdentity(listed));
        continue;
      }
      const opened = await openedNodeIdentity(absoluteEntry, {
        evidencePath: relativeEntry,
        maxFileBytes: MAX_SNAPSHOT_FILE_BYTES,
        maxTotalBytes: MAX_SNAPSHOT_TOTAL_BYTES - totalBytes,
        closeOpenedHandle,
      });
      const expectedKind = listed.isFile() ? 'file' : 'special';
      if (!opened
        || opened.kind !== expectedKind
        || !same(opened.identity, statIdentity(listed))) {
        throw snapshotFailure(relativeEntry, 'A run entry changed while the snapshot was built');
      }
      if (opened.kind === 'file') totalBytes += opened.byteCount;
      entries.set(relativeEntry, opened);
    }
    const revalidatedDirectory = await openedDirectoryIdentity(absoluteDirectory, {
      evidencePath: relativeDirectory,
      closeOpenedHandle,
    });
    if (!revalidatedDirectory || !same(revalidatedDirectory, openedDirectory)) {
      throw snapshotFailure(relativeDirectory, 'A run directory changed while the snapshot was built');
    }
  }

  await walk(runRoot, '');
  return { directories: [...directories.entries()], entries: [...entries.entries()] };
}

async function buildRunSnapshot(runRoot, options) {
  const snapshot = await captureRunSnapshot(runRoot, options);
  const confirmation = await captureRunSnapshot(runRoot, options);
  if (!same(snapshot, confirmation)) {
    throw snapshotFailure('', 'The run changed while its immutable snapshot was established');
  }
  return snapshot;
}

async function revalidateRunSnapshot(runRoot, snapshot) {
  const current = await captureRunSnapshot(runRoot);
  if (!same(snapshot, current)) {
    throw snapshotFailure('', 'The run changed after its immutable snapshot was established');
  }
}

async function listDirectoryNames(runRoot, relativePath, snapshot = null) {
  const absolutePath = path.resolve(runRoot, ...relativePath.split('/'));
  if (snapshot) {
    const expected = snapshot.directories.get(relativePath);
    const current = await openedDirectoryIdentity(absolutePath);
    if (!expected || !current || !same(current, expected.identity)) {
      throw snapshotFailure(relativePath, 'A consumed run directory differs from its immutable snapshot');
    }
    return [...expected.names];
  }
  const before = await openedDirectoryIdentity(absolutePath);
  if (!before) {
    throw snapshotFailure(relativePath, 'Evidence directory is missing, replaced, or unsafe');
  }
  const names = (await readdir(absolutePath)).sort(compareText);
  const after = await openedDirectoryIdentity(absolutePath);
  if (!after || !same(before, after)) {
    throw snapshotFailure(relativePath, 'Evidence directory changed while it was enumerated');
  }
  return names;
}

async function parseFile(runRoot, relativePath, snapshot = null) {
  const state = await regularFile(runRoot, relativePath, { snapshot });
  if (state.kind !== 'file') return { state };
  try {
    const value = JSON.parse(state.bytes.toString('utf8'));
    if (!isObject(value)) return { state, malformed: true };
    return { state, value };
  } catch {
    return { state, malformed: true };
  }
}

function publicationDirectoryIdentity(stats) {
  return {
    dev: String(stats.dev),
    ino: String(stats.ino),
    uid: String(stats.uid),
    mode: String(stats.mode),
  };
}

async function requirePrivatePublicationParent(parent) {
  let canonical;
  try {
    canonical = await realpath(parent);
  } catch {
    throw new Error('publication parent must be an existing private directory');
  }
  const listed = await lstat(parent, { bigint: true });
  const currentUid = typeof process.getuid === 'function' ? BigInt(process.getuid()) : listed.uid;
  if (!listed.isDirectory()
    || listed.isSymbolicLink()
    || (listed.mode & 0o077n) !== 0n
    || listed.uid !== currentUid) {
    throw new Error('publication parent must be an owner-private non-symlink directory');
  }
  const handle = await open(
    parent,
    fsConstants.O_RDONLY
      | (fsConstants.O_DIRECTORY ?? 0)
      | (fsConstants.O_NOFOLLOW ?? 0),
  );
  try {
    const opened = await handle.stat({ bigint: true });
    if (!opened.isDirectory()
      || !same(publicationDirectoryIdentity(opened), publicationDirectoryIdentity(listed))) {
      throw new Error('publication parent changed while it was opened');
    }
    return { handle, identity: publicationDirectoryIdentity(opened), canonical };
  } catch (error) {
    try {
      await handle.close();
    } catch (closeError) {
      throw combinedFailure(error, closeError, 'publication parent validation and cleanup failed');
    }
    throw error;
  }
}

async function revalidatePublicationParent(parent, directory) {
  if (await realpath(parent) !== directory.canonical) {
    throw new Error('publication parent changed before commit');
  }
  const listed = await lstat(parent, { bigint: true });
  if (!listed.isDirectory()
    || listed.isSymbolicLink()
    || (listed.mode & 0o077n) !== 0n
    || !same(publicationDirectoryIdentity(listed), directory.identity)) {
    throw new Error('publication parent changed before commit');
  }
}

async function rollbackLinkedOutput(
  outPath,
  parent,
  directory,
  tempIdentity,
  syncDirectory,
  closeOpenedHandle,
) {
  let finalHandle;
  let failure;
  try {
    finalHandle = await open(
      outPath,
      fsConstants.O_RDONLY
        | (fsConstants.O_NONBLOCK ?? 0)
        | (fsConstants.O_NOFOLLOW ?? 0),
    );
    const opened = await finalHandle.stat({ bigint: true });
    const listed = await lstat(outPath, { bigint: true });
    if (!opened.isFile()
      || listed.isSymbolicLink()
      || !same(statIdentity(opened), statIdentity(listed))
      || opened.dev !== tempIdentity.dev
      || opened.ino !== tempIdentity.ino) {
      throw new Error('publication rollback refused an unexpected final file');
    }
    await revalidatePublicationParent(parent, directory);
    // The verified parent is owner-private, and the identity handle remains open across unlink.
    await unlink(outPath);
    await syncDirectory(directory.handle);
  } catch (error) {
    failure = error;
    throw error;
  } finally {
    if (finalHandle) {
      try {
        await closeOpenedHandle(finalHandle, outPath);
      } catch (error) {
        if (!failure) throw error;
        failure = preservePrimaryFailure(
          failure,
          error,
          'rollback final-handle cleanup failed',
        );
      }
    }
  }
}

async function publishCreateNew(outPath, contents, {
  syncDirectory = (directoryHandle) => directoryHandle.sync(),
  removeTemp = unlink,
  closeOpenedHandle = closeHandle,
  randomBytes = cryptoRandomBytes,
} = {}) {
  if (typeof contents !== 'string' && !Buffer.isBuffer(contents)) {
    throw new TypeError('publication contents must be a string or Buffer');
  }
  const absoluteOut = path.resolve(outPath);
  const parent = path.dirname(absoluteOut);
  const tempPath = path.join(
    parent,
    `.${path.basename(absoluteOut)}.${process.pid}.${randomBytes(8).toString('hex')}.tmp`,
  );
  const directory = await requirePrivatePublicationParent(parent);
  let tempHandle;
  let tempCreated = false;
  let tempIdentity;
  let linked = false;
  let committed = false;
  let failure = null;
  try {
    tempHandle = await open(tempPath, 'wx', 0o600);
    tempCreated = true;
    await tempHandle.writeFile(contents);
    await tempHandle.sync();
    const stats = await tempHandle.stat({ bigint: true });
    tempIdentity = { dev: stats.dev, ino: stats.ino };
    await closeOpenedHandle(tempHandle, tempPath);
    tempHandle = null;

    await revalidatePublicationParent(parent, directory);
    await link(tempPath, absoluteOut);
    linked = true;
    await removeTemp(tempPath);
    tempCreated = false;
    await syncDirectory(directory.handle);
    committed = true;
  } catch (error) {
    failure = error;
    if (linked && !committed) {
      try {
        await rollbackLinkedOutput(
          absoluteOut,
          parent,
          directory,
          tempIdentity,
          syncDirectory,
          closeOpenedHandle,
        );
      } catch (rollbackError) {
        failure = combinedFailure(
          failure,
          rollbackError,
          'publication and rollback failed',
        );
      }
    }
  }

  if (tempHandle) {
    try {
      await closeOpenedHandle(tempHandle, tempPath);
    } catch (error) {
      failure = failure
        ? combinedFailure(failure, error, 'publication and temporary-handle cleanup failed')
        : error;
    }
  }
  if (tempCreated) {
    try {
      await removeTemp(tempPath);
      tempCreated = false;
    } catch (error) {
      if (error?.code !== 'ENOENT') {
        failure = failure
          ? combinedFailure(failure, error, 'publication and temporary-file cleanup failed')
          : error;
      }
    }
  }
  try {
    await closeOpenedHandle(directory.handle, parent);
  } catch (error) {
    if (!failure && committed) {
      failure = new Error('publication committed but directory-handle cleanup failed', {
        cause: error,
      });
    } else {
      failure = failure
        ? combinedFailure(failure, error, 'publication and directory-handle cleanup failed')
        : error;
    }
  }
  if (failure) throw failure;
}

async function writeCreateNew(outPath, value, options) {
  await publishCreateNew(outPath, `${JSON.stringify(value, null, 2)}\n`, options);
}

export {
  buildRunSnapshot,
  indexRunSnapshot,
  contained,
  listDirectoryNames,
  parseFile,
  publishCreateNew,
  regularFile,
  relativeTo,
  requireDirectoryChain,
  requireManifestWorkspaces,
  requirePrivateRunRoot,
  requireQuiescenceProof,
  revalidateRunSnapshot,
  writeCreateNew,
};
