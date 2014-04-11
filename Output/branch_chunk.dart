part of codemirror.dart;

class BranchChunk {
  var children;
  var size;
  var height;
  var parent;

  BranchChunk(children) {
    this.children = children;
    var size = 0,
        height = 0;
    for (var i = 0; i < children.length; ++i) {
      var ch = children[i];
      size += ch.chunkSize();
      height += ch.height;
      ch.parent = this;
    }
    this.size = size;
    this.height = height;
    this.parent = null;
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
