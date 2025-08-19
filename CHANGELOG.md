# Changelog

## 2.3.4 - 2025-08-16
- Fix timer handling using `UI.stop_timer` to avoid `NilClass` errors.

## 2.3.3 - 2025-08-16
- Avoid array allocations during entity traversal for better performance.

## 2.3.2 - 2025-08-16
- Prevent scanner cycles during traversal.
- Improve CI and test coverage.
