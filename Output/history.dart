part of codemirror.dart;

class History {
  var done;
  var undone;
  var undoDepth;
  var lastModTime;
  var lastSelTime;
  var lastOp;
  var lastOrigin;
  var lastSelOrigin;
  var generation;
  var maxGeneration;

  History(startGen) {
    this.done = [];
    this.undone = [];
    this.undoDepth = Infinity;


    this.lastModTime = this.lastSelTime = 0;
    this.lastOp = null;
    this.lastOrigin = this.lastSelOrigin = null;

    this.generation = this.maxGeneration = startGen || 1;
  }
}

historyChangeFromChange(doc, change) {
  var histChange = {
    'from': copyPos(change.from),
    'to': changeEnd(change),
    'text': getBetween(doc, change.from, change.to)
  };
  attachLocalSpans(doc, histChange, change.from.line, change.to.line + 1);
  linkedDocs(doc, (doc) {
    attachLocalSpans(doc, histChange, change.from.line, change.to.line + 1);
  }, true);
  return histChange;
}

clearSelectionEvents(array) {
  while (array.length) {
    var last = lst(array);
    if (last.ranges) {
      array.pop();
    } else {
      break;
    }
  }
}

lastChangeEvent(hist, force) {
  if (force) {
    clearSelectionEvents(hist.done);
    return lst(hist.done);
  } else if (hist.done.length && !lst(hist.done).ranges) {
    return lst(hist.done);
  } else if (hist.done.length > 1 && !hist.done[hist.done.length - 2].ranges) {
    hist.done.pop();
    return lst(hist.done);
  }
}

addChangeToHistory(doc, change, selAfter, opId) {
  var hist = doc.history;
  hist.undone.length = 0;
  var time = currentTimeInMs(),
      cur;

  if ((hist.lastOp == opId || hist.lastOrigin == change.origin && change.origin
      && ((change.origin.charAt(0) == "+" && doc.cm && hist.lastModTime > time -
      doc.cm.options.historyEventDelay) || change.origin.charAt(0) == "*")) && (cur =
      lastChangeEvent(hist, hist.lastOp == opId))) {

    var last = lst(cur.changes);
    if (cmp(change.from, change.to) == 0 && cmp(change.from, last.to) == 0) {


      last.to = changeEnd(change);
    } else {

      cur.changes.push(historyChangeFromChange(doc, change));
    }
  } else {

    var before = lst(hist.done);
    if (!before || !before.ranges) pushSelectionToHistory(doc.sel, hist.done);
    cur = {
      changes: [historyChangeFromChange(doc, change)],
      generation: hist.generation
    };
    hist.done.push(cur);
    while (hist.done.length > hist.undoDepth) {
      hist.done.shift();
      if (!hist.done[0].ranges) hist.done.shift();
    }
  }
  hist.done.push(selAfter);
  hist.generation = ++hist.maxGeneration;
  hist.lastModTime = hist.lastSelTime = time;
  hist.lastOp = opId;
  hist.lastOrigin = hist.lastSelOrigin = change.origin;

  if (!last) signal(doc, "historyAdded");
}

selectionEventCanBeMerged(doc, origin, prev, sel) {
  var ch = origin.charAt(0);
  return ch == "*" || ch == "+" && prev.ranges.length == sel.ranges.length &&
      prev.somethingSelected() == sel.somethingSelected() && new Date() -
      doc.history.lastSelTime <= (doc.cm ? doc.cm.options.historyEventDelay : 500);
}

addSelectionToHistory(doc, sel, opId, options) {
  var hist = doc.history,
      origin = options && options.origin;





  if (opId == hist.lastOp || (origin && hist.lastSelOrigin == origin &&
      (hist.lastModTime == hist.lastSelTime && hist.lastOrigin == origin ||
      selectionEventCanBeMerged(doc, origin, lst(hist.done), sel)))) {
    hist.done[hist.done.length - 1] = sel;
  } else {
    pushSelectionToHistory(sel, hist.done);
  }
  hist.lastSelTime = currentTimeInMs();
  hist.lastSelOrigin = origin;
  hist.lastOp = opId;
  if (options && options.clearRedo != false) clearSelectionEvents(hist.undone);
}

pushSelectionToHistory(sel, dest) {
  var top = lst(dest);
  if (!(top && top.ranges && top.equals(sel))) dest.push(sel);
}

attachLocalSpans(doc, change, from, to) {
  var existing = change["spans_" + doc.id],
      n = 0;
  doc.iter(Math.max(doc.first, from), Math.min(doc.first + doc.size, to), (line)
      {
    if (line.markedSpans) (existing || (existing = change["spans_" + doc.id] =
        {}))[n] = line.markedSpans;
    ++n;
  });
}

removeClearedSpans(spans) {
  if (!spans) return null;
  for (var i = 0,
      out; i < spans.length; ++i) {
    if (spans[i].marker.explicitlyCleared) {
      if (!out) out = spans.slice(0, i);
    } else if (out) out.push(spans[i]);
  }
  return !out ? spans : out.length ? out : null;
}

getOldSpans(doc, change) {
  var found = change["spans_" + doc.id];
  if (!found) return null;
  for (var i = 0,
      nw = []; i < change.text.length; ++i) nw.push(removeClearedSpans(found[i])
          );
  return nw;
}

copyHistoryArray(events, [newGroup, instantiateSel]) {
  for (var i = 0,
      copy = []; i < events.length; ++i) {
    var event = events[i];
    if (event.ranges) {
      copy.push(instantiateSel ? Selection.prototype.deepCopy.call(event) :
          event);
      continue;
    }
    var changes = event.changes,
        newChanges = [];
    copy.push({
      changes: newChanges
    });
    for (var j = 0; j < changes.length; ++j) {
      var change = changes[j],
          m;
      newChanges.push({
        'from': change.from,
        'to': change.to,
        'text': change.text
      });
      if (newGroup) for (var prop in change) if (m = prop.match(new Refexp(
          "/^spans_(\d+)\$/"))) {
        if (indexOf(newGroup, Number(m[1])) > -1) {
          lst(newChanges)[prop] = change[prop];
          //XXX delete change[prop];
        }
      }
    }
  }
  return copy;
}

rebaseHistSelSingle(pos, from, to, diff) {
  if (to < pos.line) {
    pos.line += diff;
  } else if (from < pos.line) {
    pos.line = from;
    pos.ch = 0;
  }
}

rebaseHistArray(array, from, to, diff) {
  for (var i = 0; i < array.length; ++i) {
    var sub = array[i],
        ok = true;
    if (sub.ranges) {
      if (!sub.copied) {
        sub = array[i] = sub.deepCopy();
        sub.copied = true;
      }
      for (var j = 0; j < sub.ranges.length; j++) {
        rebaseHistSelSingle(sub.ranges[j].anchor, from, to, diff);
        rebaseHistSelSingle(sub.ranges[j].head, from, to, diff);
      }
      continue;
    }
    for (var j = 0; j < sub.changes.length; ++j) {
      var cur = sub.changes[j];
      if (to < cur.from.line) {
        cur.from = newPos(cur.from.line + diff, cur.from.ch);
        cur.to = newPos(cur.to.line + diff, cur.to.ch);
      } else if (from <= cur.to.line) {
        ok = false;
        break;
      }
    }
    if (!ok) {
      array.splice(0, i + 1);
      i = 0;
    }
  }
}

rebaseHist(hist, change) {
  var from = change.from.line,
      to = change.to.line,
      diff = change.text.length - (to - from) - 1;
  rebaseHistArray(hist.done, from, to, diff);
  rebaseHistArray(hist.undone, from, to, diff);
}
