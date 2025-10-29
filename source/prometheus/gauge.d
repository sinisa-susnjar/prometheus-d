module prometheus.gauge;

import core.sync.mutex;
import core.atomic;
import std.format;

import prometheus.metric;

/// --- Gauge ---
class Gauge : Metric {
private:
  shared double _value = 0;

public:
  this(string name, string help, string[string] labels = null)
  {
    super(name, help, "gauge", labels);
  }

  void set(double v)
  {
    atomicStore(_value, v);
  }

  void inc(double v = 1)
  {
    atomicOp!"+="(_value, v);
  }

  void dec(double v = 1)
  {
    atomicOp!"-="(_value, v);
  }

  double get()
  {
    return atomicLoad(_value);
  }

  override string render()
  {
    return renderHeader() ~ format("%s%s %s\n", _name, renderLabels(), get());
  }
}
