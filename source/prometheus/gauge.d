module prometheus.gauge;

import core.atomic;
import std.format;

import prometheus.metric;

private struct Value {
public:
  void inc(double v = 1)
  {
    atomicOp!"+="(_value, v);
  }

  void dec(double v = 1)
  {
    atomicOp!"-="(_value, v);
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

/// --- Gauge ---
class Gauge : Metric {
private:
  shared double _value = 0;
  Value[immutable(string[string])] _values;

public:
  this(string name, string help, immutable string[string] labels = null)
  {
    if (labels)
      _values[labels] = Value();
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
    if (_defaultLabels !in _values)
      _values[_defaultLabels] = Value();
    _values[_defaultLabels].set(v);
  }

  void inc(double v = 1)
  {
    if (_defaultLabels !in _values)
      _values[_defaultLabels] = Value();
    _values[_defaultLabels].inc(v);
  }

  void dec(double v = 1)
  {
    if (_defaultLabels !in _values)
      _values[_defaultLabels] = Value();
    _values[_defaultLabels].dec(v);
  }

  double get()
  {
    if (_defaultLabels !in _values)
      _values[_defaultLabels] = Value();
    return _values[_defaultLabels].get();
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
