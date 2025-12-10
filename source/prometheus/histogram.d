module prometheus.histogram;

import core.atomic;
import std.format;
import std.array;
import std.conv : to;

import prometheus.metric;

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
    if (kv !in _values)
      _values[kv] = Value(_buckets);
    return _values[kv];
  }

  double observe(double v)
  {
    if (_defaultLabels !in _values)
      _values[_defaultLabels] = Value(_buckets);
    return _values[_defaultLabels].observe(v);
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
          string fullLabels = renderLabels(labels, cast(immutable)["le": to!string(limit)]);
          sb.put(format!"%s%s %s\n"(_name, fullLabels, value.counts[i]));
        }

        // +Inf bucket
        {
          string fullLabels = renderLabels(labels, cast(immutable)["le": "+Inf"]);
          sb.put(format!"%s%s %s\n"(_name, fullLabels, value.totalCount));
        }

        // sum and count
        string baseLabels = renderLabels(labels);
        sb.put(format!"%s_sum%s %s\n"(_name, baseLabels, value.sum));
        sb.put(format!"%s_count%s %s\n"(_name, baseLabels, value.totalCount));
      }
      return sb.data;
    }
  }
}
