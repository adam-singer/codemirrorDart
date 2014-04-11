part of codemirror.dart;

updateLineWidgets(lineView, dims) {
  if (lineView.alignable) lineView.alignable = null;
  for (var node = lineView.node.firstChild,
      next; node; node = next) {
    var next = node.nextSibling;
    if (node.className == "CodeMirror-linewidget") lineView.node.removeChild(
        node);
  }
  insertLineWidgets(lineView, dims);
}

buildLineElement(cm, lineView, lineN, dims) {
  var built = getLineContent(cm, lineView);
  lineView.text = lineView.node = built.pre;
  if (built.bgClass) lineView.bgClass = built.bgClass;
  if (built.textClass) lineView.textClass = built.textClass;

  updateLineClasses(lineView);
  updateLineGutter(cm, lineView, lineN, dims);
  insertLineWidgets(lineView, dims);
  return lineView.node;
}

insertLineWidgets(lineView, dims) {
  insertLineWidgetsFor(lineView.line, lineView, dims, true);
  if (lineView.rest) for (var i = 0; i < lineView.rest.length; i++)
      insertLineWidgetsFor(lineView.rest[i], lineView, dims, false);
}

insertLineWidgetsFor(line, lineView, dims, allowAbove) {
  if (!line.widgets) return;
  var wrap = ensureLineWrapped(lineView);
  for (var i = 0,
      ws = line.widgets; i < ws.length; ++i) {
    var widget = ws[i],
        node = elt("div", [widget.node], "CodeMirror-linewidget");
    if (!widget.handleMouseEvents) node.ignoreEvents = true;
    positionLineWidget(widget, node, lineView, dims);
    if (allowAbove && widget.above) {
      wrap.insertBefore(node, lineView.gutter || lineView.text);
    } else {
      wrap.appendChild(node);
    }
    signalLater(widget, "redraw");
  }
}

positionLineWidget(widget, node, lineView, dims) {
  if (widget.noHScroll) {
    (lineView.alignable || (lineView.alignable = [])).push(node);
    var width = dims.wrapperWidth;
    node.style.left = dims.fixedPos + "px";
    if (!widget.coverGutter) {
      width -= dims.gutterTotalWidth;
      node.style.paddingLeft = dims.gutterTotalWidth + "px";
    }
    node.style.width = width + "px";
  }
  if (widget.coverGutter) {
    node.style.zIndex = 5;
    node.style.position = "relative";
    if (!widget.noHScroll) node.style.marginLeft = -dims.gutterTotalWidth +
        "px";
  }
}

copyPos(x) {
  return newPos(x.line, x.ch);
}

maxPos(a, b) {
  return cmp(a, b) < 0 ? b : a;
}

minPos(a, b) {
  return cmp(a, b) < 0 ? a : b;
}



normalizeSelection(ranges, primIndex) {
  var prim = ranges[primIndex];
  ranges.sort((a, b) {
    return cmp(a.from(), b.from());
  });
  primIndex = indexOf(ranges, prim);
  for (var i = 1; i < ranges.length; i++) {
    var cur = ranges[i],
        prev = ranges[i - 1];
    if (cmp(prev.to(), cur.from()) >= 0) {
      var from = minPos(prev.from(), cur.from()),
          to = maxPos(prev.to(), cur.to());
      var inv = prev.empty() ? cur.from() == cur.head : prev.from() ==
          prev.head;
      if (i <= primIndex) --primIndex;
      ranges.splice(--i, 2, new Range(inv ? to : from, inv ? from : to));
    }
  }
  return new Selection(ranges, primIndex);
}

simpleSelection(anchor, [head]) {
  if (head == null) head = anchor;
  return new Selection([new Range(anchor, head)], 0);
}

clipLine(doc, n) {
  return math.max(doc.first, math.min(n, doc.first + doc.size - 1));
}

_clipPos(doc, pos) {
  if (pos.line < doc.first) return newPos(doc.first, 0);
  var last = doc.first + doc.size - 1;
  if (pos.line > last) return newPos(last, getLine(doc, last).text.length);
  return clipToLen(pos, getLine(doc, pos.line).text.length);
}

clipToLen(pos, linelen) {
  var ch = pos.ch;
  if (ch == null || ch > linelen) {
    return newPos(pos.line, linelen);
  } else if (ch < 0) {
    return newPos(pos.line, 0);
  } else {
    return pos;
  }
}

