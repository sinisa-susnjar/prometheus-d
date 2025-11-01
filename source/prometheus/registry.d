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

  void add(Metric m)
  {
    synchronized (this)
      _metrics ~= m;
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
