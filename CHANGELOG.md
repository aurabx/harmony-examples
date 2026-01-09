# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.9.0]
### Changed
- **BREAKING**: Migrated all 25 example configurations from legacy `[runbeam]` section to new `[provider.*]` pattern
- All examples now include `primary_provider = "local"` setting in `[proxy]` section
- All examples now include `[provider.runbeam]` section for consistency
- Updated mesh examples (data-mesh, docker/mesh) to use new provider configuration

### Removed
- Deprecated `[runbeam]` section from all example configurations

## [0.8.1]
### Added
- Santa's Workshop example pipeline with video deployment guide
- New TypeScript type fields: `since`, `runbeam`, `deployVideo`

## [0.8.0]
### Added
- Webhook example pipeline and middleware feature for event-driven integration patterns

### Changed
- Updated pipeline example documentation and readme files

## [0.7.0]
### Added
- `directory` field in `pipelines.json` to point consumers at the example folder containing a pipeline template.

### Fixed
- Corrected the `file` path for `au-erequesting-fhir-to-http`.

### Changed
- TypeScript types updated to reflect the current pipeline catalog schema.

## [0.4.0]
### Added
- AU eRequesting example pipelines (FHIR-to-HTTP and HTTP-to-FHIR)
- npm package distribution with TypeScript definitions
- CommonJS module entry point (`index.cjs`)

### Changed
- Examples now call `harmony` directly instead of via `cargo`
- Updated pipeline configurations

## [0.3.0]
### Changed
- Updated example pipeline configurations

### Fixed
- PHPUnit cache configuration

## [0.2.0]
### Added
- C-STORE filesystem example from Harmony
- Demo scripts for basic echo and DICOM backend
- Content-types example to JSON catalog

### Changed
- `TemplateLoader` now supports different loading locations
- Reorganised `pipelines.json` structure
- Updated HTTP-HTTP example

### Fixed
- HTTP internal example configuration

## [0.1.0]
Initial port from the Runbeam projet

### Added
- Initial pipeline examples for healthcare data integration
- Basic echo pipeline for testing
- HTTP proxy examples (external and internal)
- FHIR endpoint with authentication
- FHIR to DICOM integration (ImagingStudy)
- DICOM SCP endpoint (C-ECHO, C-FIND, C-GET, C-MOVE)
- DICOM backend for HTTP to DICOM translation
- DICOMweb to DIMSE bridge
- JMIX packaging and delivery pipeline
- Transform middleware examples with JOLT
- SOAP to JSON conversion pipeline
- Multi-content-type support example (JSON, XML, CSV, multipart, binary)
- Comprehensive smoketest pipeline
- `TemplateLoader` PHP class for loading pipeline/transform metadata
- PHPUnit test suite for template loading
- Pipeline catalog (`pipelines.json`)
- Transform catalog (`transforms.json`)
- Composer configuration with autoloading
- PHPUnit 12 configuration

### Changed
- Category labels normalized to lowercase in `pipelines.json`

### Fixed
- Trailing comma in `pipelines.json` causing JSON parsing errors
- `TemplateLoader` paths to load from project root instead of `src/`
- JSON exception handling to wrap `JsonException` in `RuntimeException`