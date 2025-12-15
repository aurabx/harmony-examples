# DICOM C-STORE Filesystem Example

## What is this pipeline?

This example demonstrates how to configure Harmony to receive DICOM files via the C-STORE protocol and store them using the local filesystem backend. This example is ideal for:

- Receiving DICOM files from DICOM modalities
- Storing DICOM studies on local filesystems
- Building DICOM archives
- PACS integration

## How to add this pipeline to your Harmony instance

To use this pipeline in your Harmony deployment, follow the [Adding Pipelines guide](https://docs.runbeam.io/harmony/guides/adding-pipelines):

1. Create a new TOML file in your `pipelines/` directory
2. Copy the pipeline configuration from this example
3. Configure storage backend and DICOM SCP settings
4. Harmony automatically discovers and loads the pipeline

## About Harmony and Runbeam

**Harmony** is a high-performance API gateway and proxy runtime built in Rust, designed for healthcare data integration, protocol translation, and advanced middleware processing.

**Runbeam** provides the cloud platform and ecosystem for deploying and managing Harmony instances.

- [Harmony Documentation](https://docs.runbeam.io/harmony)
- [Runbeam Cloud](https://runbeam.io)
- [GitHub Repository](https://github.com/runbeam/harmony)

---

This example demonstrates how to configure Harmony to receive DICOM files via the C-STORE protocol and store them using the local filesystem backend.

## Structure

```
cstore-filesystem/
├── config.toml          # Main configuration (storage, network)
├── pipelines/
│   └── main.toml       # Pipeline definition (endpoints, logic)
└── README.md           # This file
```

## Configuration

The configuration sets up:
1. A **Filesystem Storage** backend rooted at `./data`.
2. A **DICOM SCP** endpoint on port 11112 that accepts C-STORE.
3. A **Storage Backend** service that archives the received files to `./data/archive`.

## Usage

1. Start the server from the project root:
   ```bash
   cargo run -- --config examples/cstore-filesystem/config.toml
   ```

2. Send a DICOM file using `storescu` (from DCMTK):
   ```bash
   storescu -v -aet TEST_SCU -aec HARMONY_SCP localhost 11112 path/to/test.dcm
   ```

3. Verify the file was stored:
   ```bash
   ls -R examples/cstore-filesystem/data/dimse/
   ```

## How it Works

When a C-STORE request is received:
1. The file is streamed to disk at `{storage.path}/dimse/<uuid>.dcm` (temporary holding).
2. The `dicom_ingest` pipeline is executed with the file path in the payload.
3. The `filesystem_storage` backend receives the request and copies/moves the file to `./data/archive` (or simply acknowledges it if configured as such).
4. A success response is returned to the sender.
