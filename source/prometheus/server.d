module prometheus.server;

import std.logger.core;

import std.socket;
import std.string;

import std.array;
import std.conv;

import prometheus.registry;

/// --- HTTP Server ---
void serveMetrics(Registry registry, ushort port = 8080, string host = "0.0.0.0")
{
  auto listener = new Socket(AddressFamily.INET, SocketType.STREAM);
  listener.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, true);
  listener.bind(new InternetAddress(host, port));
  listener.listen(50);

  infof("prometheus metrics at http://%s:%d/metrics, registry: %s", host, port, registry);

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
        infof("got request from %s: %s", conn.remoteAddress(), request);
        // infof("registry: %s", registry);
        string body = registry.renderAll();
        string response = "HTTP/1.1 200 OK\r\n" ~ "Content-Type: text/plain; version=0.0.4\r\n"
          ~ "Content-Length: " ~ to!string(body.length) ~ "\r\n" ~ "Connection: close\r\n\r\n" ~ body;
        infof("response: %s", response);
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
