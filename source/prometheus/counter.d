module prometheus.counter;

import core.atomic;
import std.format;
import std.array;

import prometheus.metric;

@safe:

private struct Value {
public:
  void inc(double v = 1) @nogc nothrow
  {
    atomicOp!"+="(_value, v);
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

/// --- Counter ---
class Counter : Metric {
private:
  Value[immutable(string[string])] _values;

public:
  this(string name, string help, immutable string[string] labels = null) @nogc nothrow
  {
    super(name, help, "counter", labels);
  }

  ref Value opCall(immutable string[string] kv)
  {
    synchronized (this) {
      if (kv !in _values)
        _values[kv] = Value();
      return _values[kv];
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

  void set(double v)
  {
    synchronized (this) {
      if (_values.length == 0)
        _values[_defaultLabels] = Value();
      _values[_defaultLabels].set(v);
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
        ret.put(format!"%s%s %s\n"(_name, renderLabels(labels, _defaultLabels), value.get()));
      return ret.data();
    }
  }
}

// test combinations of no labels, default labels, opCall labels
unittest {
  // no labels
  auto c1 = new Counter("name1", "desc1");
  c1.inc(1);
  auto expect = "# HELP name1 desc1\n# TYPE name1 counter\nname1 1\n";
  assert(c1.render() == expect, format("\ngot:\n%s\nexpected:\n%s", c1.render(), expect));

  // default labels
  auto c2 = new Counter("name2", "desc2", ["key": "value"]);
  c2.inc(2);
  expect = "# HELP name2 desc2\n# TYPE name2 counter\nname2{key=\"value\"} 2\n";
  assert(c2.render() == expect, format("\ngot:\n%s\nexpected:\n%s", c2.render(), expect));

  // opCall labels
  auto c3 = new Counter("name3", "desc3");
  c3(["op": "inc"]).inc(3);
  expect = "# HELP name3 desc3\n# TYPE name3 counter\nname3{op=\"inc\"} 3\n";
  assert(c3.render() == expect, format("\ngot:\n%s\nexpected:\n%s", c3.render(), expect));

  // default + opCall labels
  auto c4 = new Counter("name4", "desc4", ["key": "value"]);
  c4(["op1": "inc1"]).inc(4.1);
  expect = "# HELP name4 desc4\n# TYPE name4 counter\nname4{op1=\"inc1\",key=\"value\"} 4.1\n";
  assert(c4.render() == expect, format("\ngot:\n%s\nexpected:\n%s", c4.render(), expect));

  // same counter with different opCall labels
  c4(["op2": "inc2"]).inc(4.2);
  expect = "# HELP name4 desc4\n# TYPE name4 counter\nname4{op2=\"inc2\",key=\"value\"} 4.2\n"
    ~ "name4{op1=\"inc1\",key=\"value\"} 4.1\n";
  assert(c4.render() == expect, format("\ngot:\n%s\nexpected:\n%s", c4.render(), expect));

  // set and get
  auto c5 = new Counter("name5", "desc5");
  c5.set(100);
  assert(c5.get() == 100, format("expected 100, got %s", c5.get()));

  // set on opCall-labeled counter
  c5(["host": "a"]).set(200);
  assert(c5(["host": "a"]).get() == 200, format("expected 200, got %s", c5(["host": "a"]).get()));

  // set + get with default labels
  auto c6 = new Counter("name6", "desc6", ["env": "test"]);
  c6.set(42);
  assert(c6.get() == 42, format("expected 42, got %s", c6.get()));
  expect = "# HELP name6 desc6\n# TYPE name6 counter\nname6{env=\"test\"} 42\n";
  assert(c6.render() == expect, format("\ngot:\n%s\nexpected:\n%s", c6.render(), expect));

  // get on a brand-new counter (triggers lazy-init in get())
  auto c7 = new Counter("name7", "desc7");
  assert(c7.get() == 0, format("expected 0, got %s", c7.get()));
}