isLine(doc, l) {
  return l >= doc.first && l < doc.first + doc.size;
}

clipPosArray(doc, array) {
  var out = [];
  for (var i = 0; i < array.length; i++) out[i] = _clipPos(doc, array[i]);
  return out;
}

extendRange(doc, range, head, [other]) {
  if (doc.cm && doc.cm.display.shift || doc.extend) {
    var anchor = range.anchor;
    if (other) {
      var posBefore = cmp(head, anchor) < 0;
      if (posBefore != (cmp(other, anchor) < 0)) {
        anchor = head;
        head = other;
      } else if (posBefore != (cmp(head, other) < 0)) {
        head = other;
      }
    }
    return new Range(anchor, head);
  } else {
    return new Range(other || head, head);
  }
}

extendSelection(doc, head, [other, options]) {
  _setSelection(doc, new Selection([extendRange(doc, doc.sel.primary(), head,
      other)], 0), options);
}

extendSelections(doc, heads, options) {
  var out = [];
  for (var i = 0; i < doc.sel.ranges.length; i++) out[i] = extendRange(doc,
          doc.sel.ranges[i], heads[i], null);
  var newSel = normalizeSelection(out, doc.sel.primIndex);
  _setSelection(doc, newSel, options);
}

replaceOneSelection(doc, i, range, options) {
  var ranges = doc.sel.ranges.slice(0);
  ranges[i] = range;
  _setSelection(doc, normalizeSelection(ranges, doc.sel.primIndex), options);
}

setSimpleSelection(doc, anchor, head, options) {
  _setSelection(doc, simpleSelection(anchor, head), options);
}

filterSelectionChange(doc, sel) {
  var obj = {
    'ranges': sel.ranges,
    'update': (ranges) {
      var that; // this
      that.ranges = [];
      for (var i = 0; i < ranges.length; i++) that.ranges[i] = new Range(
          _clipPos(doc, ranges[i].anchor), _clipPos(doc, ranges[i].head));
    }
  };
  signal(doc, "beforeSelectionChange", doc, obj);
  if (doc.cm) signal(doc.cm, "beforeSelectionChange", doc.cm, obj);
  if (obj.ranges != sel.ranges) {
    return normalizeSelection(obj.ranges, obj.ranges.length - 1);
  } else {
    return sel;
  }
}

setSelectionReplaceHistory(doc, sel, [options]) {
  var done = doc.history.done,
      last = lst(done);
  if (last && last.ranges) {
    done[done.length - 1] = sel;
    setSelectionNoUndo(doc, sel, options);
  } else {
    _setSelection(doc, sel, options);
  }
}

_setSelection(doc, sel, options) {
  if (options && options.origin && doc.cm) doc.cm.curOp.origin = options.origin;
  setSelectionNoUndo(doc, sel, options);
  addSelectionToHistory(doc, doc.sel, doc.cm ? doc.cm.curOp.id : double.NAN, options);
}

setSelectionNoUndo(doc, sel, options) {
  if (hasHandler(doc, "beforeSelectionChange") || doc.cm && hasHandler(doc.cm,
      "beforeSelectionChange")) sel = filterSelectionChange(doc, sel);

  var bias = cmp(sel.primary().head, doc.sel.primary().head) < 0 ? -1 : 1;
  setSelectionInner(doc, skipAtomicInSelection(doc, sel, bias, true));

  if (!(options && options.scroll == false) && doc.cm) ensureCursorVisible(
      doc.cm);
}

setSelectionInner(doc, sel) {
  if (sel.equals(doc.sel)) return;

  doc.sel = sel;

  if (doc.cm) doc.cm.curOp.updateInput = doc.cm.curOp.selectionChanged =
      doc.cm.curOp.cursorActivity = true;
  signalLater(doc, "cursorActivity", doc);
}

reCheckSelection(doc) {
  setSelectionInner(doc, skipAtomicInSelection(doc, doc.sel, null, false),
      sel_dontScroll);
}

