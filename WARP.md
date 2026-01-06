# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project overview

This repository packages example Harmony/Runbeam pipelines and transforms for healthcare and HTTP integration. It is primarily configuration (TOML, JSON) plus a small PHP utility and tests, and is also published as the `@aurabx/harmony-examples` npm package.

Key use cases:
- Ready-to-use example pipelines for HTTP, FHIR, DICOM, DICOMweb, JMIX, transforms, and security patterns
- A catalog of pipelines/transforms consumable from PHP and Node
- A Docker-based mesh networking example

High-level layout (see `README.md` for details):
- `pipelines/` – one directory per example pipeline, each with its own `README.md`, `config.toml`, and nested pipeline/transform config
- `transforms/` – shared JOLT transform JSON specs
- `src/TemplateLoader.php` – PHP utility to load the pipeline/transform catalogs
- `tests/TemplateLoaderTest.php` – PHPUnit tests for the loader and catalog structure
- `pipelines.json`, `transforms.json`, `workload-diagrams.json` – catalog metadata exported by the package
- `docker/` – Docker-based examples, including a mesh networking test setup

## Commands

### PHP dependencies and tests

Run from the repository root:

- Install PHP dependencies:
  ```bash path=null start=null
  composer install
  ```

- Run the full PHPUnit test suite:
  ```bash path=null start=null
  composer test
  ```

- Run a specific test file (for debugging TemplateLoader behaviour):
  ```bash path=null start=null
  vendor/bin/phpunit tests/TemplateLoaderTest.php
  ```

### Running an example pipeline with Harmony

The examples are configurations; you need a Harmony binary/runtime (e.g. from the main Harmony project or a system installation).

Typical local flow using an installed `harmony-proxy` binary (from `README.md`):

```bash path=null start=null
# From repository root
cd pipelines/basic-echo

# Start Harmony with this example's configuration
harmony-proxy --config config.toml

# In another shell, exercise the endpoint
curl http://127.0.0.1:8080/echo
```

Each pipeline under `pipelines/*` has its own `README.md` with example-specific commands and endpoints; prefer those per-pipeline docs when making changes or debugging.

### Docker mesh networking test

The Docker-based mesh example lives under `docker/`. The exact directory name and commands are documented in `docker/mesh/README.md`; follow that file when running or modifying the mesh example.

Key operations (see that README for the authoritative commands):
- Bring up the mesh test stack with Docker Compose (builds Harmony from source or uses a local binary depending on configuration)
- Send HTTP requests through the entry node to verify mesh routing
- Use `docker compose logs` and the admin endpoints to debug node and backend behaviour

## Architecture and key components

### Pipeline directories and catalog metadata

Each example pipeline lives under `pipelines/<pipeline-id>/` and typically contains:
- A top-level `config.toml` describing networks, middleware, backends, and targets for that example
- Nested `pipelines/**/*.toml` files with individual Harmony pipeline definitions
- Optional `transforms/**/*.json` files with JOLT specs used by that example
- A `README.md` explaining the scenario, endpoints, and how to run it

The top-level `pipelines.json` is a catalog of all examples. It is used by the PHP `TemplateLoader` and by consumers of the npm package:
- Keys are pipeline IDs (e.g. `basic-echo`, `fhir`, `dicom-scp`)
- Values include fields like `name`, `shortDescription`, `description`, `tags`, `file`, `type`, and optional `categories`/`directory`

`transforms.json` serves the same role for shared JOLT transforms under `transforms/`.

When adding or modifying examples, keep these relationships in mind:
- Every new example directory under `pipelines/` should have a corresponding entry in `pipelines.json`
- Tests assume certain well-known pipeline IDs exist (`basic-echo`, `fhir`, `dicom-scp`)
- Any new shared JOLT transforms in `transforms/` should be reflected in `transforms.json` if you want them discoverable via the loader and npm exports

### PHP TemplateLoader

