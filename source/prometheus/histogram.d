module prometheus.histogram;

import core.sync.mutex;
import core.atomic;
import std.format;
import std.array;

import prometheus.metric;

/// --- Histogram ---
class Histogram : Metric {
private:
  double[] _buckets; // sorted bucket limits
  shared double[] _counts;
  shared double _sum = 0;
  shared ulong _totalCount = 0;
  Mutex _mtx;

public:
  this(string name, string help, double[] buckets, string[string] labels = null)
  {
    super(name, help, "histogram", labels);
    _buckets = buckets.dup;
    _counts = new double[buckets.length];
    _counts[] = 0;
    _mtx = new Mutex;
  }

  void observe(double v)
  {
    synchronized (_mtx) {
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

  override string render()
  {
    auto sb = appender!string;
    sb.put(renderHeader());
    synchronized (_mtx) {
      foreach (i, limit; _buckets) {
        sb.put(format!"%s_bucket%s,le=\"%s\" %s\n"(_name, renderLabels(), limit, _counts[i]));
      }
      sb.put(format!"%s_bucket%s,le=\"+Inf\" %s\n"(_name, renderLabels(), _totalCount));
      sb.put(format!"%s_sum%s %s\n"(_name, renderLabels(), _sum));
      sb.put(format!"%s_count%s %s\n"(_name, renderLabels(), _totalCount));
    }
    return sb.data;
  }
}
