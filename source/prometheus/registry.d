module prometheus.registry;

import core.atomic;
import std.format;

import prometheus.metric;

/// --- Registry ---
class Registry {
private:
  Metric[] _metrics;

public:
  this()
  {
  }

  T add(T)(T m) if (is(T : Metric))
  {
    synchronized (this)
      _metrics ~= m;
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
