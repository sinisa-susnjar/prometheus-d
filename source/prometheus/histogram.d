module prometheus.histogram;

import core.atomic;
import std.format;
import std.array;
import std.conv : to;

import prometheus.metric;

/// --- Histogram ---
class Histogram : Metric {
private:
  double[] _buckets; // sorted bucket limits
  shared double[] _counts;
  shared double _sum = 0;
  shared ulong _totalCount = 0;

public:
  this(string name, string help, double[] buckets, string[string] labels = null)
  {
    super(name, help, "histogram", labels);
    _buckets = buckets.dup;
    _counts = new double[buckets.length];
    _counts[] = 0;
  }

  void observe(double v)
  {
    synchronized (this) {
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
    }
  }

  /// Render all metrics for this histogram
  override string render()
  {
    synchronized (this) {
      auto sb = appender!string;
      sb.put(renderHeader());
      // Regular buckets
      foreach (i, limit; _buckets) {
        string[string] merged = _labels.dup;
        merged["le"] = to!string(limit);
        string fullLabels = renderCustomLabels(merged);
        sb.put(format!"%s%s %s\n"(_name, fullLabels, _counts[i]));
      }

      // +Inf bucket
      {
        string[string] merged = _labels.dup;
        merged["le"] = "+Inf";
        string fullLabels = renderCustomLabels(merged);
        sb.put(format!"%s%s %s\n"(_name, fullLabels, _totalCount));
      }

      // sum and count
      string baseLabels = renderLabels();
      sb.put(format!"%s_sum%s %s\n"(_name, baseLabels, _sum));
      sb.put(format!"%s_count%s %s\n"(_name, baseLabels, _totalCount));
      return sb.data;
    }
  }
}
