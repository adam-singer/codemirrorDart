part of codemirror.dart;

class LineView {
  var line;
  var rest;
  var size;
  var node;
  var text;
  var hidden;
  LineView(doc, line, lineN) {
    this.line = line;
    this.rest = visualLineContinued(line);
    this.size = this.rest ? _lineNo(lst(this.rest)) - lineN + 1 : 1;
    this.node = this.text = null;
    this.hidden = lineIsHidden(doc, line);
  }
}
