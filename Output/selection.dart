part of codemirror.dart;

class Selection {
  var ranges;
  var primIndex;
  Selection(ranges, primIndex) {
    this.ranges = ranges;
    this.primIndex = primIndex;
  }
  primary() {
    return this.ranges[this.primIndex];
  }
  equals(other) {
    if (other == this) return true;
    if (other.primIndex != this.primIndex || other.ranges.length !=
        this.ranges.length) return false;
    for (var i = 0; i < this.ranges.length; i++) {
      var here = this.ranges[i],
          there = other.ranges[i];
      if (cmp(here.anchor, there.anchor) != 0 || cmp(here.head, there.head) !=
          0) return false;
    }
    return true;
  }
  deepCopy() {
    var out = [];
    for (var i = 0; i < this.ranges.length; i++) out[i] = new Range(copyPos(
        this.ranges[i].anchor), copyPos(this.ranges[i].head));
    return new Selection(out, this.primIndex);
  }
  somethingSelected() {
    for (var i = 0; i < this.ranges.length; i++) if (!this.ranges[i].empty())
        return true;
    return false;
  }
  contains(pos, end) {
    if (!end) end = pos;
    for (var i = 0; i < this.ranges.length; i++) {
      var range = this.ranges[i];
      if (cmp(end, range.from()) >= 0 && cmp(pos, range.to()) <= 0) return i;
    }
    return -1;
  }
}
