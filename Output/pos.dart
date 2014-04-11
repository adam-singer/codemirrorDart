part of codemirror.dart;

class Pos {
  var line;
  var ch;
  Pos(line, ch) {
    this.line = line;
    this.ch = ch;
  }
}

class PosWithInfo extends Pos {
  var outside;
  var xRel;
  PosWithInfo(line, ch, outside, xRel) : super(line, ch) {
    this.outside = outside;
    this.xRel = xRel;
  }
}
