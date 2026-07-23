[![ubuntu](https://github.com/sinisa-susnjar/prometheus-d/actions/workflows/ubuntu.yml/badge.svg)](https://github.com/sinisa-susnjar/prometheus-d/actions/workflows/ubuntu.yml) [![macos](https://github.com/sinisa-susnjar/prometheus-d/actions/workflows/macos.yml/badge.svg)](https://github.com/sinisa-susnjar/prometheus-d/actions/workflows/macos.yml) [![windows](https://github.com/sinisa-susnjar/prometheus-d/actions/workflows/windows.yml/badge.svg)](https://github.com/sinisa-susnjar/prometheus-d/actions/workflows/windows.yml) [![codecov](https://codecov.io/github/sinisa-susnjar/prometheus-d/graph/badge.svg?token=ETV1VUVFMU)](https://codecov.io/github/sinisa-susnjar/prometheus-d)

# Prometheus D

Prometheus metrics library for the [D programming language](https://dlang.org/).
Zero external dependencies — only the D standard library and runtime.

See [here](./comparison.md) for a comparison with other D Prometheus implementations.

## Example

```d
import prometheus;
import core.thread;

void main()
{
    auto reg = new Registry();

    // Counter — monotonically increasing value
    auto requests = reg.add(new Counter("http_requests_total", "Total HTTP requests"));
    requests(["method": "GET", "status": "200"]).inc();

    // Gauge — value that can go up and down
    auto cpu = reg.add(new Gauge("cpu_usage_percent", "CPU usage"));
    cpu.set(42.5);

    // Histogram — observations bucketed by configurable thresholds
    auto latency = reg.add(new Histogram("request_latency_seconds",
        "Request latency", [0.1, 0.5, 1.0, 2.0, 5.0]));
    latency(["endpoint": "/api"]).observe(0.34);

    // Summary — observations with streaming quantile estimates
    auto summary = reg.add(new Summary("response_size_bytes",
        "Response size", [0.5, 0.9, 0.99]));
    summary.observe(1024);

    // Start HTTP server (blocking — run in its own thread)
    new Thread({ serveMetrics(reg, 8080); }).start();

    // Update metrics in your application loop
    while (true) {
        requests.inc();
        Thread.sleep(1.seconds);
    }
}
```

Run the included sample:

```sh
cd examples/sample && dub run
curl http://localhost:8081/metrics
```

## Install

Add to your `dub.json`:

```json
{
    "dependencies": {
        "prometheus-d": "~>0.0.1"
    }
}
```

Or use the git dependency:

```json
{
    "dependencies": {
        "prometheus-d": { "path": "path/to/prometheus-d" }
    }
}
```

## Build & Test

```sh
dub build -c lib          # static library
dub build -c shared       # dynamic library
dub build -c asan         # static library with AddressSanitizer
dub test                  # run all unit tests
dub test --coverage       # run tests with coverage (.lst files)
```

## Implemented functionality

### Metric types

| Type | Prometheus equivalent | Key operations |
|------|----------------------|----------------|
| `Counter` | counter | `inc()`, `set()`, `get()` |
| `Gauge` | gauge | `inc()`, `dec()`, `set()`, `get()` |
| `Histogram` | histogram | `observe(v)` with configurable cumulative buckets |
| `Summary` | summary | `observe(v)` with configurable quantiles (reservoir sampling) |

### Labels

All metric types support label-based dimensionality via `opCall`:

```d
auto c = reg.add(new Counter("requests", "Help text", ["app": "myapp"]));
c(["host": "server1", "method": "GET"]).inc();  // per-label-set value
c.inc();  // uses default labels ["app": "myapp"]
```

Labels are `immutable string[string]` associative arrays. Default labels passed to the constructor are merged into all rendered output automatically.

### Registry

- **`add(metric)`** — register a metric (duplicate names are warned and skipped)
- **`counter(name)` / `gauge(name)`** — typed lookup by name
- **`get!(T)(name)`** — template-based typed lookup for any metric type
- **`renderAll()`** — produces full Prometheus text-format output

### HTTP server

`serveMetrics(registry, port, host)` starts a blocking HTTP server:

| Endpoint | Response |
|----------|----------|
| `GET /metrics` | 200 — Prometheus text format with all registered metrics |
| `GET /` | 200 — plain text server info |
| anything else | 404 |

### Built-in GC metrics

The server automatically exposes D runtime GC statistics as gauges:

- `gc_free_size_bytes` / `gc_used_size_bytes` — heap memory
- `gc_num_collections` / `gc_total_collection_time` / `gc_max_collection_time` — collection stats
- `gc_total_pause_time` / `gc_max_pause_time` — pause time stats in microseconds

Updated on every `/metrics` scrape via `GC.stats()` and `GC.profileStats()`.

### Thread safety

Metrics are safe for concurrent use:

- **Hot path** (inc, set, observe): `core.atomic` operations on `shared` fields — `@nogc nothrow`, no heap allocation
- **Container access** (label creation, rendering): `synchronized(this)` mutual exclusion
- Registry `add()`, `get()`, and `renderAll()` are all synchronized

### Prometheus format compliance

Output follows the [Prometheus exposition format](https://prometheus.io/docs/instrumenting/exposition_formats/):

```
# HELP http_requests_total Total HTTP requests
# TYPE http_requests_total counter
http_requests_total{method="GET",status="200"} 42

# HELP request_latency_seconds Request latency
# TYPE request_latency_seconds histogram
request_latency_seconds_bucket{le="0.1"} 0
request_latency_seconds_bucket{le="0.5"} 3
request_latency_seconds_bucket{le="1"} 7
request_latency_seconds_bucket{le="+Inf"} 7
request_latency_seconds_sum 1.23
request_latency_seconds_count 7
```

## TODO

- [ ] `@nogc` rendering path (currently `format()` allocates)
- [ ] Metric removal / unregister from Registry
- [ ] Configurable GC metrics (opt-in/opt-out per gauge)
- [ ] Support for Prometheus protobuf format
- [ ] Push-gateway client
- [ ] Exemplar support
- [ ] Native histogram support

## History

- **v0.0.2** — Added @safe, dip1000, faster formatting using appender!string
- **v0.0.1** — First release. Counter, Gauge, Histogram, Summary. Labels. HTTP server. GC stats.
