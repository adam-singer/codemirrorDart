part of codemirror.dart;

class Doc {
  var cm;
  var first;
  var scrollTop;
  var scrollLeft;
  var cantEdit;
  var cleanGeneration;
  var frontier;
  var sel;
  var history;
  var id;
  var modeOption;
  var size;
  var extend;
  var children;
  var linked;
  var mode;

  static int nextDocId = 0;

  Doc(text, mode, firstLine) {
    //if (!(this is Doc)) return new Doc(text, mode, firstLine);
    if (firstLine == null) firstLine = 0;

    //BranchChunk.call(this, [new LeafChunk([new Line("", null)])]);
    this.first = firstLine;
    this.scrollTop = this.scrollLeft = 0;
    this.cantEdit = false;
    this.cleanGeneration = 1;
    this.frontier = firstLine;
    var start = newPos(firstLine, 0);
    this.sel = simpleSelection(start);
    this.history = new History(null);
    this.id = ++nextDocId;
    this.modeOption = mode;

    if (typeOfReplacement(text, "string")) text = splitLines(text);
    updateDoc(this, {
      'from': start,
      'to': start,
      'text': text
    });
    _setSelection(this, simpleSelection(start), sel_dontScroll);
  }
  iter(from, to, op) {
    if (op) {
      this.iterN(from - this.first, to - from, op);
    } else {
      this.iterN(this.first, this.first + this.size, from);
    }
  }
  insert(at, lines) {
    var height = 0;
    for (var i = 0; i < lines.length; ++i) height += lines[i].height;
    this.insertInner(at - this.first, lines, height);
  }
  remove(at, n) {
    this.removeInner(at - this.first, n);
  }
  getValue(lineSep) {
    var lines = getLines(this, this.first, this.first + this.size);
    if (lineSep == false) return lines;
    return lines.join(lineSep || "\n");
  }
  setValue() {
    var f, arguments; // XXX
    var cm = this.cm;
    if (!cm || cm.curOp) return f.apply(this, arguments);
    startOperation(cm);
    try {
      return f.apply(this, arguments);
    } finally {
      endOperation(cm);
    }
  }
  replaceRange(code, from, to, origin) {
    from = _clipPos(this, from);
    to = to ? _clipPos(this, to) : from;
    replaceRange(this, code, from, to, origin);
  }
  getRange(from, to, lineSep) {
    var lines = getBetween(this, _clipPos(this, from), _clipPos(this, to));
    if (lineSep == false) return lines;
    return lines.join(lineSep || "\n");
  }
  getLine(line) {
    var l = this.getLineHandle(line);
    return l && l.text;
  }
  getLineHandle(line) {
    if (isLine(this, line)) return getLine(this, line);
  }
  getLineNumber(line) {
    return _lineNo(line);
  }
  getLineHandleVisualStart(line) {
    if (typeOfReplacement(line, "number")) line = getLine(this, line);
    return visualLine(line);
  }
  lineCount() {
    return this.size;
  }
  firstLine() {
    return this.first;
  }
  lastLine() {
    return this.first + this.size - 1;
  }
  clipPos(pos) {
    return _clipPos(this, pos);
  }
  getCursor(start) {
    var range = this.sel.primary(),
        pos;
    if (start == null || start == "head") {
      pos = range.head;
    } else if (start == "anchor") {
      pos = range.anchor;
    } else if (start == "end" || start == "to" || start == false) {
      pos = range.to();
    } else {
      pos = range.from();
    }
    return pos;
  }
  listSelections() {
    return this.sel.ranges;
  }
  somethingSelected() {
    return this.sel.somethingSelected();
  }
  setCursor() {
    var f, arguments; // XXX
    var cm = this.cm;
    if (!cm || cm.curOp) return f.apply(this, arguments);
    startOperation(cm);
    try {
      return f.apply(this, arguments);
    } finally {
      endOperation(cm);
    }
  }
  setSelection() {
    var f, arguments; // XXX
    var cm = this.cm;
    if (!cm || cm.curOp) return f.apply(this, arguments);
    startOperation(cm);
    try {
      return f.apply(this, arguments);
    } finally {
      endOperation(cm);
    }
  }
  extendSelection() {
    var f, arguments; // XXX
    var cm = this.cm;
    if (!cm || cm.curOp) return f.apply(this, arguments);
    startOperation(cm);
    try {
      return f.apply(this, arguments);
    } finally {
      endOperation(cm);
    }
  }
  extendSelections() {
    var f, arguments; // XXX
    var cm = this.cm;
    if (!cm || cm.curOp) return f.apply(this, arguments);
    startOperation(cm);
    try {
      return f.apply(this, arguments);
    } finally {
      endOperation(cm);
    }
  }
  extendSelectionsBy() {
    var f, arguments; // XXX
    var cm = this.cm;
    if (!cm || cm.curOp) return f.apply(this, arguments);
    startOperation(cm);
    try {
      return f.apply(this, arguments);
    } finally {
      endOperation(cm);
    }
  }
  setSelections() {
    var f, arguments; // XXX
    var cm = this.cm;
    if (!cm || cm.curOp) return f.apply(this, arguments);
    startOperation(cm);
    try {
      return f.apply(this, arguments);
    } finally {
      endOperation(cm);
    }
  }
  addSelection() {
    var f, arguments; // XXX
    var cm = this.cm;
    if (!cm || cm.curOp) return f.apply(this, arguments);
    startOperation(cm);
    try {
      return f.apply(this, arguments);
    } finally {
      endOperation(cm);
    }
  }
  getSelection(lineSep) {
    var ranges = this.sel.ranges,
        lines;
    for (var i = 0; i < ranges.length; i++) {
      var sel = getBetween(this, ranges[i].from(), ranges[i].to());
      lines = lines ? lines.concat(sel) : sel;
    }
    if (lineSep == false) {
      return lines;
    } else {
      return lines.join(lineSep || "\n");
    }
  }
  getSelections(lineSep) {
    var parts = [],
        ranges = this.sel.ranges;
    for (var i = 0; i < ranges.length; i++) {
      var sel = getBetween(this, ranges[i].from(), ranges[i].to());
      if (lineSep != false) sel = sel.join(lineSep || "\n");
      parts[i] = sel;
    }
    return parts;
  }
  replaceSelection() {
    var f, arguments; // XXX
    var cm = this.cm;
    if (!cm || cm.curOp) return f.apply(this, arguments);
    startOperation(cm);
    try {
      return f.apply(this, arguments);
    } finally {
      endOperation(cm);
    }
  }
  replaceSelections(code, collapse, origin) {
    var changes = [],
        sel = this.sel;
    for (var i = 0; i < sel.ranges.length; i++) {
      var range = sel.ranges[i];
      changes[i] = {
        'from': range.from(),
        'to': range.to(),
        'text': splitLines(code[i]),
        origin: origin
      };
    }
    var newSel = collapse && collapse != "end" && computeReplacedSel(this,
        changes, collapse);
    for (var i = changes.length - 1; i >= 0; i--) makeChange(this, changes[i]);
    if (newSel) {
      setSelectionReplaceHistory(this, newSel);
    } else if (this.cm) ensureCursorVisible(this.cm);
  }
  undo() {
    var f, arguments; // XXX
    var cm = this.cm;
    if (!cm || cm.curOp) return f.apply(this, arguments);
    startOperation(cm);
    try {
      return f.apply(this, arguments);
    } finally {
      endOperation(cm);
    }
  }
  redo() {
    var f, arguments; // XXX
    var cm = this.cm;
    if (!cm || cm.curOp) return f.apply(this, arguments);
    startOperation(cm);
    try {
      return f.apply(this, arguments);
    } finally {
      endOperation(cm);
    }
  }
  undoSelection() {
    var f, arguments; // XXX
    var cm = this.cm;
    if (!cm || cm.curOp) return f.apply(this, arguments);
    startOperation(cm);
    try {
      return f.apply(this, arguments);
    } finally {
      endOperation(cm);
    }
  }
  redoSelection() {
    var f, arguments; // XXX
    var cm = this.cm;
    if (!cm || cm.curOp) return f.apply(this, arguments);
    startOperation(cm);
    try {
      return f.apply(this, arguments);
    } finally {
      endOperation(cm);
    }
  }
  setExtending(val) {
    this.extend = val;
  }
  getExtending() {
    return this.extend;
  }
  historySize() {
    var hist = this.history,
        done = 0,
        undone = 0;
    for (var i = 0; i < hist.done.length; i++) if (!hist.done[i].ranges) ++done;
    for (var i = 0; i < hist.undone.length; i++) if (!hist.undone[i].ranges)
        ++undone;
    return {
      undo: done,
      redo: undone
    };
  }
  clearHistory() {
    this.history = new History(this.history.maxGeneration);
  }
  markClean() {
    this.cleanGeneration = this.changeGeneration(true);
  }
  changeGeneration(forceSplit) {
    if (forceSplit) this.history.lastOp = this.history.lastOrigin = null;
    return this.history.generation;
  }
  isClean(gen) {
    return this.history.generation == (gen || this.cleanGeneration);
  }
  getHistory() {
    return {
      'done': copyHistoryArray(this.history.done),
      'undone': copyHistoryArray(this.history.undone)
    };
  }
  setHistory(histData) {
    var hist = this.history = new History(this.history.maxGeneration);
    hist.done = copyHistoryArray(histData.done.slice(0), null, true);
    hist.undone = copyHistoryArray(histData.undone.slice(0), null, true);
  }
  markText(from, to, options) {
    return markText(this, _clipPos(this, from), _clipPos(this, to), options,
        "range");
  }
  setBookmark(pos, options) {
    var realOpts = {
      'replacedWith': options && (options.nodeType == null ? options.widget :
          options),
      'insertLeft': options && options.insertLeft,
      'clearWhenEmpty': false,
      'shared': options && options.shared
    };
    pos = _clipPos(this, pos);
    return markText(this, pos, pos, realOpts, "bookmark");
  }
  findMarksAt(pos) {
    pos = _clipPos(this, pos);
    var markers = [],
        spans = getLine(this, pos.line).markedSpans;
    if (spans) for (var i = 0; i < spans.length; ++i) {
      var span = spans[i];
      if ((span.from == null || span.from <= pos.ch) && (span.to == null ||
          span.to >= pos.ch)) markers.push(span.marker.parent || span.marker);
    }
    return markers;
  }
  findMarks(from, to, filter) {
    from = _clipPos(this, from);
    to = _clipPos(this, to);
    var found = [],
        lineNo = from.line;
    this.iter(from.line, to.line + 1, (line) {
      var spans = line.markedSpans;
      if (spans) for (var i = 0; i < spans.length; i++) {
        var span = spans[i];
        if (!(lineNo == from.line && from.ch > span.to || span.from == null &&
            lineNo != from.line || lineNo == to.line && span.from > to.ch) && (!filter ||
            filter(span.marker))) found.push(span.marker.parent || span.marker);
      }
      ++lineNo;
    });
    return found;
  }
  getAllMarks() {
    var markers = [];
    this.iter((line) {
      var sps = line.markedSpans;
      if (sps) for (var i = 0; i < sps.length; ++i) if (sps[i].from != null)
          markers.push(sps[i].marker);
    });
    return markers;
  }
  posFromIndex(off) {
    var ch,
        lineNo = this.first;
    this.iter((line) {
      var sz = line.text.length + 1;
      if (sz > off) {
        ch = off;
        return true;
      }
      off -= sz;
      ++lineNo;
    });
    return clipPos(this, newPos(lineNo, ch));
  }
  indexFromPos(coords) {
    coords = clipPos(this, coords);
    var index = coords.ch;
    if (coords.line < this.first || coords.ch < 0) return 0;
    this.iter(this.first, coords.line, (line) {
      index += line.text.length + 1;
    });
    return index;
  }
  copy(copyHistory) {
    var doc = new Doc(getLines(this, this.first, this.first + this.size),
        this.modeOption, this.first);
    doc.scrollTop = this.scrollTop;
    doc.scrollLeft = this.scrollLeft;
    doc.sel = this.sel;
    doc.extend = false;
    if (copyHistory) {
      doc.history.undoDepth = this.history.undoDepth;
      doc.setHistory(this.getHistory());
    }
    return doc;
  }
  linkedDoc(options) {
    if (!options) options = {};
    var from = this.first,
        to = this.first + this.size;
    if (options.from != null && options.from > from) from = options.from;
    if (options.to != null && options.to < to) to = options.to;
    var copy = new Doc(getLines(this, from, to), options.mode ||
        this.modeOption, from);
    if (options.sharedHist) copy.history = this.history;
    (this.linked || (this.linked = [])).push({
      'doc': copy,
      'sharedHist': options.sharedHist
    });
    copy.linked = [{
        'doc': this,
        'isParent': true,
        'sharedHist': options.sharedHist
      }];
    copySharedMarkers(copy, findSharedMarkers(this));
    return copy;
  }
  unlinkDoc(other) {
    if (other is CodeMirror) other = other.doc;
    if (this.linked) for (var i = 0; i < this.linked.length; ++i) {
      var link = this.linked[i];
      if (link.doc != other) continue;
      this.linked.splice(i, 1);
      other.unlinkDoc(this);
      detachSharedMarkers(findSharedMarkers(this));
      break;
    }

    if (other.history == this.history) {
      var splitIds = [other.id];
      linkedDocs(other, (doc) {
        splitIds.push(doc.id);
      }, true);
      other.history = new History(null);
      other.history.done = copyHistoryArray(this.history.done, splitIds);
      other.history.undone = copyHistoryArray(this.history.undone, splitIds);
    }
  }
  iterLinkedDocs(f) {
    linkedDocs(this, f);
  }
  getMode() {
    return this.mode;
  }
  getEditor() {
    return this.cm;
  }
  eachLine(from, to, op) {
    if (op) {
      this.iterN(from - this.first, to - from, op);
    } else {
      this.iterN(this.first, this.first + this.size, from);
    }
  }
  on(type, f) {
    _on(this, type, f);
  }
  off(type, f) {
    _off(this, type, f);
  }
  chunkSize() {
    return this.size;
  }
  removeInner(at, n) {
    this.size -= n;
    for (var i = 0; i < this.children.length; ++i) {
      var child = this.children[i],
          sz = child.chunkSize();
      if (at < sz) {
        var rm = math.min(n, sz - at),
            oldHeight = child.height;
        child.removeInner(at, rm);
        this.height -= oldHeight - child.height;
        if (sz == rm) {
          this.children.splice(i--, 1);
          child.parent = null;
        }
        if ((n -= rm) == 0) break;
        at = 0;
      } else {
        at -= sz;
      }
    }


    if (this.size - n < 25 && (this.children.length > 1 || !(this.children[0] is
        LeafChunk))) {
      var lines = [];
      this.collapse(lines);
      this.children = [new LeafChunk(lines)];
      this.children[0].parent = this;
    }
  }
  collapse(lines) {
    for (var i = 0; i < this.children.length; ++i) this.children[i].collapse(
        lines);
  }
  insertInner(at, lines, height) {
    this.size += lines.length;
    this.height += height;
    for (var i = 0; i < this.children.length; ++i) {
      var child = this.children[i],
          sz = child.chunkSize();
      if (at <= sz) {
        child.insertInner(at, lines, height);
        if (child.lines && child.lines.length > 50) {
          while (child.lines.length > 50) {
            var spilled = child.lines.splice(child.lines.length - 25, 25);
            var newleaf = new LeafChunk(spilled);
            child.height -= newleaf.height;
            this.children.splice(i + 1, 0, newleaf);
            newleaf.parent = this;
          }
          this.maybeSpill();
        }
        break;
      }
      at -= sz;
    }
  }
  maybeSpill() {
    if (this.children.length <= 10) return;
    var me = this;
    do {
      var spilled = me.children.splice(me.children.length - 5, 5);
      var sibling = new BranchChunk(spilled);
      if (!me.parent) {
        var copy = new BranchChunk(me.children);
        copy.parent = me;
        me.children = [copy, sibling];
        me = copy;
      } else {
        me.size -= sibling.size;
        me.height -= sibling.height;
        var myIndex = indexOf(me.parent.children, me);
        me.parent.children.splice(myIndex + 1, 0, sibling);
      }
      sibling.parent = me.parent;
    } while (me.children.length > 10);
    me.parent.maybeSpill();
  }
  iterN(at, n, op) {
    for (var i = 0; i < this.children.length; ++i) {
      var child = this.children[i],
          sz = child.chunkSize();
      if (at < sz) {
        var used = math.min(n, sz - at);
        if (child.iterN(at, used, op)) return true;
        if ((n -= used) == 0) break;
        at = 0;
      } else {
        at -= sz;
      }
    }
  }
}
