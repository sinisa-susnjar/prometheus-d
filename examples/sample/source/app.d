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

  // Create some counters
  auto counter = reg.add(new Counter("requests_total", "Total number of requests"));
  auto counter2 = reg.add(new Counter("requests_total2", "Total number of requests", [
    "method": "GET"
  ]));
  auto counter3 = reg.add(new Counter("requests_total3", "Total number of requests", [
    "method": "GET"
  ]));
  auto counter4 = reg.add(new Counter("requests_total4", "Total number of requests", [
    "method": "GET"
  ]));

  // Create some gauges
  auto gauge = reg.add(new Gauge("cpu_usage_percent", "Simulated CPU usage"));
  auto gauge2 = reg.add(new Gauge("cpu_usage_percent2", "Simulated CPU usage"));
  auto gauge3 = reg.add(new Gauge("cpu_usage_percent3", "Simulated CPU usage"));
  auto gauge4 = reg.add(new Gauge("cpu_usage_percent4", "Simulated CPU usage"));

  // Create a histogram with a given set of buckets
  auto hist = reg.add(new Histogram("response_time_seconds", "Response time", [
    0.1, 0.5, 1, 2, 5, 10
  ]));

  // Create a summary with a given set of percentiles
  auto summary = reg.add(new Summary("response_latency", "Observed latency", [0.5, 0.9, 0.99]));

  // Create a gauge with some static information that never changes
  reg.add(new Gauge("server_info", "Server information", [
    "account": "#123456789",
    "type": "DEMO",
    "server": "Darwinex-Demo",
    "company": "Tradeslide Trading Tech Limited",
    "ccy": "EUR",
    "stop_out_mode": "%"
  ]));

  // Background metric updates
  new Thread({ serveMetrics(reg, 8081); }).start();

  auto cnt = 0;
  immutable hosts = ["spock", "bones", "scotty"];
  while (true) {
    if (++cnt % 2 == 0)
      counter(["client": "client#1", "symbol": "XAUUSD"]).inc(0.1);
    else
      counter(["client": "client#2", "symbol": "USDJPY"]).inc(0.2);
    counter2.inc(1);
    counter3.inc(10);
    counter4.inc(100);
    gauge(["host": hosts[cnt % hosts.length]]).set(uniform(0, 100));
    gauge2.set(uniform(100, 1000));
    gauge3.set(uniform(1000, 10_000));
    gauge4.set(uniform(10_000, 100_000));
    auto v = hist(["host": hosts[cnt % hosts.length]]).observe(uniform(0.01, 10.0));
    summary(["host": hosts[cnt % hosts.length]]).observe(v);
    Thread.sleep(50.msecs);
  }
}
