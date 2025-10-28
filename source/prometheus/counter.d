module prometheus.counter;

import core.sync.mutex;
import core.atomic;
import std.format;

import prometheus.metric;

/// --- Counter ---
class Counter : Metric {
  shared double value = 0;
  this(string name, string help, string[string] labels = null)
  {
    super(name, help, "counter", labels);
  }

  void inc(double v = 1)
  {
    atomicOp!"+="(value, v);
  }

  void set(double v)
  {
    atomicStore(value, v);
  }

  double get()
  {
    return atomicLoad(value);
  }

  override string render()
  {
    return "# HELP " ~ name ~ " " ~ help ~ "\n" ~ "# TYPE " ~ name ~ " counter\n" ~ format!"%s%s %s\n"(name,
        renderLabels(), get());
  }
}