skipAtomicInSelection(doc, sel, bias, mayClear) {
  var out;
  for (var i = 0; i < sel.ranges.length; i++) {
    var range = sel.ranges[i];
    var newAnchor = skipAtomic(doc, range.anchor, bias, mayClear);
    var newHead = skipAtomic(doc, range.head, bias, mayClear);
    if (out || newAnchor != range.anchor || newHead != range.head) {
      if (!out) out = sel.ranges.slice(0, i);
      out[i] = new Range(newAnchor, newHead);
    }
  }
  return out ? normalizeSelection(out, sel.primIndex) : sel;
}

skipAtomic(doc, pos, bias, mayClear) {
  var flipped = false,
      curPos = pos;
  var dir = bias || 1;
  doc.cantEdit = false;
  search: for ( ; ; ) {
    var line = getLine(doc, curPos.line);
    if (line.markedSpans) {
      for (var i = 0; i < line.markedSpans.length; ++i) {
        var sp = line.markedSpans[i],
            m = sp.marker;
        if ((sp.from == null || (m.inclusiveLeft ? sp.from <= curPos.ch :
            sp.from < curPos.ch)) && (sp.to == null || (m.inclusiveRight ? sp.to >=
            curPos.ch : sp.to > curPos.ch))) {
          if (mayClear) {
            signal(m, "beforeCursorEnter");
            if (m.explicitlyCleared) {
              if (!line.markedSpans) {
                break;
              } else {
                --i;
                continue;
              }
            }
          }
          if (!m.atomic) continue;
          var newPos = m.find(dir < 0 ? -1 : 1);
          if (cmp(newPos, curPos) == 0) {
            newPos.ch += dir;
            if (newPos.ch < 0) {
              if (newPos.line > doc.first) {
                newPos = _clipPos(doc, newPos(newPos.line - 1));
              } else {
                newPos = null;
              }
            } else if (newPos.ch > line.text.length) {
              if (newPos.line < doc.first + doc.size - 1) {
                newPos = newPos(newPos.line + 1, 0);
              } else {
                newPos = null;
              }
            }
            if (!newPos) {
              if (flipped) {


                if (!mayClear) return skipAtomic(doc, pos, bias, true);

                doc.cantEdit = true;
                return newPos(doc.first, 0);
              }
              flipped = true;
              newPos = pos;
              dir = -dir;
            }
          }
          curPos = newPos;
          continue search;
        }
      }
    }
    return curPos;
  }
}

updateSelection(cm) {
  var display = cm.display,
      doc = cm.doc;
  var curFragment = document.createDocumentFragment();
  var selFragment = document.createDocumentFragment();

  for (var i = 0; i < doc.sel.ranges.length; i++) {
    var range = doc.sel.ranges[i];
    var collapsed = range.empty();
    if (collapsed || cm.options.showCursorWhenSelecting) drawSelectionCursor(cm,
        range, curFragment);
    if (!collapsed) drawSelectionRange(cm, range, selFragment);
  }


  if (cm.options.moveInputWithCursor) {
    var headPos = cursorCoords(cm, doc.sel.primary().head, "div");
    var wrapOff = display.wrapper.getBoundingClientRect(),
        lineOff = display.lineDiv.getBoundingClientRect();
    var top = math.max(0, math.min(display.wrapper.clientHeight - 10,
        headPos.top + lineOff.top - wrapOff.top));
    var left = math.max(0, math.min(display.wrapper.clientWidth - 10,
        headPos.left + lineOff.left - wrapOff.left));
    display.inputDiv.style.top = top + "px";
    display.inputDiv.style.left = left + "px";
  }

  removeChildrenAndAdd(display.cursorDiv, curFragment);
  removeChildrenAndAdd(display.selectionDiv, selFragment);
}

drawSelectionCursor(cm, range, output) {
  var pos = cursorCoords(cm, range.head, "div");

  var cursor = output.appendChild(elt("div", "\u00a0", "CodeMirror-cursor"));
  cursor.style.left = pos.left + "px";
  cursor.style.top = pos.top + "px";
  cursor.style.height = (math.max(0, pos.bottom - pos.top) *
      cm.options.cursorHeight).toString() + "px";

  if (pos.other) {

    var otherCursor = output.appendChild(elt("div", "\u00a0",
        "CodeMirror-cursor CodeMirror-secondarycursor"));
    otherCursor.style.display = "";
    otherCursor.style.left = pos.other.left + "px";
    otherCursor.style.top = pos.other.top + "px";
    otherCursor.style.height = (pos.other.bottom - pos.other.top) * .85 + "px";
  }
}

