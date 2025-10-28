module prometheus.metric;

import std.format;

/// --- Base Metric ---
abstract class Metric {
protected:
  string _name;
  string _help;
  string _mtype;
  immutable string[string] _defaultLabels;

  string renderLabels(T...)(T labelsArgs)
  {
    string result = "";
    bool firstLabel = true;
    foreach (i, labels; labelsArgs) {
      // don't output anything for empty labels or default labels only
      if (labels.length == 0 || (i == 0 && labels == _defaultLabels)) // || labels == _defaultLabels) // if (labels.length == 0)
        continue;
      if (firstLabel)
        result ~= "{";
      else
        result ~= ",";
      firstLabel = false;
      bool first = true;
      foreach (k, v; labels) {
        if (!first)
          result ~= ",";
        result ~= format("%s=\"%s\"", k, v);
        first = false;
      }
    }
    if (!firstLabel)
      result ~= "}";
    return result;
  }

public:
  this(string name, string help, string mtype, immutable string[string] labels = null) @nogc nothrow
  {
    _name = name;
    _help = help;
    _mtype = mtype;
    if (labels !is null)
      _defaultLabels = labels;
  }

  string renderHeader()
  {
    return format("# HELP %s %s\n# TYPE %s %s\n", _name, _help, _name, _mtype);
  }

  string name() const @nogc nothrow
  {
    return _name;
  }

  string mtype() const @nogc nothrow
  {
    return _mtype;
  }

  abstract string render();
}
