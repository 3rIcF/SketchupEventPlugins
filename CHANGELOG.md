# Changelog

## Unreleased
- Added configurable `CHUNK_SIZE` (default 3000) to process scans in slices.
- Async scanning now reports progress via `EA.scanProgress` events and supports cancellation.
