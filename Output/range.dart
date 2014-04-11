part of codemirror.dart;

class Range {
  var anchor;
  var head;
  Range(anchor, head) {
    this.anchor = anchor;
    this.head = head;
  }
  from() {
    return minPos(this.anchor, this.head);
  }
  to() {
    return maxPos(this.anchor, this.head);
  }
  empty() {
    return this.head.line == this.anchor.line && this.head.ch == this.anchor.ch;
  }
}
