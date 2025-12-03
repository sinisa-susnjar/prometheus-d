module prometheus.summary;

import std.algorithm;
import core.atomic;
import std.format;
import std.array;
import std.conv;

import prometheus.metric;

private struct Quantile {
  double quantile;
  double value;
}

private struct Value {
public:
  this(double[] quantileValues)
  {
    _quantiles = quantileValues.map!(q => Quantile(q, 0.0)).array;
  }

  double observe(double v)
  {
    // sum += v;
    core.atomic.atomicOp!"+="(_sum, v);
    // count++;
    core.atomic.atomicOp!"+="(_count, 1);
    // Update quantiles (simple streaming approximation)
    foreach (ref q; _quantiles) {
      q.value += (v - q.value) * 0.05; // smoothing factor
    }
    return v;
  }

  ref const(Quantile[]) quantiles() const
  {
    return _quantiles;
  }

  double sum() const
  {
    return _sum;
  }

  double count() const
  {
    return _count;
  }

private:
  Quantile[] _quantiles;
  shared double _sum = 0;
  shared ulong _count = 0;
}

/// --- Summary ---
class Summary : Metric {
private:
  Value[immutable(string[string])] _values;
  double[] _quantiles;

public:
  this(string name, string help, double[] quantileValues, string[string] labels = null)
  {
    super(name, help, "summary", labels);
    // _quantiles = quantileValues.map!(q => Quantile(q, 0.0)).array;
    _quantiles = quantileValues;
  }

  ref Value opCall(immutable string[string] kv)
  {
    if (kv !in _values)
      _values[kv] = Value(_quantiles);
    return _values[kv];
  }

  /*
  double observe(double v)
  {
    synchronized (this) {
      // sum += v;
      core.atomic.atomicOp!"+="(_sum, v);
      // count++;
      core.atomic.atomicOp!"+="(_count, 1);
      // Update quantiles (simple streaming approximation)
      foreach (ref q; _quantiles) {
        q.value += (v - q.value) * 0.05; // smoothing factor
      }
    }
    return v;
  }
  */

  /*
  string render2()
  {
    synchronized (this) {
      auto sb = appender!string;
      sb.put(renderHeader());
      // Render quantiles
      foreach (q; _quantiles) {
        // string[string] merged = _labels.dup;
        immutable string[string] merged = ["quantile": to!string(q.quantile)];
        string fullLabels = renderLabels(merged);
        sb.put(format!"%s%s %s\n"(_name, fullLabels, q.value));
      }

      // Render sum and count
      string baseLabels = renderLabels();
      sb.put(format!"%s_sum%s %s\n"(_name, baseLabels, _sum));
      sb.put(format!"%s_count%s %s\n"(_name, baseLabels, _count));
      return sb.data;
    }
  }
  */

  override string render()
  {
    synchronized (this) {
      auto sb = appender!string;
      sb.put(renderHeader());
      foreach (ref labels, ref value; _values) {
        if (labels == _defaultLabels && _values.length > 1)
          continue;
        // ret ~= format("%s%s %s\n", _name, renderLabels(labels), value.get());
        // Render quantiles
        foreach (q; value.quantiles()) {
          // string[string] merged = _labels.dup;
          string[string] merged = labels + ["quantile": to!string(q.quantile)];
          string fullLabels = renderLabels(merged);
          sb.put(format!"%s%s %s\n"(_name, fullLabels, q.value));
        }

        // Render sum and count
        string baseLabels = renderLabels();
        sb.put(format!"%s_sum%s %s\n"(_name, baseLabels, value.sum()));
        sb.put(format!"%s_count%s %s\n"(_name, baseLabels, value.count()));
      }
      return sb.data;
    }
  }

}
