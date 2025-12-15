# DICOMweb Gateway Pipeline

## What is this pipeline?

This pipeline demonstrates a DICOMweb gateway that translates RESTful DICOMweb queries (QIDO-RS, WADO-RS) into DIMSE operations and forwards them to a DICOM PACS system. This example is ideal for:

- Providing RESTful access to DICOM PACS systems
- Modernizing legacy DIMSE-based PACS with a web API
- Standards-compliant DICOMweb implementation (QIDO-RS, WADO-RS)
- Bridging healthcare IT systems with web-based clients

## How to add this pipeline to your Harmony instance

To use this pipeline in your Harmony deployment, follow the [Adding Pipelines guide](https://docs.runbeam.io/harmony/guides/adding-pipelines):

1. Create a new TOML file in your `pipelines/` directory
2. Copy the pipeline configuration from this example
3. Customize the DICOM backend target (host, port, AE titles)
4. Harmony automatically discovers and loads the pipeline

Quick example:
```toml
# pipelines/my-dicomweb.toml
[pipelines.dicomweb_gateway]
description = "DICOMweb gateway to PACS"
networks = ["default"]
endpoints = ["dicomweb_endpoint"]
middleware = ["dicomweb_processor"]
backends = ["pacs_backend"]

[backends.pacs_backend]
service = "dicom_scu"
target_ref = "my_pacs"

[targets.my_pacs]
connection.host = "pacs.hospital.local"
connection.port = 104
connection.protocol = "dicom"
```

## About Harmony and Runbeam

**Harmony** is a high-performance API gateway and proxy runtime built in Rust, designed for healthcare data integration, protocol translation, and advanced middleware processing.

**Runbeam** provides the cloud platform and ecosystem for deploying and managing Harmony instances.

- [Harmony Documentation](https://docs.runbeam.io/harmony)
- [Runbeam Cloud](https://runbeam.io)
- [GitHub Repository](https://github.com/runbeam/harmony)

---

## Configuration Overview

### Network
- **Bind Address**: 0.0.0.0 (all interfaces)
- **Port**: 8081
- **Endpoints**: DICOMweb service endpoints

### Service Support

This example includes configuration for:
- **dicom_scu**: DICOM Service Class User (client) for DIMSE operations
- **dicomweb**: DICOMweb middleware for REST-to-DIMSE translation

### Backend Target

The pipeline connects to a DICOM PACS system. Update the target configuration:

```toml
[targets.orthanc]
connection.host = "pacs.example.com"
connection.port = 104
connection.protocol = "dicom"
timeout_secs = 60
```

### Supported Operations

- **QIDO-RS**: Query for DICOM studies, series, and instances
- **WADO-RS**: Retrieve DICOM instances

## Example Requests

```bash
# Query for studies by patient ID
curl "http://localhost:8081/dicom/studies?PatientID=PID123" \
  -H "Accept: application/dicom+json"

# Query for studies by date range
curl "http://localhost:8081/dicom/studies?StudyDate=20250101-20251231" \
  -H "Accept: application/dicom+json"

# Query for specific series within a study
curl "http://localhost:8081/dicom/studies/1.2.3.4.5/series" \
  -H "Accept: application/dicom+json"

# Retrieve all instances of a series
curl "http://localhost:8081/dicom/studies/1.2.3.4.5/series/1.2.3.4.5.1/instances" \
  -H "Accept: application/dicom+json"
```

## DICOM Concepts

### QIDO-RS (Query/Retrieve - Information Objects)
RESTful query interface for searching DICOM studies, series, and instances. Query parameters are mapped to DICOM attributes for C-FIND operations.

### WADO-RS (Web Access to DICOM Objects)
RESTful retrieve interface for fetching DICOM instances. Harmony translates REST requests into DIMSE C-GET/C-MOVE operations.

### DIMSE Operations
Harmony internally uses DIMSE (DICOM Message Service Element) operations:
- **C-FIND**: Searches for DICOM objects
- **C-GET**: Retrieves DICOM objects from PACS
- **C-MOVE**: Moves DICOM objects to a destination

## Files Structure

```
dicomweb/
├── config.toml                    # Main proxy configuration
├── pipelines/
│   └── dicomweb.toml              # Pipeline definition
└── README.md                      # This file
```

## Troubleshooting

### Connection to PACS Fails
- Verify PACS host and port are correct
- Check network connectivity to PACS system
- Verify DICOM protocol is accessible (not just HTTP)
- Check PACS firewall rules allow connections on port 104

### No Results from Queries
- Verify query parameters match DICOM attribute names
- Ensure PACS contains data matching query criteria
- Check logs for DIMSE operation errors
- Test with simpler queries first (e.g., no filter parameters)

### DICOMweb Format Issues
- Verify `Accept` header is set to `application/dicom+json`
- Check that DICOMweb middleware is properly configured
- Ensure PACS supports the requested DICOM operations

## Security Considerations

- Add authentication middleware to protect DICOM access
- Configure network policies to restrict DICOM access to trusted sources
- Use TLS for encrypted connections (if supported by PACS)
- Implement audit logging for DICOM queries and retrievals
- Validate and sanitize all query parameters

## References

- [DICOMweb Standard (QIDO-RS, WADO-RS)](https://www.dicomstandard.org/)
- [DICOM Standard](https://www.dicomstandard.org/)
- [Harmony Documentation](https://docs.runbeam.io/harmony)

## Next Steps

- Configure authentication for DICOM access
- Set up monitoring and alerting for PACS queries
- Implement audit logging for compliance
- Test with your actual PACS system
- Deploy to production with appropriate security controls
