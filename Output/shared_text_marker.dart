part of codemirror.dart;

class SharedTextMarker {
  var markers;
  var primary;
  var explicitlyCleared;
  SharedTextMarker(markers, primary) {
    this.markers = markers;
    this.primary = primary;
    for (var i = 0; i < markers.length; ++i) markers[i].parent = this;
  }
  on(type, f) {
    _on(this, type, f);
  }
  off(type, f) {
    _off(this, type, f);
  }
  clear() {
    if (this.explicitlyCleared) return;
    this.explicitlyCleared = true;
    for (var i = 0; i < this.markers.length; ++i) this.markers[i].clear();
    signalLater(this, "clear");
  }
  find(side, lineObj) {
    return this.primary.find(side, lineObj);
  }
}
