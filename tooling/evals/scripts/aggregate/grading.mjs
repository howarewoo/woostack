import path from 'node:path';

import {
  CAPABILITIES,
  COMPLETION_STATUSES,
  KEBAB,
  completionIdentityValid,
  exactKeys,
  isObject,
  nonEmptyString,
  sanitizeMessage,
} from './contracts.mjs';



function capabilitiesValid(capabilities) {
  return Array.isArray(capabilities)
    && capabilities.every((item) => typeof item === 'string' && CAPABILITIES.has(item))
    && new Set(capabilities).size === capabilities.length;
}

function completionPayloadError(completionStatus, error) {
  if (!COMPLETION_STATUSES.has(completionStatus)) {
    return {
      field: '/completionStatus',
      message: 'Completion status must be complete, failed, or timed-out',
    };
  }
  if (completionStatus === 'complete') {
    return error === null
      ? null
      : { field: '/error', message: 'A completed result must have a null error' };
  }
  if (!exactKeys(error, ['code', 'message'])
    || !KEBAB.test(error.code ?? '')
    || !nonEmptyString(error.message)
    || sanitizeMessage(error.message) !== error.message) {
    return {
      field: '/error',
      message: 'A failed or timed-out result requires the canonical error shape',
    };
  }
  return null;
}

function qualitativePayloadError(grade) {
  const completionError = completionPayloadError(grade.completionStatus, grade.error);
  if (completionError) return completionError;
  if (grade.completionStatus === 'complete') {
    if (typeof grade.pass !== 'boolean') {
      return { field: '/pass', message: 'A completed grade requires a boolean pass value' };
    }
    if (!nonEmptyString(grade.rationale)) {
      return { field: '/rationale', message: 'A completed grade requires a non-empty rationale' };
    }
  } else {
    if (grade.pass !== null) {
      return { field: '/pass', message: 'An incomplete grade must have a null pass value' };
    }
    if (grade.rationale !== null) {
      return { field: '/rationale', message: 'An incomplete grade must have a null rationale' };
    }
  }
  return null;
}

function parseJsonPointer(pointer) {
  if (pointer === '') return [];
  if (typeof pointer !== 'string' || !pointer.startsWith('/')) return null;
  return pointer.slice(1).split('/').map((part) => part.replace(/~1/g, '/').replace(/~0/g, '~'));
}

function pointerValue(root, pointer) {
  const parts = parseJsonPointer(pointer);
  if (parts === null) return { found: false };
  let value = root;
  for (const part of parts) {
    if (Array.isArray(value)) {
      if (!/^(?:0|[1-9][0-9]*)$/.test(part)) return { found: false };
      const index = Number(part);
      if (!Number.isSafeInteger(index)
        || index >= value.length
        || !Object.hasOwn(value, index)) {
        return { found: false };
      }
      value = value[index];
      continue;
    }
    if (!isObject(value) || !Object.hasOwn(value, part)) return { found: false };
    value = value[part];
  }
  return { found: true, value };
}

function gradeFilename(relativePath) {
  const match = /^grade\.([a-z0-9-]+)\.(candidate|baseline)\.([1-9][0-9]*)\.([a-z0-9-]+)\.json$/
    .exec(path.basename(relativePath));
  if (!match) return null;
  return {
    caseId: match[1],
    variant: match[2],
    repetition: Number(match[3]),
    graderId: match[4],
  };
}

function inputFilename(relativePath) {
  const match = /^input\.([a-z0-9-]+)\.(candidate|baseline)\.([1-9][0-9]*)\.([a-z0-9-]+)\.json$/
    .exec(path.basename(relativePath));
  if (!match) return null;
  return {
    caseId: match[1],
    variant: match[2],
    repetition: Number(match[3]),
    graderId: match[4],
  };
}

export {
  capabilitiesValid,
  completionIdentityValid,
  completionPayloadError,
  gradeFilename,
  inputFilename,
  pointerValue,
  qualitativePayloadError,
};
