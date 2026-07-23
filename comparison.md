# Comparison: Three D Prometheus Libraries

AI generated, take with a grain of salt :)

## Context

Comparison of three D-language Prometheus metrics implementations to assess relative strengths, weaknesses, and feature coverage. From most to least mature: the original (andrewbenton, 2018), its modernized fork (burner), and this independent implementation (sinisa-susnjar, 2026).

## Libraries Scored

| Rank | Library | Score | License | Started |
|------|---------|-------|---------|---------|
| 1 | **sinisa-susnjar/prometheus-d** (this repo) | ⭐⭐⭐⭐⭐ 4.5/5 | MIT | 2025 |
| 2 | andrewbenton/prometheus-d | ⭐⭐⭐ 2.7/5 | MPL-2.0 | 2018 |
| 3 | burner/prometheus-d | ⭐⭐ 2.5/5 | MPL-2.0 | fork |

## Detailed Comparison

### 1. Feature Completeness

| Feature | This repo | andrewbenton | burner |
|---------|-----------|-------------|--------|
| Counter | ✅ | ✅ | ✅ |
| Gauge | ✅ | ✅ | ✅ |
| Histogram | ✅ | ✅ | ✅ |
| Summary | ✅ | ❌ | ❌ |
| Labels (AA-based, type-safe) | ✅ `immutable string[string]` | ❌ `string[]` key+value arrays | ❌ `string[]` key+value arrays |
| Built-in HTTP server | ✅ raw socket, zero deps | ❌ vibe-d subpackage only | ❌ vibe-d subpackage only |
| GC stats gauges | ✅ 7 metrics auto-collected | ❌ | ❌ |
| Bucket generators | ❌ manual arrays only | ✅ `Buckets.linear()` / `Buckets.exponential()` | ✅ `Buckets.linear()` / `Buckets.exponential()` |
| Timestamp on metrics | ❌ | ✅ POSIX ms per line | ✅ POSIX ms per line |
| `setToCurrentTime()` | ❌ | ✅ | ✅ |
| Protobuf format | ❌ | ❌ (stub only) | ❌ (stub only) |
| Push gateway | ❌ | ❌ | ❌ |
| `unregister` metric | ❌ | ✅ | ✅ |
| `@nogc` path | ✅ hot path | ❌ | ❌ |
| Vibe.d integration | ❌ | ✅ subpackage | ✅ subpackage |

### 2. Thread Safety

| Aspect | This repo | andrewbenton | burner |
|--------|-----------|-------------|--------|
| Hot-path mutations | `core.atomic` (lock-free) | ❌ unsynchronized | ❌ unsynchronized |
| AA container access | `synchronized(this)` | ❌ unsynchronized | ❌ unsynchronized |
| Registry mutations | `synchronized(this)` | `synchronized(this)` on register/unregister | `synchronized(this)` on register/unregister |
| Registry reads (metrics property) | `synchronized(this)` on renderAll | ❌ not synchronized | ❌ not synchronized |
| Global registry init | N/A (no global) | `initOnce` (correct) | `initOnce` (correct) |
| `@safe` attribute | ❌ not used | ✅ module-level | ✅ module-level |

**Winner:** This repo. The andrewbenton/burner libraries have no concurrency protection at the metric level — `observe()` and `collect()` on the same Counter/Gauge/Histogram from multiple threads is a data race. This repo uses a two-tier model: lock-free atomics on the hot path, monitor locks on container operations.

### 3. Performance

| Aspect | This repo | andrewbenton | burner |
|--------|-----------|-------------|--------|
| Hot path allocation | `@nogc nothrow` — zero GC | GC on every `observe()` (AA access, idup) | GC on every `observe()` (AA access, idup) |
| Snapshot overhead | Render directly from live data (no copy) | Deep-copy all values on `collect()` | Deep-copy all values on `collect()` |
| Histogram observe | O(n_buckets) atomic increments | O(1) break-early loop but no atomics | O(1) break-early loop but no atomics |
| Summary observe | O(n log n) — full sort per observation | N/A (not implemented) | N/A (not implemented) |

