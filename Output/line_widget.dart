part of codemirror.dart;

class LineWidget {
  var cm;
  var node;
  var height;
  var line;
  LineWidget(cm, node, options) {
    if (options) for (var opt in options) if (options.hasOwnProperty(opt))
        this[opt] = options[opt];
    this.cm = cm;
    this.node = node;
  }
  on(type, f) {
    _on(this, type, f);
  }
  off(type, f) {
    _off(this, type, f);
  }
  clear() {
    var cm = this.cm,
        ws = this.line.widgets,
        line = this.line,
        no = _lineNo(line);
    if (no == null || !ws) return;
    for (var i = 0; i < ws.length; ++i) if (ws[i] == this) ws.splice(i--, 1);
    if (!ws.length) line.widgets = null;
    var height = widgetHeight(this);
    runInOp(cm, () {
      adjustScrollWhenAboveVisible(cm, line, -height);
      regLineChange(cm, no, "widget");
      updateLineHeight(line, math.max(0, line.height - height));
    });
  }
  changed() {
    var oldH = this.height,
        cm = this.cm,
        line = this.line;
    this.height = null;
    var diff = widgetHeight(this) - oldH;
    if (!diff) return;
    runInOp(cm, () {
      cm.curOp.forceUpdate = true;
      adjustScrollWhenAboveVisible(cm, line, diff);
      updateLineHeight(line, line.height + diff);
    });
  }

  // XXX
  void operator []=(var key, var value) {}
}
