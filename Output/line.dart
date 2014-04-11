part of codemirror.dart;

class Line {
  var text;
  var height;
  Line(text, markedSpans, estimateHeight) {
    this.text = text;
    attachMarkedSpans(this, markedSpans);
    this.height = estimateHeight ? estimateHeight(this) : 1;
  }
  on(type, f) {
    _on(this, type, f);
  }
  off(type, f) {
    _off(this, type, f);
  }
  lineNo() {
    return _lineNo(this);
  }
}
