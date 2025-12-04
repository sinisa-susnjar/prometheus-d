module prometheus.counter;

import core.atomic;
import std.format;

import prometheus.metric;

private struct Value {
public:
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

private:
  shared double _value = 0;
}

/// --- Counter ---
class Counter : Metric {
private:
  Value[immutable(string[string])] _values;

public:
  this(string name, string help, immutable string[string] labels = null)
  {
    super(name, help, "counter", labels);
    if (labels !is null)
      _values[labels] = Value();
  }

  ref Value opCall(immutable string[string] kv)
  {
    if (kv !in _values)
      _values[kv] = Value();
    return _values[kv];
  }

  void inc(double v = 1)
  {
    if (_values.length == 0)
      _values[_defaultLabels] = Value();
    foreach (ref value; _values)
      value.inc(v);
  }

  void set(double v)
  {
    if (_values.length == 0)
      _values[_defaultLabels] = Value();
    foreach (ref value; _values)
      value.set(v);
  }

  double get()
  {
    if (_values.length == 0)
      _values[_defaultLabels] = Value();
    double v = 0;
    foreach (ref value; _values)
      v = value.get();
    return v;
  }

  override string render()
  {
    synchronized (this) {
      string ret = renderHeader();
      foreach (ref labels, ref value; _values) {
        if (labels == _defaultLabels && _values.length > 1)
          continue;
        ret ~= format("%s%s %s\n", _name, renderLabels(labels), value.get());
      }
      return ret;
    }
  }
}
