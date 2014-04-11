part of codemirror.dart;

class LeafChunk {
  var lines;
  var parent;
  var height;

  LeafChunk(lines) {
    this.lines = lines;
    this.parent = null;
    for (var i = 0,
        height = 0; i < lines.length; ++i) {
      lines[i].parent = this;
      height += lines[i].height;
    }
    this.height = height;
  }
  chunkSize() {
    return this.lines.length;
  }
  removeInner(at, n) {
    for (var i = at,
        e = at + n; i < e; ++i) {
      var line = this.lines[i];
      this.height -= line.height;
      cleanUpLine(line);
      signalLater(line, "delete");
    }
    this.lines.splice(at, n);
  }
  collapse(lines) {
    lines.push.apply(lines, this.lines);
  }
  insertInner(at, lines, height) {
    this.height += height;
    this.lines = this.lines.slice(0, at).concat(lines).concat(this.lines.slice(
        at));
    for (var i = 0; i < lines.length; ++i) lines[i].parent = this;
  }
  iterN(at, n, op) {
    for (var e = at + n; at < e; ++at) if (op(this.lines[at])) return true;
  }
}
