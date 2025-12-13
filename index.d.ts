export interface UseCase {
  title: string;
  description: string;
}

export interface PipelineCatalogEntry {
  name: string;
  shortDescription: string;
  description: string;
  categories: string[];
  tags: string[];
  useCases: UseCase[];
  prerequisites: string[];
  file: string;
  type: 'pipeline';
}

export interface TransformCatalogEntry {
  name: string;
  description: string;
  categories: string[];
  prerequisites: string[];
  file: string;
  type: 'transform';
}

export type PipelinesCatalog = Record<string, PipelineCatalogEntry>;
export type TransformsCatalog = Record<string, TransformCatalogEntry>;

declare const api: {
  packageRoot: string;
  pipelines: PipelinesCatalog;
  transforms: TransformsCatalog;
  getPipeline: (id: string) => PipelineCatalogEntry | undefined;
  getTransform: (id: string) => TransformCatalogEntry | undefined;
  resolvePipelinePath: (id: string) => string | null;
  resolveTransformPath: (id: string) => string | null;
};

export = api;
