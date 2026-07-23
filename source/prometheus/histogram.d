module prometheus.histogram;

import core.atomic;
import std.format;
import std.array;
import std.conv : to;

import prometheus.metric;

@safe:

private struct Value {
public:
  this(double[] buckets)
  {
    _buckets = buckets;
    _counts = new double[buckets.length];
    _counts[] = 0;
  }

  double observe(double v) @nogc nothrow
  {
    foreach (i, limit; _buckets) {
      if (v <= limit) {
        // counts[i]++;
        core.atomic.atomicOp!"+="(_counts[i], 1);
        // writefln("counts: %s", counts);
      }
    }
    // sum += v;
    core.atomic.atomicOp!"+="(_sum, v);
    // totalCount++;
    core.atomic.atomicOp!"+="(_totalCount, 1);
    return v;
  }

  shared(const(double[])) counts() const @nogc nothrow
  {
    return _counts;
  }

  shared(const(double)) sum() const @nogc nothrow
  {
    return _sum;
  }

  shared(const(ulong)) totalCount() const @nogc nothrow
  {
    return _totalCount;
  }

  const(double[]) buckets() const @nogc nothrow
  {
    return _buckets;
  }

private:
  double[] _buckets; // sorted bucket limits
  shared double[] _counts;
  shared double _sum = 0;
  shared ulong _totalCount = 0;
}

/// --- Histogram ---
class Histogram : Metric {
private:
  Value[immutable(string[string])] _values;
  double[] _buckets; // sorted bucket limits

public:
  this(string name, string help, double[] buckets, immutable string[string] labels = null)
  {
    super(name, help, "histogram", labels);
    _buckets = buckets.dup;
  }

  ref Value opCall(immutable string[string] kv)
  {
    synchronized (this) {
      if (kv !in _values)
        _values[kv] = Value(_buckets);
      return _values[kv];
    }
  }

  double observe(double v)
  {
    synchronized (this) {
      if (_defaultLabels !in _values)
        _values[_defaultLabels] = Value(_buckets);
      return _values[_defaultLabels].observe(v);
    }
  }

  /// Render all metrics for this histogram
  override string render()
  {
    synchronized (this) {
      auto sb = appender!string;
      sb.put(renderHeader());
      foreach (immutable ref labels, ref value; _values) {
        if (labels == _defaultLabels && _values.length > 1)
          continue;

        // Regular buckets
        foreach (i, limit; value.buckets()) {
          immutable bucket = ["le": to!string(limit)];
          string fullLabels = renderLabels(labels, _defaultLabels, bucket);
          sb.put(format!"%s_bucket%s %s\n"(_name, fullLabels, value.counts[i]));
        }

        // +Inf bucket
        {
          static immutable inf = ["le": "+Inf"];
          string fullLabels = renderLabels(labels, _defaultLabels, inf);
          sb.put(format!"%s_bucket%s %s\n"(_name, fullLabels, value.totalCount));
        }

        // sum and count
        string baseLabels = renderLabels(labels, _defaultLabels);
        sb.put(format!"%s_sum%s %s\n"(_name, baseLabels, value.sum));
        sb.put(format!"%s_count%s %s\n"(_name, baseLabels, value.totalCount));
      }
      return sb.data;
    }
  }
}

// test labels, buckets, and rendering
unittest {
  import std.string : indexOf;

  // basic histogram
  auto h1 = new Histogram("name1", "desc1", [0.1, 0.5, 1.0, 2.0]);
  h1.observe(0.3);
  h1.observe(1.5);
  h1.observe(0.05);
  auto renderOut = h1.render();
  assert(renderOut.indexOf("# HELP name1 desc1") >= 0, "header missing");
  assert(renderOut.indexOf("# TYPE name1 histogram") >= 0, "type missing");
  assert(renderOut.indexOf("_bucket{le=\"0.1\"}") > 0);
  assert(renderOut.indexOf("_bucket{le=\"0.5\"}") > 0);
  assert(renderOut.indexOf("_bucket{le=\"1\"}") > 0);
  assert(renderOut.indexOf("_bucket{le=\"2\"}") > 0);
  assert(renderOut.indexOf("_bucket{le=\"+Inf\"}") > 0);
  assert(renderOut.indexOf("_sum") > 0);
  assert(renderOut.indexOf("_count") > 0);

  // with default labels
  auto h2 = new Histogram("name2", "desc2", [1.0, 5.0], ["env": "prod"]);
  h2.observe(3.0);
  renderOut = h2.render();
  assert(renderOut.indexOf("env=\"prod\"") > 0, "default labels missing: " ~ renderOut);

  // with opCall labels
  auto h3 = new Histogram("name3", "desc3", [10.0, 100.0]);
  h3(["host": "x"]).observe(50.0);
  renderOut = h3.render();
  assert(renderOut.indexOf("host=\"x\"") > 0, "opCall labels missing: " ~ renderOut);
}