drawSelectionRange(cm, range, output) {
  var display = cm.display,
      doc = cm.doc;
  var fragment = document.createDocumentFragment();
  var padding = paddingH(cm.display),
      leftSide = padding.left,
      rightSide = display.lineSpace.offsetWidth - padding.right;

  add(left, top, width, bottom) {
    if (top < 0) top = 0;
    top = top.round();
    bottom = bottom.round();
    fragment.appendChild(elt("div", null, "CodeMirror-selected",
        "position: absolute; left: " + left + "px; top: " + top + "px; width: " + (width
        == null ? rightSide - left : width) + "px; height: " + (bottom - top) + "px"));
  }

  drawForLine(line, fromArg, toArg) {
    var lineObj = getLine(doc, line);
    var lineLen = lineObj.text.length;
    var start, end;
    coords(ch, bias) {
      return charCoords(cm, newPos(line, ch), "div", lineObj, bias);
    }

    iterateBidiSections(getOrder(lineObj), fromArg || 0, toArg == null ? lineLen
        : toArg, (from, to, dir) {
      var leftPos = coords(from, "left"),
          rightPos,
          left,
          right;
      if (from == to) {
        rightPos = leftPos;
        left = right = leftPos.left;
      } else {
        rightPos = coords(to - 1, "right");
        if (dir == "rtl") {
          var tmp = leftPos;
          leftPos = rightPos;
          rightPos = tmp;
        }
        left = leftPos.left;
        right = rightPos.right;
      }
      if (fromArg == null && from == 0) left = leftSide;
      if (rightPos.top - leftPos.top > 3) {
        add(left, leftPos.top, null, leftPos.bottom);
        left = leftSide;
        if (leftPos.bottom < rightPos.top) add(left, leftPos.bottom, null,
            rightPos.top);
      }
      if (toArg == null && to == lineLen) right = rightSide;
      if (!start || leftPos.top < start.top || leftPos.top == start.top &&
          leftPos.left < start.left) start = leftPos;
      if (!end || rightPos.bottom > end.bottom || rightPos.bottom == end.bottom
          && rightPos.right > end.right) end = rightPos;
      if (left < leftSide + 1) left = leftSide;
      add(left, rightPos.top, right - left, rightPos.bottom);
    });
    return {
      start: start,
      end: end
    };
  }

  var sFrom = range.from(),
      sTo = range.to();
  if (sFrom.line == sTo.line) {
    drawForLine(sFrom.line, sFrom.ch, sTo.ch);
  } else {
    var fromLine = getLine(doc, sFrom.line),
        toLine = getLine(doc, sTo.line);
    var singleVLine = visualLine(fromLine) == visualLine(toLine);
    var leftEnd = drawForLine(sFrom.line, sFrom.ch, singleVLine ?
        fromLine.text.length + 1 : null).end;
    var rightStart = drawForLine(sTo.line, singleVLine ? 0 : null, sTo.ch
        ).start;
    if (singleVLine) {
      if (leftEnd.top < rightStart.top - 2) {
        add(leftEnd.right, leftEnd.top, null, leftEnd.bottom);
        add(leftSide, rightStart.top, rightStart.left, rightStart.bottom);
      } else {
        add(leftEnd.right, leftEnd.top, rightStart.left - leftEnd.right,
            leftEnd.bottom);
      }
    }
    if (leftEnd.bottom < rightStart.top) add(leftSide, leftEnd.bottom, null,
        rightStart.top);
  }

  output.appendChild(fragment);
}

restartBlink(cm) {
  if (!cm.state.focused) return;
  var display = cm.display;
  clearInterval(display.blinker);
  var on = true;
  display.cursorDiv.style.visibility = "";
  if (cm.options.cursorBlinkRate > 0) display.blinker = setInterval(() {
    display.cursorDiv.style.visibility = (on = !on) ? "" : "hidden";
  }, cm.options.cursorBlinkRate);
}

startWorker(cm, time) {
  if (cm.doc.mode.startState && cm.doc.frontier < cm.display.viewTo)
      cm.state.highlight.set(time, bind(highlightWorker, cm));
}

