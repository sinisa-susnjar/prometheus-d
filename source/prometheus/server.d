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
void serveMetrics(Registry registry, ushort port = 8080, string host = "0.0.0.0")
{
  auto listener = new Socket(AddressFamily.INET, SocketType.STREAM);
  listener.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, true);
  listener.bind(new InternetAddress(host, port));
  listener.listen(50);

  infof("prometheus metrics at http://%s:%d/metrics, registry: %s", host, port, registry);

  auto gcFreeSize = registry.add(new Gauge("gc_free_size", "Free bytes on the GC heap"));
  auto gcUsedSize = registry.add(new Gauge("gc_used_size", "Used bytes on the GC heap"));
  auto gcMaxCollectionTime = registry.add(new Gauge("gc_max_collection_time",
      "Largest time spent during GC cycle in µs"));
  auto gcMaxPauseTime = registry.add(new Gauge("gc_max_pause_time", "Largest time paused during GC cycle in us"));
  auto gcNumCollections = registry.add(new Gauge("gc_num_collections", "Total number of GC cycles"));
  auto gcTotalCollectionTime = registry.add(new Gauge("gc_total_collection_time", "Total time spent doing GC in us"));
  auto gcTotalPauseTime = registry.add(new Gauge("gc_total_pause_time", "Total time paused doing GC in us"));

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

      if (request.startsWith("GET /metrics")) {

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
      } else {
        errorf("unknown request from %s: %s", conn.remoteAddress(), request);
        conn.send("HTTP/1.1 404 Not Found\r\nConnection: close\r\n\r\n");
      }
    } catch (Exception ex) {
      errorf("caught exception: %s", ex);
    }
  }
}
