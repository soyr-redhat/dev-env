#!/usr/bin/env node
import { readFileSync } from 'fs';
import yaml from 'js-yaml';

const BOILERPLATE_ENV = new Set(['USER', 'HOME', 'TORCHINDUCTOR_CACHE_DIR']);

const PROVIDER_MAP = {
  google: 'Google',
  redhatai: 'Red Hat AI',
  meta: 'Meta',
  'meta-llama': 'Meta',
  mistralai: 'Mistral AI',
  microsoft: 'Microsoft',
  ibm: 'IBM',
};

const PRECISION_PATTERNS = [
  [/fp8/i, 'fp8'],
  [/nvfp4/i, 'nvfp4'],
  [/fp4/i, 'fp4'],
  [/int4/i, 'int4'],
  [/int8/i, 'int8'],
  [/awq/i, 'awq'],
  [/gptq/i, 'gptq'],
  [/fp16/i, 'fp16'],
];

const VRAM_FROM_GPU = {
  'NVIDIA-H100-80GB-HBM3': 80,
  'NVIDIA-A100-SXM4-80GB': 80,
  'NVIDIA-A100-SXM4-40GB': 40,
  'NVIDIA-A100-PCIE-40GB': 40,
  'NVIDIA-A10G': 24,
  'NVIDIA-L4': 24,
  'NVIDIA-L40S': 48,
};

function titleCase(str) {
  return str
    .replace(/[-_]+/g, ' ')
    .replace(/\b\w/g, (c) => c.toUpperCase())
    .replace(/\b(It|Of|And|The|In|On|At|For)\b/g, (w) => w.toLowerCase())
    .replace(/\b(\d+[bBmM])\b/g, (w) => w.toUpperCase())
    .replace(/^./, (c) => c.toUpperCase());
}

function inferProvider(org) {
  const key = org.toLowerCase();
  return PROVIDER_MAP[key] || titleCase(org);
}

function inferPrecision(modelId) {
  for (const [pattern, precision] of PRECISION_PATTERNS) {
    if (pattern.test(modelId)) return precision;
  }
  return 'bf16';
}

function inferParams(modelId) {
  const match = modelId.match(/(\d+\.?\d*)\s*[bB]\b/);
  return match ? `${match[1]}B` : 'TODO';
}

function inferActiveParams(modelId) {
  const active = modelId.match(/[aA](\d+\.?\d*)[bB]/);
  if (active) return `${active[1]}B`;
  return null;
}

function inferVram(nodeSelector) {
  if (!nodeSelector) return 80;
  const gpu = nodeSelector['nvidia.com/gpu.product'];
  return (gpu && VRAM_FROM_GPU[gpu]) || 80;
}

function convert(input) {
  const docs = yaml.loadAll(input);
  const pod = docs.find(
    (d) => d && (d.kind === 'Pod' || d.kind === 'Deployment')
  );
  if (!pod) {
    throw new Error('No Pod or Deployment resource found in input');
  }

  const spec =
    pod.kind === 'Deployment'
      ? pod.spec?.template?.spec
      : pod.spec;

  const container = spec?.containers?.[0];
  if (!container) throw new Error('No container found in pod spec');

  const allArgs = container.args || [];
  let modelId = null;
  const vllmArgs = [];

  for (let i = 0; i < allArgs.length; i++) {
    const arg = allArgs[i];
    if (arg === '--model' && i + 1 < allArgs.length) {
      modelId = allArgs[++i];
    } else if (arg.startsWith('--model=')) {
      modelId = arg.split('=')[1];
    } else if (arg === '--port' && i + 1 < allArgs.length) {
      i++;
    } else if (arg.startsWith('--port=')) {
      // skip
    } else if (arg.startsWith('--')) {
      if (i + 1 < allArgs.length && !allArgs[i + 1].startsWith('--')) {
        vllmArgs.push(`${arg}=${allArgs[++i]}`);
      } else {
        vllmArgs.push(arg);
      }
    }
  }

  if (!modelId) throw new Error('Could not find --model argument');

  const [org, ...repoParts] = modelId.split('/');
  const repo = repoParts.join('/');

  const envVars = {};
  if (container.env) {
    for (const e of container.env) {
      if (!BOILERPLATE_ENV.has(e.name)) {
        envVars[e.name] = String(e.value);
      }
    }
  }

  const gpuCount =
    parseInt(container.resources?.limits?.['nvidia.com/gpu']) || 1;
  const cpu = container.resources?.requests?.cpu || '4';
  const memory = container.resources?.requests?.memory || '32Gi';

  const nodeSelector = spec.nodeSelector || null;

  let shmSize = null;
  if (spec.volumes) {
    const shm = spec.volumes.find(
      (v) => v.emptyDir?.medium === 'Memory'
    );
    if (shm?.emptyDir?.sizeLimit) shmSize = shm.emptyDir.sizeLimit;
  }

  const paramCount = inferParams(repo);
  const activeParams = inferActiveParams(repo) || paramCount;
  const precision = inferPrecision(modelId);

  let contextLength = 8192;
  for (const arg of vllmArgs) {
    const match = arg.match(/--max-model-len=(\d+)/);
    if (match) contextLength = parseInt(match[1]);
  }

  const recipe = {
    meta: {
      title: titleCase(repo),
      provider: inferProvider(org),
      description: 'TODO: Add model description',
      date_updated: new Date().toISOString().split('T')[0],
      tasks: ['text'],
    },
    model: {
      model_id: modelId,
      architecture: 'dense',
      parameter_count: paramCount,
      active_parameters: activeParams,
      context_length: contextLength,
    },
    variants: {
      default: {
        precision,
        min_gpus: gpuCount,
        vram_minimum_gb: inferVram(nodeSelector),
        description: 'TODO: Add variant description',
      },
    },
    deployment: {
      image: container.image,
    },
  };

  if (vllmArgs.length > 0) recipe.deployment.vllm_args = vllmArgs;
  if (Object.keys(envVars).length > 0) recipe.deployment.env = envVars;

  recipe.deployment.resources = { gpu: gpuCount, cpu, memory };

  if (nodeSelector) recipe.deployment.node_selector = nodeSelector;
  if (shmSize) recipe.deployment.shm_size = shmSize;

  return yaml.dump(recipe, {
    lineWidth: -1,
    quotingType: '"',
    forceQuotes: false,
    noRefs: true,
    sortKeys: false,
  });
}

const input = readFileSync(process.argv[2] || '/dev/stdin', 'utf8');
process.stdout.write(convert(input));