highlightWorker(cm) {
  var doc = cm.doc;
  if (doc.frontier < doc.first) doc.frontier = doc.first;
  if (doc.frontier >= cm.display.viewTo) return;
  var end = currentTimeInMs() + cm.options.workTime;
  var state = copyState(doc.mode, getStateBefore(cm, doc.frontier));

  runInOp(cm, () {
    doc.iter(doc.frontier, math.min(doc.first + doc.size, cm.display.viewTo +
        500), (line) {
      if (doc.frontier >= cm.display.viewFrom) {
        var oldStyles = line.styles;
        var highlighted = highlightLine(cm, line, state, true);
        line.styles = highlighted.styles;
        if (highlighted.classes) {
          line.styleClasses = highlighted.classes;
        } else if (line.styleClasses) line.styleClasses = null;
        var ischange = !oldStyles || oldStyles.length != line.styles.length;
        for (var i = 0; !ischange && i < oldStyles.length; ++i) ischange =
            oldStyles[i] != line.styles[i];
        if (ischange) regLineChange(cm, doc.frontier, "text");
        line.stateAfter = copyState(doc.mode, state);
      } else {
        processLine(cm, line.text, state);
        line.stateAfter = doc.frontier % 5 == 0 ? copyState(doc.mode, state) :
            null;
      }
      ++doc.frontier;
      if (currentTimeInMs() > end) {
        startWorker(cm, cm.options.workDelay);
        return true;
      }
    });
  });
}

findStartLine(cm, n, precise) {
  var minindent,
      minline,
      doc = cm.doc;
  var lim = precise ? -1 : n - (cm.doc.mode.innerMode ? 1000 : 100);
  for (var search = n; search > lim; --search) {
    if (search <= doc.first) return doc.first;
    var line = getLine(doc, search - 1);
    if (line.stateAfter && (!precise || search <= doc.frontier)) return search;
    var indented = countColumn(line.text, null, cm.options.tabSize);
    if (minline == null || minindent > indented) {
      minline = search - 1;
      minindent = indented;
    }
  }
  return minline;
}

getStateBefore(cm, n, [precise]) {
  var doc = cm.doc,
      display = cm.display;
  if (!doc.mode.startState) return true;
  var pos = findStartLine(cm, n, precise),
      state = pos > doc.first && getLine(doc, pos - 1).stateAfter;
  if (!state) {
    state = startState(doc.mode);
  } else {
    state = copyState(doc.mode, state);
  }
  doc.iter(pos, n, (line) {
    processLine(cm, line.text, state);
    var save = pos == n - 1 || pos % 5 == 0 || pos >= display.viewFrom && pos <
        display.viewTo;
    line.stateAfter = save ? copyState(doc.mode, state) : null;
    ++pos;
  });
  if (precise) doc.frontier = pos;
  return state;
}

paddingTop(display) {
  return display.lineSpace.offsetTop;
}

paddingVert(display) {
  return display.mover.offsetHeight - display.lineSpace.offsetHeight;
}

paddingH(display) {
  if (display.cachedPaddingH) return display.cachedPaddingH;
  var e = removeChildrenAndAdd(display.measure, elt("pre", "x"));
  var style = window.getComputedStyle ? window.getComputedStyle(e) :
      e.currentStyle;
  return display.cachedPaddingH = {
    'left': parseInt(style.paddingLeft),
    'right': parseInt(style.paddingRight)
  };
}

ensureLineHeights(cm, lineView, rect) {
  var wrapping = cm.options.lineWrapping;
  var curWidth = wrapping && cm.display.scroller.clientWidth;
  if (!lineView.measure.heights || wrapping && lineView.measure.width !=
      curWidth) {
    var heights = lineView.measure.heights = [];
    if (wrapping) {
      lineView.measure.width = curWidth;
      var rects = lineView.text.firstChild.getClientRects();
      for (var i = 0; i < rects.length - 1; i++) {
        var cur = rects[i],
            next = rects[i + 1];
        if ((cur.bottom - next.bottom).abs() > 2) heights.push((cur.bottom +
            next.top) / 2 - rect.top);
      }
    }
    heights.push(rect.bottom - rect.top);
  }
}

mapFromLineView(lineView, line, lineN) {
  if (lineView.line == line) return {
    'map': lineView.measure.map,
    'cache': lineView.measure.cache
  };
  for (var i = 0; i < lineView.rest.length; i++) if (lineView.rest[i] == line)
      return {
    'map': lineView.measure.maps[i],
    'cache': lineView.measure.caches[i]
  };
  for (var i = 0; i < lineView.rest.length; i++) if (_lineNo(lineView.rest[i]) >
      lineN) return {
    'map': lineView.measure.maps[i],
    'cache': lineView.measure.caches[i],
    'before': true
  };
}

