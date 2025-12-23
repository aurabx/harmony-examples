import pipelines from './pipelines.json' assert { type: 'json' };
import transforms from './transforms.json' assert { type: 'json' };
import workloadDiagrams from './workload-diagrams.json' assert { type: 'json' };
import { fileURLToPath } from 'node:url';
import { dirname } from 'node:path';

const packageRoot = dirname(fileURLToPath(import.meta.url));

function getPipeline(id) {
  return pipelines[id];
}

function getTransform(id) {
  return transforms[id];
}

function resolvePipelinePath(id) {
  const entry = getPipeline(id);
  if (!entry || !entry.file) return null;

  return packageRoot + '/pipelines/' + entry.file;
}

function resolveTransformPath(id) {
  const entry = getTransform(id);
  if (!entry || !entry.file) return null;

  return packageRoot + '/transforms/' + entry.file;
}

export {
  packageRoot,
  pipelines,
  transforms,
  workloadDiagrams,
  getPipeline,
  getTransform,
  resolvePipelinePath,
  resolveTransformPath,
};
