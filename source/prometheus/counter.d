module prometheus.counter;

import core.atomic;
import std.format;

import prometheus.metric;

/// --- Counter ---
class Counter : Metric {
private:
  shared double _value = 0;

public:
  this(string name, string help, string[string] labels = null)
  {
    super(name, help, "counter", labels);
  }

  void inc(double v = 1)
  {
    atomicOp!"+="(_value, v);
  }

  void set(double v)
  {
    atomicStore(_value, v);
  }

  double get()
  {
    return atomicLoad(_value);
  }

  override string render()
  {
    synchronized (this) {
      return renderHeader() ~ format("%s%s %s\n", _name, renderLabels(), get());
    }
  }
}