updateExternalMeasurement(cm, line) {
  line = visualLine(line);
  var lineN = _lineNo(line);
  var view = cm.display.externalMeasured = new LineView(cm.doc, line, lineN);
  view.lineN = lineN;
  var built = view.built = buildLineContent(cm, view);
  view.text = built.pre;
  removeChildrenAndAdd(cm.display.lineMeasure, built.pre);
  return view;
}

measureChar(cm, line, ch, [bias]) {
  return measureCharPrepared(cm, prepareMeasureForLine(cm, line), ch, bias);
}

findViewForLine(cm, lineN) {
  if (lineN >= cm.display.viewFrom && lineN < cm.display.viewTo) return
      cm.display.view[findViewIndex(cm, lineN)];
  var ext = cm.display.externalMeasured;
  if (ext && lineN >= ext.lineN && lineN < ext.lineN + ext.size) return ext;
}

prepareMeasureForLine(cm, line) {
  var lineN = _lineNo(line);
  var view = findViewForLine(cm, lineN);
  if (view && !view.text) {
    view = null;
  } else if (view && view.changes) updateLineForChanges(cm, view, lineN,
      getDimensions(cm));
  if (!view) view = updateExternalMeasurement(cm, line);

  var info = mapFromLineView(view, line, lineN);
  return {
    'line': line,
    'view': view,
    'rect': null,
    'map': info.map,
    'cache': info.cache,
    'before': info.before,
    'hasHeights': false
  };
}

measureCharPrepared(cm, prepared, ch, bias) {
  if (prepared.before) ch = -1;
  var key = ch + (bias || ""),
      found;
  if (prepared.cache.hasOwnProperty(key)) {
    found = prepared.cache[key];
  } else {
    if (!prepared.rect) prepared.rect =
        prepared.view.text.getBoundingClientRect();
    if (!prepared.hasHeights) {
      ensureLineHeights(cm, prepared.view, prepared.rect);
      prepared.hasHeights = true;
    }
    found = measureCharInner(cm, prepared, ch, bias);
    if (!found.bogus) prepared.cache[key] = found;
  }
  return {
    'left': found.left,
    'right': found.right,
    'top': found.top,
    'bottom': found.bottom
  };
}

measureCharInner(cm, prepared, ch, bias) {
  var map = prepared.map;

  var node, start, end, collapse;
  var mStart, mEnd;


  for (var i = 0; i < map.length; i += 3) {
    mStart = map[i];
    mEnd = map[i + 1];
    if (ch < mStart) {
      start = 0;
      end = 1;
      collapse = "left";
    } else if (ch < mEnd) {
      start = ch - mStart;
      end = start + 1;
    } else if (i == map.length - 3 || ch == mEnd && map[i + 3] > ch) {
      end = mEnd - mStart;
      start = end - 1;
      if (ch >= mEnd) collapse = "right";
    }
    if (start != null) {
      node = map[i + 2];
      if (mStart == mEnd && bias == (node.insertLeft ? "left" : "right"))
          collapse = bias;
      if (bias == "left" && start == 0) while (i && map[i - 2] == map[i - 3] &&
          map[i - 1].insertLeft) {
        node = map[(i -= 3) + 2];
        collapse = "left";
      }
      if (bias == "right" && start == mEnd - mStart) while (i < map.length - 3
          && map[i + 3] == map[i + 4] && !map[i + 5].insertLeft) {
        node = map[(i += 3) + 2];
        collapse = "right";
      }
      break;
    }
  }

  var rect;
  if (node.nodeType == 3) {
    while (start && isExtendingChar(prepared.line.text.charAt(mStart + start)))
        --start;
    while (mStart + end < mEnd && isExtendingChar(prepared.line.text.charAt(
        mStart + end))) ++end;
    if (ie_upto8 && start == 0 && end == mEnd - mStart) {
      rect = node.parentNode.getBoundingClientRect();
    } else if (ie && cm.options.lineWrapping) {
      var rects = range(node, start, end).getClientRects();
      if (rects.length) {
        rect = rects[bias == "right" ? rects.length - 1 : 0];
      } else {
        rect = nullRect;
      }
    } else {
      rect = range(node, start, end).getBoundingClientRect();
    }
  } else {
    if (start > 0) collapse = bias = "right";
    var rects;
    if (cm.options.lineWrapping && (rects = node.getClientRects()).length > 1) {
      rect = rects[bias == "right" ? rects.length - 1 : 0];
    } else {
      rect = node.getBoundingClientRect();
    }
  }
  if (ie_upto8 && !start && (!rect || !rect.left && !rect.right)) {
    var rSpan = node.parentNode.getClientRects()[0];
    if (rSpan) {
      rect = {
        'left': rSpan.left,
        'right': rSpan.left + charWidth(cm.display),
        'top': rSpan.top,
        'bottom': rSpan.bottom
      };
    } else {
      rect = nullRect;
    }
  }

  var top,
      bot = (rect.bottom + rect.top) / 2 - prepared.rect.top;
  var heights = prepared.view.measure.heights;
  var i = 0;
  for (; i < heights.length - 1; i++) if (bot < heights[i]) break;
  top = i ? heights[i - 1] : 0;
  bot = heights[i];
  var result = {
    'left': (collapse == "right" ? rect.right : rect.left) - prepared.rect.left,
    'right': (collapse == "left" ? rect.left : rect.right) - prepared.rect.left,
    'top': top,
    'bottom': bot
  };
  if (!rect.left && !rect.right) result.bogus = true;
  return result;
}

