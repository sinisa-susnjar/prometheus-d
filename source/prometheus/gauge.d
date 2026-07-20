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
    synchronized (this) {
      if (kv !in _values)
        _values[kv] = Value();
      return _values[kv];
    }
  }

  void set(double v)
  {
    synchronized (this) {
      if (_values.length == 0)
        _values[_defaultLabels] = Value();
      _values[_defaultLabels].set(v);
    }
  }

  void inc(double v = 1)
  {
    synchronized (this) {
      if (_values.length == 0)
        _values[_defaultLabels] = Value();
      _values[_defaultLabels].inc(v);
    }
  }

  void dec(double v = 1)
  {
    synchronized (this) {
      if (_values.length == 0)
        _values[_defaultLabels] = Value();
      _values[_defaultLabels].dec(v);
    }
  }

  double get()
  {
    synchronized (this) {
      if (_values.length == 0)
        _values[_defaultLabels] = Value();
      return _values[_defaultLabels].get();
    }
  }

  override string render()
  {
    synchronized (this) {
      auto ret = appender!string;
      ret.put(renderHeader());
      foreach (ref labels, ref value; _values)
        ret.put(format("%s%s %s\n", _name, renderLabels(labels, _defaultLabels), value.get()));
      return ret.data();
    }
  }
}

// test combinations of no labels, default labels, opCall labels
unittest {
  import std.string : indexOf;

  // no labels
  auto g1 = new Gauge("name1", "desc1");
  g1.set(42.0);
  auto renderOut = g1.render();
  auto expect = "# HELP name1 desc1\n# TYPE name1 gauge\nname1 42\n";
  assert(renderOut == expect, format("\ngot:\n%s\nexpected:\n%s", renderOut, expect));

  // inc/dec
  g1.inc(8);
  assert(g1.get() == 50.0, format("expected 50, got %s", g1.get()));
  g1.dec(10);
  assert(g1.get() == 40.0, format("expected 40, got %s", g1.get()));

  // default labels
  auto g2 = new Gauge("name2", "desc2", ["key": "value"]);
  g2.set(99.0);
  renderOut = g2.render();
  assert(renderOut.indexOf("key=\"value\"") > 0, "default labels missing: " ~ renderOut);

  // opCall labels
  auto g3 = new Gauge("name3", "desc3");
  g3(["host": "server1"]).set(3.14);
  renderOut = g3.render();
  assert(renderOut.indexOf("host=\"server1\"") > 0, "opCall labels missing: " ~ renderOut);

  // multiple label sets
  g3(["host": "server2"]).set(2.71);
  renderOut = g3.render();
  assert(renderOut.indexOf("host=\"server1\"") > 0);
  assert(renderOut.indexOf("host=\"server2\"") > 0);
}
