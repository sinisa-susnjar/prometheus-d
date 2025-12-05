module prometheus.registry;

import core.atomic;
import std.format;

import prometheus.metric;
import prometheus.counter;
import prometheus.gauge;

/// --- Registry ---
class Registry {
private:
  Counter[string] _counters;
  Gauge[string] _gauges;
  Metric[] _metrics;

public:
  this()
  {
  }

  Counter counter(string name)
  {
    if (name in _counters)
      return _counters[name];
    return null;
  }

  Gauge gauge(string name)
  {
    if (name in _gauges)
      return _gauges[name];
    return null;
  }

  T add(T)(T m) if (is(T : Metric))
  {
    synchronized (this) {
      _metrics ~= m;
      // TODO: check if a metric with the same name already exists and do something smart
      static if (is(T : Counter)) {
        _counters[m.name()] = m;
      }
      static if (is(T : Gauge)) {
        _gauges[m.name()] = m;
      }
    }
    return m;
  }

  string renderAll()
  {
    synchronized (this) {
      string result;
      foreach (m; _metrics) {
        synchronized (m) {
          result ~= m.render() ~ "\n";
        }
      }
      return result;
    }
  }
}
