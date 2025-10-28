module prometheus.histogram;

import core.sync.mutex;
import core.atomic;
import std.format;
import std.array;

import prometheus.metric;

/// --- Histogram ---
class Histogram : Metric {
  double[] buckets; // sorted bucket limits
  shared double[] counts;
  shared double sum = 0;
  shared ulong totalCount = 0;
  Mutex mtx;

  this(string name, string help, double[] buckets, string[string] labels = null)
  {
    super(name, help, "histogram", labels);
    this.buckets = buckets.dup;
    this.counts = new double[buckets.length];
    counts[] = 0;
    mtx = new Mutex;
  }

  void observe(double v)
  {
    synchronized (mtx) {
      foreach (i, limit; buckets) {
        if (v <= limit) {
          // counts[i]++;
          core.atomic.atomicOp!"+="(this.counts[i], 1);
          // writefln("counts: %s", counts);
        }
      }
      // sum += v;
      core.atomic.atomicOp!"+="(this.sum, v);
      // totalCount++;
      core.atomic.atomicOp!"+="(this.totalCount, 1);
    }
  }

  override string render()
  {
    auto sb = appender!string;
    sb.put("# HELP " ~ name ~ " " ~ help ~ "\n");
    sb.put("# TYPE " ~ name ~ " histogram\n");

    synchronized (mtx) {
      foreach (i, limit; buckets) {
        sb.put(format!"%s_bucket%s,le=\"%s\" %s\n"(name, renderLabels(), limit, counts[i]));
      }
      sb.put(format!"%s_bucket%s,le=\"+Inf\" %s\n"(name, renderLabels(), totalCount));
      sb.put(format!"%s_sum%s %s\n"(name, renderLabels(), sum));
      sb.put(format!"%s_count%s %s\n"(name, renderLabels(), totalCount));
    }
    return sb.data;
  }
}