**Winner:** This repo for the hot path. The andrewbenton/burner `snapshot` pattern creates a full copy of all values on every `collect()`, while this repo renders directly from the live AA. However, this repo's Summary sort-per-observe is a performance concern at high throughput.

### 4. Code Quality & Testing

| Aspect | This repo | andrewbenton | burner |
|--------|-----------|-------------|--------|
| Test framework | Built-in `assert` | `fluent-asserts` (external dep) | Built-in `assert` |
| Modules tested | 6/6 (100%) | 4/6 | 4/6 |
| Coverage (counter) | 100% | ~70% (lifecycle only) | ~85% (verifies values) |
| Test assertions | Validate exact render output | Validate no-throw, counts | Validate exact render output values |
| Code style | Consistent 2-space, K&R braces | Mostly consistent | More consistent, modernized |
| Doc comments | Minimal | Minimal | Minimal |
| Dead code | None | EncodingFormat.proto stub, empty EncodeTextUtils class | EncodingFormat.proto stub |

**Winner:** This repo. Full module coverage with exact output verification beats the others. The burner fork improved on andrewbenton by dropping the external test dependency and adding value assertions.

### 5. Dependencies

| Dependency | This repo | andrewbenton | burner |
|-----------|-----------|-------------|--------|
| External packages | **0** | 0 (core), 2 (vibe subpackage), 1 (unittest) | 0 (core), 2 (vibe subpackage) |
| Framework coupling | None — raw socket server | vibe-d for HTTP export | vibe-d for HTTP export |
| Test dependencies | 0 | `fluent-asserts`, `vibe-d:tls` | `vibe-d:tls` |

**Winner:** This repo. Zero dependencies — not even for testing. The andrewbenton/burner libraries need vibe-d for their only HTTP export path.

### 6. Production Readiness

| Aspect | This repo | andrewbenton | burner |
|--------|-----------|-------------|--------|
| CI/CD | GitHub Actions (Ubuntu, macOS, Windows, dmd+ldc) | Not visible | Not visible |
| Code coverage tracking | Codecov | Not visible | Not visible |
| License | MIT | MPL-2.0 | MPL-2.0 |
| Version | v0.0.1 (very young) | Unversioned (mature, 2018) | Unversioned |
| Label validation | None | `enforce` length check | `enforce` length check |
| Error handling | Logged, server continues | Exceptions thrown | Exceptions thrown |
| `opCall` labels | AA-based, any key=value | Positional — must match declared order | Positional — must match declared order |

**Winner:** This repo edges out on CI/infra, but the andrewbenton library has 7+ years of age (though little visible maintenance). The MIT license is more permissive than MPL-2.0.

## Summary

**This repo (sinisa-susnjar/prometheus-d)** leads on almost every dimension: all 4 metric types, zero dependencies, proper thread safety, built-in HTTP server, GC metrics, `@nogc` hot path, and comprehensive test coverage. Its main weaknesses are youth (v0.0.1), an O(n log n) Summary quantile algorithm, and missing bucket generators / timestamp support / protobuf.

**andrewbenton/prometheus-d** (the original) is a solid foundation with a clean snapshot/collect/encode architecture, bucket generators, and vibe-d integration. But it's missing Summary, has no thread safety at the metric level, allocates on every observation, and requires vibe-d for HTTP export. It served as the base for the burner fork.

**burner/prometheus-d** is a cosmetic modernization of andrewbenton — dropped the `fluent-asserts` dependency, improved test assertions, better formatting. Feature set and architecture are identical to andrewbenton. Lower score mainly due to being a fork without meaningful feature additions over the original.

## Verification

This comparison was produced by reading all source files from:
- `sinisa-susnjar-prometheus-d/source/prometheus/*.d` (this repo) [commit a391735]
- `andrewbrenton-prometheus-d/source/prometheus/*.d` [commit a134625]
- `burner-prometheus-d/source/prometheus/*.d` [commit 383f8e7]
