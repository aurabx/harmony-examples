# DICOM to AI Gateway

This example demonstrates how to create a bridge between traditional PACS systems and modern cloud-based AI processing services. The pipeline receives DICOM images via the standard C-STORE protocol and transforms them into JSON requests suitable for AI/ML cloud services.

## Use Case

Medical imaging departments often need to integrate modern AI analysis capabilities with existing PACS infrastructure. This example shows how to:

- Receive DICOM images from medical modalities or PACS systems
- Extract relevant metadata for AI processing
- Transform DICOM data into JSON format
- Send structured requests to cloud-based AI services
- Maintain compatibility with existing DICOM workflows

## Architecture

```
PACS/Modality → DICOM C-STORE → Harmony → Metadata Extraction → JOLT Transform → JSON → Cloud AI Service
```

## Configuration

### DICOM Listener (SCP)
- **AET**: AI_GATEWAY
- **Port**: 11113
- **Supported Operations**: C-STORE (image reception)
- **Protocol**: DICOM over TCP

### Metadata Extraction
The pipeline uses Harmony's middleware chain to process DICOM data:
- `dicom_flatten` middleware converts DICOM binary format to JSON-serializable structure
- `transform` middleware applies JOLT specification from `transforms/dicom_to_ai.json`
- Exposes DICOM tags with standard (group,element) format like "(0010,0020)"
- Makes complete DICOM dataset available for JSON transformation

### JSON Transformation
Using JOLT specifications, the DICOM metadata is restructured into a JSON format optimized for AI processing:
```json
{
  "patient": {
    "id": "PATIENT123",
    "name": "DOE^JOHN"
  },
  "study": {
    "uid": "1.2.3.4.5",
    "date": "20240115",
    "description": "CT CHEST WO CONTRAST"
  },
  "imaging": {
    "modality": "CT",
    "bodyPart": "CHEST"
  },
  "processing": {
    "requestType": "DICOM_ANALYSIS",
    "priority": "normal",
    "timestamp": "2024-01-15T10:30:00Z",
    "source": "pacs_gateway"
  }
}
```

## Setup

1. **Configure DICOM Source**: Set your PACS or modality to send studies to AET `AI_GATEWAY` on port `11113`

2. **Update AI Service URL**: Modify `config.toml` to point to your actual AI service endpoint:
   ```toml
   [targets.ai_service]
   connection.host = "your-ai-service.com"
   connection.port = 443
   connection.protocol = "https"
   ```

3. **Start Harmony**: 
   ```bash
   harmony start -c config.toml
   ```

4. **Test Integration**: Send a DICOM study to the gateway and monitor the logs:
   ```bash
   tail -f ./tmp/harmony_dicom_ai.log
   ```

## Use Cases

### Medical Image Analysis
- Automatically route radiology studies to AI services for preliminary analysis
- Enable real-time quality control and anomaly detection
- Support clinical decision support systems

### Research and Development
- Extract datasets for machine learning model training
- Enable retrospective analysis of large imaging archives
- Support clinical research workflows

### Enterprise Integration
- Bridge legacy DICOM infrastructure with modern cloud services
- Enable hybrid cloud/on-premises deployment models
- Maintain regulatory compliance while leveraging AI capabilities

## Customization

### Adding New Metadata Fields
To include additional DICOM tags in the JSON output, update the JOLT transformation spec in `transforms/dicom_to_ai.json`:
```json
{
  "operation": "shift",
  "spec": {
    "(XXXX,YYYY)": "target.path"  // DICOM tag (group,element) format
  }
}
```

### Modifying JSON Structure
Update the JOLT specification to match your AI service's expected input format.

### Adding Authentication
Include API keys or authentication headers in the HTTP backend configuration:
```toml
[backends.ai_cloud_api.options.headers]
Authorization = "Bearer your-api-key"
```

## Monitoring

The pipeline provides detailed logging for:
- Incoming DICOM connections
- Metadata extraction results
- JSON transformation output
- HTTP backend responses

Monitor the log file at `./tmp/harmony_dicom_ai.log` for troubleshooting and performance analysis.

## Security Considerations

- Ensure proper firewall configuration for DICOM port 11113
- Use TLS/HTTPS for all external communications
- Implement proper authentication for AI service access
- Consider data retention policies for extracted metadata
- Validate that all PHI handling complies with relevant regulations (HIPAA, GDPR, etc.)

## Troubleshooting

### Common Issues

1. **DICOM Connection Failed**
   - Verify network connectivity to the Harmony server
   - Check that port 11113 is open and not blocked by firewall
   - Confirm AET configuration matches between sender and receiver

2. **Metadata Extraction Errors**
   - Ensure DICOM files contain the expected tags
   - Check log files for specific tag extraction failures
   - Validate DICOM file format compliance

3. **AI Service Connection Issues**
   - Verify AI service endpoint connectivity
   - Check authentication credentials
   - Confirm JSON format matches service expectations

### Log Analysis
Use the debug log level to trace the complete flow:
```bash
harmony start -c config.toml --log-level debug
```

## Related Examples

- [DICOM Backend](../dicom-backend/) - HTTP to DICOM conversion
- [DICOM Receiver](../dicom-scp/) - Basic DICOM SCP setup
- [Data Transformation](../transform/) - Advanced JOLT transformations
- [HTTP with Middleware](../http-with-middleware/) - Middleware chain examples