The only PHP source file, `src/TemplateLoader.php`, provides a small API for loading the catalogs:
- `loadPipelines(?string $pipelines_root = null, ?string $pipelines_file = null): array`
  - Defaults to reading `pipelines.json` from the project root
- `loadTransforms(?string $transforms_root = null, ?string $transforms_file = null): array`
  - Defaults to reading `transforms.json` from the project root

Internally both call a private `loadJson(string $path): array` helper that:
- Validates that the file exists and is readable
- Uses `json_decode(..., JSON_THROW_ON_ERROR)` to parse
- Enforces that the decoded value is an array, otherwise throws a `RuntimeException`

If you change the shape or location of the catalog JSON files, update both the loader defaults and the tests to keep behaviour consistent.

### PHPUnit tests

`tests/TemplateLoaderTest.php` covers both the happy path and failure modes of `TemplateLoader`:
- Verifies that `loadPipelines()` returns a non-empty array and contains key examples (`basic-echo`, `fhir`, `dicom-scp`)
- Asserts that each pipeline entry has required fields and correct types (e.g. `tags` is always an array)
- Exercises `loadTransforms()` but allows for the file to be missing (it treats "file not found" as an expected runtime failure mode)
- Uses reflection to access `loadJson()` and tests error behaviour:
  - Missing files throw `RuntimeException` with a "File not found:" message
  - Invalid JSON produces a `RuntimeException` mentioning JSON decode failure
  - Non-array JSON values cause a `RuntimeException` with an "Expected array" message

When extending functionality, mirror this style: add tests that validate both structure and error-handling for any new metadata files or loader entry points.

### Node/TypeScript consumers (npm package)

`package.json` exposes the examples as an npm package `@aurabx/harmony-examples`:
- `main`, `module`, and `types` point to `index.cjs`, `index.mjs`, and `index.d.ts`
- The `exports` map exposes:
  - The main entry (with types, ESM, and CJS builds)
  - `./pipelines.json`, `./transforms.json`, `./workload-diagrams.json`
  - `./pipelines/*` and `./transforms/*` so callers can resolve individual assets

Consumers typically:
- Import the package and inspect the `pipelines`/`transforms` catalogs
- Resolve paths to specific example configs or transforms from within the installed package

Be aware that JavaScript/TypeScript consumers may rely on the stability of the export map and the catalog JSON shape; avoid breaking changes without coordinating versioning.

### Harmony configuration patterns

`README.md` documents common Harmony configuration patterns used across examples, including:
- Network listeners: HTTP, DICOM, and management APIs defined under `[network.*]`
- Middleware chains: ordered lists of middleware names attached to a pipeline
- Backend and target definitions: `backends.*` and `targets.*` sections linking pipelines to upstream services

These patterns are shared across many example `config.toml` files; keep new configurations consistent with them to make examples easier to understand and reuse.

### Docker mesh networking example

The mesh example under `docker/` demonstrates a small multi-node Harmony deployment:
- **Node B (entry point)** accepts external HTTP traffic on one port and forwards it into the mesh using JWT-authenticated egress
- **Node A (backend node)** receives mesh ingress traffic, validates JWTs, and forwards requests to a simple Python HTTP backend
- **Python backend** echoes request details in JSON, confirming that traffic has traversed the mesh path

The Docker Compose setup also includes:
- Admin/management ports for each node (health checks, diagnostics)
- A shared JWT secret for mesh authentication (meant to be changed outside of local testing)

When editing or extending this example, preserve the separation of concerns between:
- Entry nodes that expose public HTTP endpoints and speak mesh egress
- Internal nodes that terminate mesh ingress and forward to backends

## Working with and extending examples

When adding or modifying pipelines/transforms:
- Follow existing directory and naming patterns under `pipelines/` and `transforms/`
- Update `pipelines.json` (and `transforms.json` where relevant) so the catalogs stay in sync
- Ensure `TemplateLoader` and its tests continue to pass and validate any new required fields
- Keep per-example `README.md` files accurate with endpoints, ports, and how-to-run instructions so they remain trustworthy for both humans and tools.
