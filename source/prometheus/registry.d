module prometheus.registry;

import core.atomic;
import std.format;

import prometheus.metric;
import prometheus.counter;

/// --- Registry ---
class Registry {
private:
  Counter[string] _counters;
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

  T add(T)(T m) if (is(T : Metric))
  {
    synchronized (this) {
      _metrics ~= m;
      static if (is(T : Counter)) {
        // TODO: check if a counter with the same name already exists and do something smart
        _counters[m.name()] = m;
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
