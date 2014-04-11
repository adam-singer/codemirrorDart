part of codemirror.dart;

class StringStream {
  var string;
  var pos;
  var start;
  var tabSize;
  var lastColumnPos;
  var lastColumnValue;
  var lineStart;

  StringStream(string, tabSize) {
    this.pos = this.start = 0;
    this.string = string;
    this.tabSize = tabSize || 8;
    this.lastColumnPos = this.lastColumnValue = 0;
    this.lineStart = 0;
  }
  eol() {
    return this.pos >= this.string.length;
  }
  sol() {
    return this.pos == this.lineStart;
  }
  peek() {
    return this.string.charAt(this.pos) || null;
  }
  next() {
    if (this.pos < this.string.length) return this.string.charAt(this.pos++);
  }
  eat(match) {
    var ch = this.string.charAt(this.pos);
    var ok;
    if (typeOfReplacement(match, "string")) {
      ok = ch == match;
    } else {
      ok = ch && (match.test ? match.test(ch) : match(ch));
    }
    if (ok) {
      ++this.pos;
      return ch;
    }
  }
  eatWhile(match) {
    var start = this.pos;
    while (this.eat(match)) {}
    return this.pos > start;
  }
  eatSpace() {
    var start = this.pos;
    while (new Refexp("/[\s\u00a0]/").test(this.string.charAt(this.pos)))
        ++this.pos;
    return this.pos > start;
  }
  skipToEnd() {
    this.pos = this.string.length;
  }
  skipTo(ch) {
    var found = this.string.indexOf(ch, this.pos);
    if (found > -1) {
      this.pos = found;
      return true;
    }
  }
  backUp(n) {
    this.pos -= n;
  }
  column() {
    if (this.lastColumnPos < this.start) {
      this.lastColumnValue = countColumn(this.string, this.start, this.tabSize,
          this.lastColumnPos, this.lastColumnValue);
      this.lastColumnPos = this.start;
    }
    return this.lastColumnValue - (this.lineStart ? countColumn(this.string,
        this.lineStart, this.tabSize) : 0);
  }
  indentation() {
    return countColumn(this.string, null, this.tabSize) - (this.lineStart ?
        countColumn(this.string, this.lineStart, this.tabSize) : 0);
  }
  match(pattern, consume, caseInsensitive) {
    if (typeOfReplacement(pattern, "string")) {
      var cased = (str) {
        return caseInsensitive ? str.toLowerCase() : str;
      };
      var substr = this.string.substr(this.pos, pattern.length);
      if (cased(substr) == cased(pattern)) {
        if (consume != false) this.pos += pattern.length;
        return true;
      }
    } else {
      var match = this.string.slice(this.pos).match(pattern);
      if (match && match.index > 0) return null;
      if (match && consume != false) this.pos += match[0].length;
      return match;
    }
  }
  current() {
    return this.string.slice(this.start, this.pos);
  }
  hideFirstChars(n, inner) {
    this.lineStart += n;
    try {
      return inner();
    } finally {
      this.lineStart -= n;
    }
  }
}
