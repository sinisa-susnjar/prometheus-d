module prometheus.registry;

import core.sync.mutex;
import core.atomic;
import std.format;

import prometheus.metric;

/// --- Registry ---
class Registry {
  private Metric[] metrics;
  private Mutex mtx;

  this()
  {
    mtx = new Mutex;
  }

  void add(Metric m)
  {
    synchronized (mtx)
      metrics ~= m;
  }

  string renderAll()
  {
    synchronized (mtx) {
      string result;
      foreach (m; metrics)
        result ~= m.render() ~ "\n";
      return result;
    }
  }
}
