module prometheus.gauge;

import core.sync.mutex;
import core.atomic;
import std.format;

import prometheus.metric;

/// --- Gauge ---
class Gauge : Metric {
  shared double value = 0;
  this(string name, string help, string[string] labels = null)
  {
    super(name, help, "gauge", labels);
  }

  void set(double v)
  {
    atomicStore(value, v);
  }

  void inc(double v = 1)
  {
    atomicOp!"+="(value, v);
  }

  void dec(double v = 1)
  {
    atomicOp!"-="(value, v);
  }

  double get()
  {
    return atomicLoad(value);
  }

  override string render()
  {
    return renderHeader() ~ format!"%s%s %s\n"(name, renderLabels(), get());
  }
}
