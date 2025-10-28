module prometheus.registry;

import core.atomic;
import std.format;
import std.logger.core;

import prometheus.metric;
import prometheus.counter;
import prometheus.gauge;

/// --- Registry ---
class Registry {
private:
  Counter[string] _counters;
  Gauge[string] _gauges;
  Metric[string] _metricsByName;

public:
  this()
  {
  }

  Counter counter(string name)
  {
    synchronized (this) {
      if (name in _counters)
        return _counters[name];
      return null;
    }
  }

  Gauge gauge(string name)
  {
    synchronized (this) {
      if (name in _gauges)
        return _gauges[name];
      return null;
    }
  }

  T add(T)(T m) if (is(T : Metric))
  {
    synchronized (this) {
      // Check for duplicate metric names
      if (m.name() in _metricsByName) {
        auto existing = _metricsByName[m.name()];
        warningf("registry: metric with name '%s' already registered, skipping duplicate",
          m.name());
        return m;
      }
      _metricsByName[m.name()] = m;

      // Index metric by name for duplicate detection
      static if (is(T : Counter)) {
        _counters[m.name()] = m;
      }
      static if (is(T : Gauge)) {
        _gauges[m.name()] = m;
      }
    }
    return m;
  }

  T get(T)(string name) if (is(T : Metric))
  {
    synchronized (this) {
      static if (is(T : Counter)) {
        if (name in _counters)
          return cast(T) _counters[name];
      }
      static if (is(T : Gauge)) {
        if (name in _gauges)
          return cast(T) _gauges[name];
      }
      // Generic fallback for any Metric subtype
      if (name in _metricsByName) {
        auto m = _metricsByName[name];
        auto typed = cast(T) m;
        if (typed !is null)
          return typed;
      }
    }
    return null;
  }

  string renderAll()
  {
    synchronized (this) {
      string result;
      foreach (m; _metricsByName) {
        result ~= m.render() ~ "\n";
      }
      return result;
    }
  }
}

// test registry add, lookup, duplicate detection, and renderAll
unittest {
  import std.string : indexOf;
  import prometheus.histogram;
  import prometheus.summary;
  import prometheus.gauge;

  // --- empty registry ---
  {
    auto reg = new Registry();
    auto result = reg.renderAll();
    assert(result == "", "empty registry should render empty string, got: " ~ result);
  }

  // --- add and renderAll ---
  auto reg = new Registry();
  reg.add(new Counter("http_requests", "Total HTTP requests"));
  reg.add(new Gauge("cpu_temp", "CPU temperature"));
  reg.add(new Histogram("latency", "Request latency", [0.1, 0.5, 1.0]));
  reg.add(new Summary("latency_summary", "Latency summary", [0.5, 0.99]));

  auto result = reg.renderAll();
  assert(result.indexOf("# HELP http_requests") >= 0, "counter HELP missing");
  assert(result.indexOf("# TYPE http_requests counter") >= 0, "counter TYPE missing");
  assert(result.indexOf("# HELP cpu_temp") >= 0, "gauge HELP missing");
  assert(result.indexOf("# TYPE cpu_temp gauge") >= 0, "gauge TYPE missing");
  assert(result.indexOf("# HELP latency") >= 0, "histogram HELP missing");
  assert(result.indexOf("# TYPE latency histogram") >= 0, "histogram TYPE missing");
  assert(result.indexOf("# HELP latency_summary") >= 0, "summary HELP missing");
  assert(result.indexOf("# TYPE latency_summary summary") >= 0, "summary TYPE missing");

  // --- counter/gauge lookup ---
  auto c = reg.counter("http_requests");
  assert(c !is null, "counter lookup should find http_requests");
  assert(c.name() == "http_requests");

  auto missingCounter = reg.counter("nonexistent");
  assert(missingCounter is null, "counter lookup of nonexistent should return null");

  auto g = reg.gauge("cpu_temp");
  assert(g !is null, "gauge lookup should find cpu_temp");
  assert(g.name() == "cpu_temp");

  auto missingGauge = reg.gauge("nonexistent");
  assert(missingGauge is null, "gauge lookup of nonexistent should return null");

  // --- get!T typed lookup ---
  auto c2 = reg.get!Counter("http_requests");
  assert(c2 !is null, "get!Counter should find http_requests");

  auto g2 = reg.get!Gauge("cpu_temp");
  assert(g2 !is null, "get!Gauge should find cpu_temp");

  auto wrongType = reg.get!Gauge("http_requests");
  assert(wrongType is null, "get!Gauge on counter should return null");

  auto wrongType2 = reg.get!Counter("cpu_temp");
  assert(wrongType2 is null, "get!Counter on gauge should return null");

  // --- get!T for Histogram and Summary (generic fallback) ---
  auto h = reg.get!Histogram("latency");
  assert(h !is null, "get!Histogram should find latency");
  assert(h.name() == "latency");

  auto s = reg.get!Summary("latency_summary");
  assert(s !is null, "get!Summary should find latency_summary");
  assert(s.name() == "latency_summary");

  // --- duplicate name detection ---
  // Adding a metric with same name should not crash and should warn
  reg.add(new Counter("http_requests", "Duplicate counter"));
  // renderAll should still work fine
  auto result2 = reg.renderAll();
  assert(result2.indexOf("# HELP http_requests") >= 0);

  // --- set value on counter and verify it appears in output ---
  auto c3 = reg.get!Counter("http_requests");
  c3.inc(5);
  result2 = reg.renderAll();
  assert(result2.indexOf("http_requests 5") > 0, "counter value should be 5 in output");
}