clearLineMeasurementCacheFor(lineView) {
  if (lineView.measure) {
    lineView.measure.cache = {};
    lineView.measure.heights = null;
    if (lineView.rest) for (var i = 0; i < lineView.rest.length; i++)
        lineView.measure.caches[i] = {};
  }
}

clearLineMeasurementCache(cm) {
  cm.display.externalMeasure = null;
  removeChildren(cm.display.lineMeasure);
  for (var i = 0; i < cm.display.view.length; i++) clearLineMeasurementCacheFor(
      cm.display.view[i]);
}

clearCaches(cm) {
  clearLineMeasurementCache(cm);
  cm.display.cachedCharWidth = cm.display.cachedTextHeight =
      cm.display.cachedPaddingH = null;
  if (!cm.options.lineWrapping) cm.display.maxLineChanged = true;
  cm.display.lineNumChars = null;
}

pageScrollX() {
  return window.pageXOffset || (document.documentElement ||
      document.body).scrollLeft;
}

pageScrollY() {
  return window.pageYOffset || (document.documentElement ||
      document.body).scrollTop;
}

intoCoordSystem(cm, lineObj, rect, context) {
  if (lineObj.widgets) for (var i = 0; i < lineObj.widgets.length; ++i) if
      (lineObj.widgets[i].above) {
    var size = widgetHeight(lineObj.widgets[i]);
    rect.top += size;
    rect.bottom += size;
  }
  if (context == "line") return rect;
  if (!context) context = "local";
  var yOff = heightAtLine(lineObj);
  if (context == "local") {
    yOff += paddingTop(cm.display);
  } else {
    yOff -= cm.display.viewOffset;
  }
  if (context == "page" || context == "window") {
    var lOff = cm.display.lineSpace.getBoundingClientRect();
    yOff += lOff.top + (context == "window" ? 0 : pageScrollY());
    var xOff = lOff.left + (context == "window" ? 0 : pageScrollX());
    rect.left += xOff;
    rect.right += xOff;
  }
  rect.top += yOff;
  rect.bottom += yOff;
  return rect;
}

fromCoordSystem(cm, coords, context) {
  if (context == "div") return coords;
  var left = coords.left,
      top = coords.top;

  if (context == "page") {
    left -= pageScrollX();
    top -= pageScrollY();
  } else if (context == "local" || !context) {
    var localBox = cm.display.sizer.getBoundingClientRect();
    left += localBox.left;
    top += localBox.top;
  }

  var lineSpaceBox = cm.display.lineSpace.getBoundingClientRect();
  return {
    left: left - lineSpaceBox.left,
    top: top - lineSpaceBox.top
  };
}

charCoords(cm, pos, context, lineObj, bias) {
  if (!lineObj) lineObj = getLine(cm.doc, pos.line);
  return intoCoordSystem(cm, lineObj, measureChar(cm, lineObj, pos.ch, bias),
      context);
}
