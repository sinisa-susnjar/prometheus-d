module prometheus.metric;

import std.format;

/// --- Base Metric ---
abstract class Metric {
  string name;
  string help;
  string mtype;
  string[string] labels; // static labels

  this(string name, string help, string mtype, string[string] labels = null)
  {
    this.name = name;
    this.help = help;
    this.mtype = mtype;
    if (labels !is null)
      this.labels = labels.dup;
  }

  string renderLabels()
  {
    if (labels.length == 0)
      return "";
    string result = "{";
    bool first = true;
    foreach (k, v; labels) {
      if (!first)
        result ~= ",";
      result ~= format!"%s=\"%s\""(k, v);
      first = false;
    }
    result ~= "}";
    return result;
  }

  abstract string render();
}
