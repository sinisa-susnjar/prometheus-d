module prometheus.registry;

import core.sync.mutex;
import core.atomic;
import std.format;

import prometheus.metric;

/// --- Registry ---
class Registry {
private:
  Metric[] _metrics;
  Mutex _mtx;

public:
  this()
  {
    _mtx = new Mutex;
  }

  void add(Metric m)
  {
    synchronized (_mtx)
      _metrics ~= m;
  }

  string renderAll()
  {
    synchronized (_mtx) {
      string result;
      foreach (m; _metrics)
        result ~= m.render() ~ "\n";
      return result;
    }
  }
}
