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
  auto counter2 = new Counter("requests_total2", "Total number of requests", ["method": "GET"]);
  auto counter3 = new Counter("requests_total3", "Total number of requests", ["method": "GET"]);
  auto counter4 = new Counter("requests_total4", "Total number of requests", ["method": "GET"]);
  auto gauge = new Gauge("cpu_usage_percent", "Simulated CPU usage");
  auto gauge2 = new Gauge("cpu_usage_percent2", "Simulated CPU usage");
  auto gauge3 = new Gauge("cpu_usage_percent3", "Simulated CPU usage");
  auto gauge4 = new Gauge("cpu_usage_percent4", "Simulated CPU usage");
  auto hist = new Histogram("response_time_seconds", "Response time", [0.1, 0.5, 1, 2, 5, 10]);
  auto summary = new Summary("response_latency", "Observed latency", [0.5, 0.9, 0.99]);
  auto info = new Gauge("server_info", "Server information", [
    "account": "#123456789",
    "type": "DEMO",
    "server": "Darwinex-Demo",
    "company": "Tradeslide Trading Tech Limited",
    "ccy": "EUR",
    "stop_out_mode": "%"
  ]);

  reg.add(counter);
  reg.add(counter2);
  reg.add(counter3);
  reg.add(counter4);
  reg.add(gauge);
  reg.add(gauge2);
  reg.add(gauge3);
  reg.add(gauge4);
  reg.add(hist);
  reg.add(summary);
  reg.add(info);

  // Background metric updates
  new Thread({ serveMetrics(reg, 8081); }).start();

  while (true) {
    counter.inc(0.1);
    counter2.inc(1);
    counter3.inc(10);
    counter4.inc(100);
    gauge.set(uniform(0, 100));
    gauge2.set(uniform(100, 1000));
    gauge3.set(uniform(1000, 10000));
    gauge4.set(uniform(10000, 100000));
    double val = uniform(0.01, 10.0);
    hist.observe(val);
    summary.observe(val);
    Thread.sleep(50.msecs);
  }
}
