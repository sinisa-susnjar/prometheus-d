module prometheus.server;

import std.logger.core;

import std.socket;
import std.string;

import std.array;
import std.conv;
import core.memory;

import prometheus.registry;
import prometheus.gauge;

/// --- HTTP Server ---
void serveMetrics(Registry registry, ushort port = 8080, string host = "0.0.0.0") @safe
{
  auto listener = new Socket(AddressFamily.INET, SocketType.STREAM);
  listener.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, true);
  listener.bind(new InternetAddress(host, port));
  listener.listen(10);

  infof("prometheus metrics at http://%s:%d/metrics", host, port);

  auto gcFreeSize = registry.add(
      new Gauge("gc_free_size_bytes", "Free bytes on the GC heap"));
  auto gcUsedSize = registry.add(
      new Gauge("gc_used_size_bytes", "Used bytes on the GC heap"));
  auto gcMaxCollectionTime = registry.add(
      new Gauge("gc_max_collection_time", "Largest time spent during GC cycle in usecs"));
  auto gcMaxPauseTime = registry.add(
      new Gauge("gc_max_pause_time", "Largest time paused during GC cycle in usecs"));
  auto gcNumCollections = registry.add(
      new Gauge("gc_num_collections", "Total number of GC cycles"));
  auto gcTotalCollectionTime = registry.add(
      new Gauge("gc_total_collection_time", "Total time spent doing GC in usecs"));
  auto gcTotalPauseTime = registry.add(
      new Gauge("gc_total_pause_time", "Total time paused doing GC in usecs"));

  while (true) {
    try {
      auto conn = listener.accept();
      scope (exit)
        conn.close();

      char[8192] buffer;
      auto bytesRead = conn.receive(buffer[]);
      if (bytesRead == Socket.ERROR || bytesRead <= 0) {
        errorf("truncated request from %s", conn.remoteAddress());
        continue;
      }

      string request = buffer[0 .. bytesRead].idup;

      // Exact match for /metrics
      if (request.startsWith("GET /metrics ") || request.startsWith("GET /metrics\r\n")
        || request == "GET /metrics") {

        auto stats = GC.stats();
        auto prof = GC.profileStats();
        gcFreeSize.set(stats.freeSize);
        gcUsedSize.set(stats.usedSize);
        gcMaxCollectionTime.set(prof.maxCollectionTime.total!"usecs");
        gcMaxPauseTime.set(prof.maxPauseTime.total!"usecs");
        gcNumCollections.set(prof.numCollections);
        gcTotalCollectionTime.set(prof.totalCollectionTime.total!"usecs");
        gcTotalPauseTime.set(prof.totalPauseTime.total!"usecs");

        // tracef("got request from %s: %s", conn.remoteAddress(), request);
        // infof("registry: %s", registry);
        string body = registry.renderAll();
        string response = "HTTP/1.1 200 OK\r\n" ~ "Content-Type: text/plain; version=0.0.4\r\n"
          ~ "Content-Length: " ~ to!string(body.length) ~ "\r\n" ~ "Connection: close\r\n\r\n" ~ body;
        // tracef("response: %s", response);
        auto ret = conn.send(response);
        if (ret == Socket.ERROR || ret <= 0) {
          errorf("send response failed %s: %s", conn.remoteAddress(), response);
        }
      } else if (request.startsWith("GET / ") || request.startsWith("GET /\r\n") || request == "GET /") {
        string body = "prometheus-d metrics server\n";
        string response = "HTTP/1.1 200 OK\r\n" ~ "Content-Type: text/plain\r\n"
          ~ "Content-Length: " ~ to!string(body.length) ~ "\r\n" ~ "Connection: close\r\n\r\n" ~ body;
        conn.send(response);
      } else {
        errorf("unknown request from %s: %s", conn.remoteAddress(), request);
        conn.send("HTTP/1.1 404 Not Found\r\nConnection: close\r\n\r\n");
      }
    } catch (Exception ex) {
      errorf("caught exception: %s", ex.message);
    }
  }
}

// test HTTP server: /metrics, /, and 404
unittest {
  import std.string : indexOf;
  import core.thread : Thread, msecs;
  import prometheus.counter;

  // Use a high random-ish port to avoid conflicts
  ushort port = 18_901;

  // (cast()sharedLog).logLevel = LogLevel.trace;

  auto reg = new Registry();
  auto c = reg.add(new Counter("test_requests", "Test counter"));
  c.inc(42);

  // Spawn the server in a background thread
  auto serverThread = new Thread(() {
    serveMetrics(reg, port, "127.0.0.1");
  });
  serverThread.isDaemon(true);
  serverThread.start();

  // Give it time to bind
  Thread.sleep(200.msecs);

  auto sendRequest = (string req) {
    auto sock = new Socket(AddressFamily.INET, SocketType.STREAM);
    scope (exit) sock.close();
    sock.connect(new InternetAddress("127.0.0.1", port));
    sock.send(req);
    char[8192] buf;
    auto n = sock.receive(buf[]);
    if (n <= 0 || n == Socket.ERROR)
      return "";
    return buf[0 .. n].idup;
  };

  // --- test GET /metrics ---
  {
    auto resp = sendRequest("GET /metrics HTTP/1.0\r\n\r\n");
    assert(resp.indexOf("HTTP/1.1 200 OK") >= 0, "should get 200 for /metrics, got: " ~ resp);
    assert(resp.indexOf("Content-Type: text/plain") >= 0, "should have text/plain content type");
    assert(resp.indexOf("test_requests") > 0, "should contain counter name in body");
  }

  // --- test GET / ---
  {
    auto resp = sendRequest("GET / HTTP/1.0\r\n\r\n");
    assert(resp.indexOf("HTTP/1.1 200 OK") >= 0, "should get 200 for /, got: " ~ resp);
    assert(resp.indexOf("prometheus-d metrics server") > 0, "should have server info in body");
  }

  // --- test unknown request (404) ---
  {
    auto resp = sendRequest("POST /foo HTTP/1.0\r\n\r\n");
    assert(resp.indexOf("HTTP/1.1 404 Not Found") >= 0, "should get 404 for unknown path, got: " ~ resp);
  }
}
