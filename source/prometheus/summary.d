module prometheus.summary;

import core.sync.mutex;
import std.algorithm;
import core.atomic;
import std.format;
import std.array;
import std.conv;

import prometheus.metric;

/// --- Summary ---
class Summary : Metric {
private:
  struct Quantile {
    double quantile;
    double value;
  }

  Quantile[] _quantiles;
  shared double _sum = 0;
  shared ulong _count = 0;
  Mutex _mtx;

public:
  this(string name, string help, double[] quantileValues, string[string] labels = null)
  {
    super(name, help, "summary", labels);
    _quantiles = quantileValues.map!(q => Quantile(q, 0.0)).array;
    _mtx = new Mutex;
  }

  void observe(double v)
  {
    synchronized (_mtx) {
      // sum += v;
      core.atomic.atomicOp!"+="(_sum, v);
      // count++;
      core.atomic.atomicOp!"+="(_count, 1);
      // Update quantiles (simple streaming approximation)
      foreach (ref q; _quantiles) {
        q.value += (v - q.value) * 0.05; // smoothing factor
      }
    }
  }

  override string render()
  {
    auto sb = appender!string;
    sb.put(renderHeader());
    synchronized (_mtx) {
      // Render quantiles
      foreach (q; _quantiles) {
        string[string] merged = _labels.dup;
        merged["quantile"] = to!string(q.quantile);
        string fullLabels = renderCustomLabels(merged);
        sb.put(format!"%s%s %s\n"(_name, fullLabels, q.value));
      }

      // Render sum and count
      string baseLabels = renderLabels();
      sb.put(format!"%s_sum%s %s\n"(_name, baseLabels, _sum));
      sb.put(format!"%s_count%s %s\n"(_name, baseLabels, _count));
    }

    return sb.data;
  }
}
