part of codemirror.dart;

class MarkedSpan {
  var marker;
  var from;
  var to;
  MarkedSpan(marker, from, to) {
    this.marker = marker;
    this.from = from;
    this.to = to;
  }
}

getMarkedSpanFor(spans, marker) {
  if (spans) for (var i = 0; i < spans.length; ++i) {
    var span = spans[i];
    if (span.marker == marker) return span;
  }
}

removeMarkedSpan(spans, span) {
  var r;
  for (var i = 0; i < spans.length; ++i) if (spans[i] != span) (r || (r =
      [])).push(spans[i]);
  return r;
}

addMarkedSpan(line, span) {
  line.markedSpans = line.markedSpans ? line.markedSpans.concat([span]) :
      [span];
  span.marker.attachLine(line);
}

markedSpansBefore(old, startCh, isInsert) {
  if (old) for (var i = 0,
      nw; i < old.length; ++i) {
    var span = old[i],
        marker = span.marker;
    var startsBefore = span.from == null || (marker.inclusiveLeft ? span.from <=
        startCh : span.from < startCh);
    if (startsBefore || span.from == startCh && marker.type == "bookmark" &&
        (!isInsert || !span.marker.insertLeft)) {
      var endsAfter = span.to == null || (marker.inclusiveRight ? span.to >=
          startCh : span.to > startCh);
      (nw || (nw = [])).push(new MarkedSpan(marker, span.from, endsAfter ? null
          : span.to));
    }
  }
  return nw;
}

markedSpansAfter(old, endCh, isInsert) {
  if (old) for (var i = 0,
      nw; i < old.length; ++i) {
    var span = old[i],
        marker = span.marker;
    var endsAfter = span.to == null || (marker.inclusiveRight ? span.to >= endCh
        : span.to > endCh);
    if (endsAfter || span.from == endCh && marker.type == "bookmark" &&
        (!isInsert || span.marker.insertLeft)) {
      var startsBefore = span.from == null || (marker.inclusiveLeft ? span.from
          <= endCh : span.from < endCh);
      (nw || (nw = [])).push(new MarkedSpan(marker, startsBefore ? null :
          span.from - endCh, span.to == null ? null : span.to - endCh));
    }
  }
  return nw;
}

stretchSpansOverChange(doc, change) {
  var oldFirst = isLine(doc, change.from.line) && getLine(doc, change.from.line
      ).markedSpans;
  var oldLast = isLine(doc, change.to.line) && getLine(doc, change.to.line
      ).markedSpans;
  if (!oldFirst && !oldLast) return null;

  var startCh = change.from.ch,
      endCh = change.to.ch,
      isInsert = cmp(change.from, change.to) == 0;

  var first = markedSpansBefore(oldFirst, startCh, isInsert);
  var last = markedSpansAfter(oldLast, endCh, isInsert);


  var sameLine = change.text.length == 1,
      offset = lst(change.text).length + (sameLine ? startCh : 0);
  if (first) {

    for (var i = 0; i < first.length; ++i) {
      var span = first[i];
      if (span.to == null) {
        var found = getMarkedSpanFor(last, span.marker);
        if (!found) {
          span.to = startCh;
        } else if (sameLine) span.to = found.to == null ? null : found.to +
            offset;
      }
    }
  }
  if (last) {

    for (var i = 0; i < last.length; ++i) {
      var span = last[i];
      if (span.to != null) span.to += offset;
      if (span.from == null) {
        var found = getMarkedSpanFor(first, span.marker);
        if (!found) {
          span.from = offset;
          if (sameLine) (first || (first = [])).push(span);
        }
      } else {
        span.from += offset;
        if (sameLine) (first || (first = [])).push(span);
      }
    }
  }

  if (first) first = clearEmptySpans(first);
  if (last && last != first) last = clearEmptySpans(last);

  var newMarkers = [first];
  if (!sameLine) {

    var gap = change.text.length - 2,
        gapMarkers;
    if (gap > 0 && first) for (var i = 0; i < first.length; ++i) if (first[i].to
        == null) (gapMarkers || (gapMarkers = [])).push(new MarkedSpan(first[i].marker,
        null, null));
    for (var i = 0; i < gap; ++i) newMarkers.push(gapMarkers);
    newMarkers.push(last);
  }
  return newMarkers;
}

clearEmptySpans(spans) {
  for (var i = 0; i < spans.length; ++i) {
    var span = spans[i];
    if (span.from != null && span.from == span.to && span.marker.clearWhenEmpty
        != false) spans.splice(i--, 1);
  }
  if (!spans.length) return null;
  return spans;
}

mergeOldSpans(doc, change) {
  var old = getOldSpans(doc, change);
  var stretched = stretchSpansOverChange(doc, change);
  if (!old) return stretched;
  if (!stretched) return old;

  for (var i = 0; i < old.length; ++i) {
    var oldCur = old[i],
        stretchCur = stretched[i];
    if (oldCur && stretchCur) {
      spans: for (var j = 0; j < stretchCur.length; ++j) {
        var span = stretchCur[j];
        for (var k = 0; k < oldCur.length; ++k) if (oldCur[k].marker ==
            span.marker) continue spans;
        oldCur.push(span);
      }
    } else if (stretchCur) {
      old[i] = stretchCur;
    }
  }
  return old;
}

removeReadOnlyRanges(doc, from, to) {
  var markers = null;
  doc.iter(from.line, to.line + 1, (line) {
    if (line.markedSpans) for (var i = 0; i < line.markedSpans.length; ++i) {
      var mark = line.markedSpans[i].marker;
      if (mark.readOnly && (!markers || indexOf(markers, mark) == -1)) (markers
          || (markers = [])).push(mark);
    }
  });
  if (!markers) return null;
  var parts = [{
      from: from,
      to: to
    }];
  for (var i = 0; i < markers.length; ++i) {
    var mk = markers[i],
        m = mk.find(0);
    for (var j = 0; j < parts.length; ++j) {
      var p = parts[j];
      if (cmp(p.to, m.from) < 0 || cmp(p.from, m.to) > 0) continue;
      var newParts = [j, 1],
          dfrom = cmp(p.from, m.from),
          dto = cmp(p.to, m.to);
      if (dfrom < 0 || !mk.inclusiveLeft && !dfrom) newParts.push({
        from: p.from,
        to: m.from
      });
      if (dto > 0 || !mk.inclusiveRight && !dto) newParts.push({
        from: m.to,
        to: p.to
      });
      parts.splice.apply(parts, newParts);
      j += newParts.length - 1;
    }
  }
  return parts;
}

detachMarkedSpans(line) {
  var spans = line.markedSpans;
  if (!spans) return;
  for (var i = 0; i < spans.length; ++i) spans[i].marker.detachLine(line);
  line.markedSpans = null;
}

attachMarkedSpans(line, spans) {
  if (!spans) return;
  for (var i = 0; i < spans.length; ++i) spans[i].marker.attachLine(line);
  line.markedSpans = spans;
}
