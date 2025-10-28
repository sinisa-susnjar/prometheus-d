module prometheus.server;

import std.logger.core;

import std.socket;
import std.string;

// import std.stdio;
import std.array;
import std.conv;

import prometheus.registry;

/// --- HTTP Server ---
void serveMetrics(Registry registry, ushort port = 8080)
{
  auto listener = new Socket(AddressFamily.INET, SocketType.STREAM);
  listener.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, true);
  listener.bind(new InternetAddress("0.0.0.0", port));
  listener.listen(10);

  infof("prometheus metrics at http://localhost:%d/metrics, registry: %s", port, registry);

  while (true) {
    auto conn = listener.accept();
    scope (exit)
      conn.close();

    char[2048] buffer;
    auto bytesRead = conn.receive(buffer[]);
    if (bytesRead <= 0)
      continue;

    string request = buffer[0 .. bytesRead].idup;

    if (request.startsWith("GET /metrics")) {
      // infof("got request from %s: %s", conn.remoteAddress(), request);
      // infof("registry: %s", registry);
      string body = registry.renderAll();
      string response = "HTTP/1.1 200 OK\r\n" ~ "Content-Type: text/plain; version=0.0.4\r\n"
        ~ "Content-Length: " ~ to!string(body.length) ~ "\r\n" ~ "Connection: close\r\n\r\n" ~ body;
      conn.send(response);
    } else {
      conn.send("HTTP/1.1 404 Not Found\r\nConnection: close\r\n\r\n");
    }
  }
}
