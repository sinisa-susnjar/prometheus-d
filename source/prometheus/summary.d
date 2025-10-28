module prometheus.summary;

import core.sync.mutex;
import core.atomic;
import std.format;
import std.array;

import prometheus.metric;

/// --- Summary ---
class Summary : Metric {
  shared double sum = 0;
  shared ulong count = 0;
  double[] window; // simple reservoir for quantiles
  size_t maxSamples;
  Mutex mtx;

  this(string name, string help, size_t maxSamples = 100, string[string] labels = null)
  {
    super(name, help, "summary", labels);
    this.maxSamples = maxSamples;
    mtx = new Mutex;
  }

  void observe(double v)
  {
    synchronized (mtx) {
      // sum += v;
      core.atomic.atomicOp!"+="(this.sum, v);
      // count++;
      core.atomic.atomicOp!"+="(this.count, 1);
      if (window.length < maxSamples)
        window ~= v;
      else {
        window[count % maxSamples] = v; // circular overwrite
      }
    }
  }

  double quantile(double q)
  {
    import std.algorithm : sort;

    synchronized (mtx) {
      if (window.length == 0)
        return double.nan;
      auto sorted = window.dup;
      sort(sorted);
      size_t idx = cast(size_t)(q * (cast(int) sorted.length - 1));
      return sorted[idx];
    }
  }

  override string render()
  {
    auto sb = appender!string;
    sb.put("# HELP " ~ name ~ " " ~ help ~ "\n");
    sb.put("# TYPE " ~ name ~ " summary\n");
    synchronized (mtx) {
      foreach (q; [0.5, 0.9, 0.99]) {
        sb.put(format!"%s%s,quantile=\"%s\" %s\n"(name, renderLabels(), q, quantile(q)));
      }
      sb.put(format!"%s_sum%s %s\n"(name, renderLabels(), sum));
      sb.put(format!"%s_count%s %s\n"(name, renderLabels(), count));
    }
    return sb.data;
  }
}
