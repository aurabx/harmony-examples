# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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