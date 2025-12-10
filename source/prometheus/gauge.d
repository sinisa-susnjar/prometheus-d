module prometheus.gauge;

import core.atomic;
import std.format;
import std.array;

import prometheus.metric;

private struct Value {
public:
  void inc(double v = 1) @nogc nothrow
  {
    atomicOp!"+="(_value, v);
  }

  void dec(double v = 1) @nogc nothrow
  {
    atomicOp!"-="(_value, v);
  }

  void set(double v) @nogc nothrow
  {
    atomicStore(_value, v);
  }

  double get() @nogc nothrow
  {
    return atomicLoad(_value);
  }

private:
  shared double _value = 0;
}

/// --- Gauge ---
class Gauge : Metric {
private:
  Value[immutable(string[string])] _values;

public:
  this(string name, string help, immutable string[string] labels = null) @nogc nothrow
  {
    super(name, help, "gauge", labels);
  }

  ref Value opCall(immutable string[string] kv)
  {
    if (kv !in _values)
      _values[kv] = Value();
    return _values[kv];
  }

  void set(double v)
  {
    if (_values.length == 0)
      _values[_defaultLabels] = Value();
    _values[_defaultLabels].set(v);
  }

  void inc(double v = 1)
  {
    if (_values.length == 0)
      _values[_defaultLabels] = Value();
    _values[_defaultLabels].inc(v);
  }

  void dec(double v = 1)
  {
    if (_values.length == 0)
      _values[_defaultLabels] = Value();
    _values[_defaultLabels].dec(v);
  }

  double get()
  {
    if (_values.length == 0)
      _values[_defaultLabels] = Value();
    return _values[_defaultLabels].get();
  }

  override string render()
  {
    synchronized (this) {
      auto ret = appender!string;
      ret.put(renderHeader());
      foreach (ref labels, ref value; _values)
        ret.put(format("%s%s %s\n", _name, renderLabels(labels), value.get()));
      return ret.data();
    }
  }
}
