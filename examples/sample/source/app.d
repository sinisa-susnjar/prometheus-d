import std.socket;
import std.stdio;
import std.string;
import std.conv;
import std.datetime.stopwatch;
import std.format;
import std.random;
import std.array;
import core.thread;
import core.atomic;
import core.sync.mutex;

import prometheus;

/// --- Main Demo ---
void main()
{
  auto reg = new Registry();

  // Create labeled metrics
  auto counter = new Counter("requests_total", "Total number of requests", ["method": "GET"]);
  auto gauge = new Gauge("cpu_usage_percent", "Simulated CPU usage");
  auto hist = new Histogram("response_time_seconds", "Response time", [0.1, 0.5, 1, 2, 5, 10]);
  auto summary = new Summary("response_latency", "Observed latency", 100);
  auto info = new Gauge("server_info", "Server information", [
    "account": "#123456789",
    "type": "DEMO",
    "server": "Darwinex-Demo",
    "company": "Tradeslide Trading Tech Limited",
    "ccy": "EUR",
    "stop_out_mode": "%"
  ]);

  reg.add(counter);
  reg.add(gauge);
  reg.add(hist);
  reg.add(summary);
  reg.add(info);

  // Background metric updates
  new Thread({ serveMetrics(reg); }).start();

  while (true) {
    counter.inc(0.1);
    gauge.set(uniform(0, 100));
    double val = uniform(0.01, 10.0);
    hist.observe(val);
    summary.observe(val);
    Thread.sleep(1.seconds);
  }
}
