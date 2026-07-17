const UNAVAILABLE = 'unavailable';

function mean(values) {
  return values.reduce((sum, value) => sum + value, 0) / values.length;
}

function populationVariance(values, average) {
  if (values.length < 2) return UNAVAILABLE;
  return values.reduce((sum, value) => sum + ((value - average) ** 2), 0) / values.length;
}

function metric(values) {
  if (values.length === 0) return UNAVAILABLE;
  const average = mean(values);
  return { mean: average, variance: populationVariance(values, average) };
}

function comparative(candidate, baseline) {
  return {
    candidate,
    baseline,
    delta: typeof candidate === 'number' && typeof baseline === 'number'
      ? candidate - baseline
      : UNAVAILABLE,
  };
}

function durationMetric(results, runs) {
  const observations = [];
  for (let repetition = 1; repetition <= runs; repetition += 1) {
    const values = results
      .filter((item) => item.repetition === repetition && item.completionStatus === 'complete')
      .map((item) => item.durationMs);
    if (values.length > 0) observations.push(mean(values));
  }
  return metric(observations);
}

function tokenMetric(results, runs) {
  const fields = ['input', 'output', 'total'];
  const observations = Object.fromEntries(fields.map((field) => [field, []]));
  for (let repetition = 1; repetition <= runs; repetition += 1) {
    const usages = results
      .filter((item) => item.repetition === repetition && item.completionStatus === 'complete')
      .map((item) => item.tokenUsage);
    if (usages.length === 0 || usages.some((usage) => usage === UNAVAILABLE)) return UNAVAILABLE;
    for (const field of fields) {
      observations[field].push(usages.reduce((sum, usage) => sum + usage[field], 0));
    }
  }
  return Object.fromEntries(fields.map((field) => [field, metric(observations[field])]));
}

function tokenComparison(candidate, baseline) {
  if (candidate === UNAVAILABLE || baseline === UNAVAILABLE) return UNAVAILABLE;
  return {
    candidate,
    baseline,
    delta: Object.fromEntries(['input', 'output', 'total'].map((field) => [
      field,
      candidate[field].mean - baseline[field].mean,
    ])),
  };
}

function triggerMetric(cases, targetSkill, variant, type) {
  let tp = 0;
  let fp = 0;
  let fn = 0;
  for (const entry of cases.filter((item) => item.kind === 'trigger')) {
    for (const result of entry[variant]) {
      const positive = entry.definition.shouldTrigger === true;
      const predicted = result.selectedSkill === targetSkill;
      if (positive && predicted) tp += 1;
      else if (!positive && predicted) fp += 1;
      else if (positive && !predicted) fn += 1;
    }
  }
  if (type === 'precision') return tp + fp === 0 ? UNAVAILABLE : tp / (tp + fp);
  return tp + fn === 0 ? UNAVAILABLE : tp / (tp + fn);
}

export {
  comparative,
  durationMetric,
  metric,
  tokenComparison,
  tokenMetric,
  triggerMetric,
};
