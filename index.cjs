const path = require('node:path');

const pipelines = require('./pipelines.json');
const transforms = require('./transforms.json');
const workloadDiagrams = require('./workload-diagrams.json');

const packageRoot = __dirname;

function getPipeline(id) {
  return pipelines[id];
}

function getTransform(id) {
  return transforms[id];
}

function resolvePipelinePath(id) {
  const entry = getPipeline(id);
  if (!entry || !entry.file) return null;

  return path.join(packageRoot, 'pipelines', entry.file);
}

function resolveTransformPath(id) {
  const entry = getTransform(id);
  if (!entry || !entry.file) return null;

  return path.join(packageRoot, 'transforms', entry.file);
}

module.exports = {
  packageRoot,
  pipelines,
  transforms,
  workloadDiagrams,
  getPipeline,
  getTransform,
  resolvePipelinePath,
  resolveTransformPath,
};
