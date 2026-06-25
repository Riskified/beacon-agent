# Changelog

## 1.0.0 — 2026-05-27

Initial release.

- Supports Flask, PHP, Node/Express, React + Vite
- Session variable discovery and recommendation
- Shared-layout-aware injection (injects once, not per-page)
- Stale/broken beacon detection and removal
- Layer 1: curl smoke checks (7 assertions per page)
- Layer 2: generated test suite (pytest / PHPUnit / Jest)
- Layer 3: generated Playwright behavioral tests
- `beacon_audit.json` audit log
