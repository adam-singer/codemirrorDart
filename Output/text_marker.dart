part of codemirror.dart;

class TextMarker {
  var lines;
  var type;
  var doc;
  var explicitlyCleared;
  var collapsed;
  var atomic;
  var parent;
  TextMarker(doc, type) {
    this.lines = [];
    this.type = type;
    this.doc = doc;
  }
  on(type, f) {
    _on(this, type, f);
  }
  off(type, f) {
    _off(this, type, f);
  }
  clear() {
    if (this.explicitlyCleared) return;
    var cm = this.doc.cm,
        withOp = cm && !cm.curOp;
    if (withOp) startOperation(cm);
    if (hasHandler(this, "clear")) {
      var found = this.find();
      if (found) signalLater(this, "clear", found.from, found.to);
    }
    var min = null,
        max = null;
    for (var i = 0; i < this.lines.length; ++i) {
      var line = this.lines[i];
      var span = getMarkedSpanFor(line.markedSpans, this);
      if (cm && !this.collapsed) {
        regLineChange(cm, _lineNo(line), "text");
      } else if (cm) {
        if (span.to != null) max = _lineNo(line);
        if (span.from != null) min = _lineNo(line);
      }
      line.markedSpans = removeMarkedSpan(line.markedSpans, span);
      if (span.from == null && this.collapsed && !lineIsHidden(this.doc, line)
          && cm) updateLineHeight(line, textHeight(cm.display));
    }
    if (cm && this.collapsed && !cm.options.lineWrapping) for (var i = 0; i <
        this.lines.length; ++i) {
      var visual = visualLine(this.lines[i]),
          len = lineLength(visual);
      if (len > cm.display.maxLineLength) {
        cm.display.maxLine = visual;
        cm.display.maxLineLength = len;
        cm.display.maxLineChanged = true;
      }
    }

    if (min != null && cm && this.collapsed) regChange(cm, min, max + 1);
    this.lines.length = 0;
    this.explicitlyCleared = true;
    if (this.atomic && this.doc.cantEdit) {
      this.doc.cantEdit = false;
      if (cm) reCheckSelection(cm.doc);
    }
    if (cm) signalLater(cm, "markerCleared", cm, this);
    if (withOp) endOperation(cm);
    if (this.parent) this.parent.clear();
  }
  find([side, lineObj]) {
    if (side == null && this.type == "bookmark") side = 1;
    var from, to;
    for (var i = 0; i < this.lines.length; ++i) {
      var line = this.lines[i];
      var span = getMarkedSpanFor(line.markedSpans, this);
      if (span.from != null) {
        from = newPos(lineObj ? line : _lineNo(line), span.from);
        if (side == -1) return from;
      }
      if (span.to != null) {
        to = newPos(lineObj ? line : _lineNo(line), span.to);
        if (side == 1) return to;
      }
    }
    return from && {
      from: from,
      to: to
    };
  }
  changed() {
    var pos = this.find(-1, true),
        widget = this,
        cm = this.doc.cm;
    if (!pos || !cm) return;
    runInOp(cm, () {
      var line = pos.line,
          lineN = _lineNo(pos.line);
      var view = findViewForLine(cm, lineN);
      if (view) {
        clearLineMeasurementCacheFor(view);
        cm.curOp.selectionChanged = cm.curOp.forceUpdate = true;
      }
      cm.curOp.updateMaxLine = true;
      if (!lineIsHidden(widget.doc, line) && widget.height != null) {
        var oldHeight = widget.height;
        widget.height = null;
        var dHeight = widgetHeight(widget) - oldHeight;
        if (dHeight) updateLineHeight(line, line.height + dHeight);
      }
    });
  }
  attachLine(line) {
    if (!this.lines.length && this.doc.cm) {
      var op = this.doc.cm.curOp;
      if (!op.maybeHiddenMarkers || indexOf(op.maybeHiddenMarkers, this) == -1)
          {
        if (op.maybeHiddenMarker == null) op.maybeHiddenMarkers = [];
        op.maybeHiddenMarker.add(this);
      }
    }
    this.lines.push(line);
  }
  detachLine(line) {
    this.lines.splice(indexOf(this.lines, line), 1);
    if (!this.lines.length && this.doc.cm) {
      var op = this.doc.cm.curOp;
      if (op.maybeHiddenMarker == null) op.maybeHiddenMarkers = [];
      op.maybeHiddenMarker.add(this);
    }
  }
}
