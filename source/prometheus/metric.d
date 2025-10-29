module prometheus.metric;

import std.format;

/// --- Base Metric ---
abstract class Metric {
protected:
  string _name;
  string _help;
  string _mtype;
  string[string] _labels; // static labels

  string renderCustomLabels(string[string] lbls)
  {
    if (lbls.length == 0)
      return "";
    string result = "{";
    bool first = true;
    foreach (k, v; lbls) {
      if (!first)
        result ~= ",";
      result ~= format!"%s=\"%s\""(k, v);
      first = false;
    }
    result ~= "}";
    return result;
  }

public:
  this(string name, string help, string mtype, string[string] labels = null)
  {
    _name = name;
    _help = help;
    _mtype = mtype;
    if (labels !is null)
      _labels = labels.dup;
  }

  string renderLabels()
  {
    if (_labels.length == 0)
      return "";
    string result = "{";
    bool first = true;
    foreach (k, v; _labels) {
      if (!first)
        result ~= ",";
      result ~= format("%s=\"%s\"", k, v);
      first = false;
    }
    result ~= "}";
    return result;
  }

  string renderHeader()
  {
    return format("# HELP %s %s\n# TYPE %s %s\n", _name, _help, _name, _mtype).dup;
  }

  abstract string render();
}
