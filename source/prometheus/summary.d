module prometheus.summary;

import std.algorithm;
import core.atomic;
import std.format;
import std.array;
import std.conv;
import std.math;

import prometheus.metric;

@safe:

private struct Quantile {
  double quantile;
  double value;
}

private struct Value {
public:
  this(double[] quantileValues, size_t maxSamples = 1024)
  {
    _quantileDefs = quantileValues.dup;
    _quantiles = quantileValues.map!(q => Quantile(q, 0.0)).array;
    _maxSamples = maxSamples;
    _samples.reserve(maxSamples);
  }

  double observe(double v)
  {
    // sum and count use atomic ops for thread safety
    core.atomic.atomicOp!"+="(_sum, v);
    core.atomic.atomicOp!"+="(_count, 1);

    // Reservoir sampling for quantile computation
    // Uses the class-level synchronized block for protection
    if (_samples.length < _maxSamples) {
      _samples ~= v;
    } else {
      // Random replacement (reservoir sampling)
      import std.random;
      size_t idx = uniform(0, cast(size_t)(_count));
      if (idx < _maxSamples) {
        _samples[idx] = v;
      }
    }

    // Recompute quantiles from samples
    if (_samples.length > 0) {
      auto sorted = _samples.dup;
      sort(sorted);
      foreach (ref q; _quantiles) {
        size_t idx = cast(size_t)(q.quantile * (sorted.length - 1));
        if (idx >= sorted.length)
          idx = sorted.length - 1;
        q.value = sorted[idx];
      }
    }

    return v;
  }

  const(Quantile[]) quantiles() const
  {
    return _quantiles;
  }

  double sum() const @nogc nothrow
  {
    return _sum;
  }

  double count() const @nogc nothrow
  {
    return _count;
  }

private:
  Quantile[] _quantiles;
  double[] _quantileDefs;
  double[] _samples;
  size_t _maxSamples;
  shared double _sum = 0;
  shared double _count = 0;
}

/// --- Summary ---
class Summary : Metric {
private:
  Value[immutable(string[string])] _values;
  double[] _quantileDefs;

public:
  this(string name, string help, double[] quantileValues, immutable string[string] labels = null)
  {
    super(name, help, "summary", labels);
    _quantileDefs = quantileValues.dup;
  }

  ref Value opCall(immutable string[string] kv)
  {
    synchronized (this) {
      if (kv !in _values)
        _values[kv] = Value(_quantileDefs);
      return _values[kv];
    }
  }

  double observe(double v)
  {
    synchronized (this) {
      if (_defaultLabels !in _values)
        _values[_defaultLabels] = Value(_quantileDefs);
      return _values[_defaultLabels].observe(v);
    }
  }

  override string render()
  {
    synchronized (this) {
      auto sb = appender!string;
      sb.put(renderHeader());
      foreach (immutable ref labels, ref value; _values) {
        if (labels == _defaultLabels && _values.length > 1)
          continue;

        // Render quantiles
        foreach (immutable q; value.quantiles()) {
          immutable quantile = ["quantile": to!string(q.quantile)];
          string fullLabels = renderLabels(labels, _defaultLabels, quantile);
          sb.put(format!"%s%s %s\n"(_name, fullLabels, q.value));
        }

        // Render sum and count
        string baseLabels = renderLabels(labels, _defaultLabels);
        sb.put(format!"%s_sum%s %s\n"(_name, baseLabels, value.sum()));
        sb.put(format!"%s_count%s %s\n"(_name, baseLabels, value.count()));
      }
      return sb.data;
    }
  }

}

// test labels and rendering
unittest {
  import std.string : indexOf;

  // no labels, default quantiles
  auto s1 = new Summary("name1", "desc1", [0.5, 0.9, 0.99]);
  s1.observe(1.0);
  s1.observe(2.0);
  s1.observe(3.0);
  auto renderOut = s1.render();
  assert(renderOut.indexOf("# HELP name1 desc1") >= 0, "header missing: " ~ renderOut);
  assert(renderOut.indexOf("# TYPE name1 summary") >= 0);
  assert(renderOut.indexOf("quantile=\"0.5\"") > 0);
  assert(renderOut.indexOf("quantile=\"0.9\"") > 0);
  assert(renderOut.indexOf("quantile=\"0.99\"") > 0);
  assert(renderOut.indexOf("_sum") > 0);
  assert(renderOut.indexOf("_count") > 0);

  // with default labels
  auto s2 = new Summary("name2", "desc2", [0.5, 0.9], ["key": "value"]);
  s2.observe(5.0);
  renderOut = s2.render();
  assert(renderOut.indexOf("key=\"value\"") > 0, "default labels missing: " ~ renderOut);

  // with opCall labels
  auto s3 = new Summary("name3", "desc3", [0.5]);
  s3(["host": "x"]).observe(10.0);
  renderOut = s3.render();
  assert(renderOut.indexOf("host=\"x\"") > 0, "opCall labels missing: " ~ renderOut);
}
