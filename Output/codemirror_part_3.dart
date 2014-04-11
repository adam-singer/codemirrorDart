part of codemirror.dart;



cursorCoords(cm, pos, context, lineObj, preparedMeasure) {
  lineObj = lineObj || getLine(cm.doc, pos.line);
  if (!preparedMeasure) preparedMeasure = prepareMeasureForLine(cm, lineObj);
  get(ch, [right]) {
    var m = measureCharPrepared(cm, preparedMeasure, ch, right ? "right" :
        "left");
    if (right != null) {
      m.left = m.right;
    } else {
      m.right = m.left;
    }
    return intoCoordSystem(cm, lineObj, m, context);
  }
  var order;
  getBidi(ch, partPos) {
    var part = order[partPos],
        right = part.level % 2;
    if (ch == bidiLeft(part) && partPos && part.level < order[partPos -
        1].level) {
      part = order[--partPos];
      ch = bidiRight(part) - (part.level % 2 ? 0 : 1);
      right = true;
    } else if (ch == bidiRight(part) && partPos < order.length - 1 && part.level
        < order[partPos + 1].level) {
      part = order[++partPos];
      ch = bidiLeft(part) - part.level % 2;
      right = false;
    }
    if (right && ch == part.to && ch > part.from) return get(ch - 1);
    return get(ch, right);
  }
  order = getOrder(lineObj);
  var ch = pos.ch;
  if (!order) return get(ch);
  var partPos = getBidiPartAt(order, ch);
  var val = getBidi(ch, partPos);
  if (bidiOther != null) val.other = getBidi(ch, bidiOther);
  return val;
}

estimateCoords(cm, pos) {
  var left = 0;
  pos = _clipPos(cm.doc, pos);
  if (!cm.options.lineWrapping) left = charWidth(cm.display) * pos.ch;
  var lineObj = getLine(cm.doc, pos.line);
  var top = heightAtLine(lineObj) + paddingTop(cm.display);
  return {
    'left': left,
    'right': left,
    'top': top,
    'bottom': top + lineObj.height
  };
}

coordsChar(cm, x, y) {
  var doc = cm.doc;
  y += cm.display.viewOffset;
  if (y < 0) return new PosWithInfo(doc.first, 0, true, -1);
  var lineN = lineAtHeight(doc, y),
      last = doc.first + doc.size - 1;
  if (lineN > last) return new PosWithInfo(doc.first + doc.size - 1, getLine(
      doc, last).text.length, true, 1);
  if (x < 0) x = 0;

  var lineObj = getLine(doc, lineN);
  for ( ; ; ) {
    var found = coordsCharInner(cm, lineObj, lineN, x, y);
    var merged = collapsedSpanAtEnd(lineObj);
    var mergedPos = merged && merged.find(0, true);
    if (merged && (found.ch > mergedPos.from.ch || found.ch == mergedPos.from.ch
        && found.xRel > 0)) {
      lineN = _lineNo(lineObj = mergedPos.to.line);
    } else {
      return found;
    }
  }
}

coordsCharInner(cm, lineObj, lineNo, x, y) {
  var innerOff = y - heightAtLine(lineObj);
  var wrongLine = false,
      adjust = 2 * cm.display.wrapper.clientWidth;
  var preparedMeasure = prepareMeasureForLine(cm, lineObj);

  getX(ch) {
    var sp = cursorCoords(cm, newPos(lineNo, ch), "line", lineObj,
        preparedMeasure);
    wrongLine = true;
    if (innerOff > sp.bottom) {
      return sp.left - adjust;
    } else if (innerOff < sp.top) {
      return sp.left + adjust;
    } else {
      wrongLine = false;
    }
    return sp.left;
  }

  var bidi = getOrder(lineObj),
      dist = lineObj.text.length;
  var from = lineLeft(lineObj),
      to = lineRight(lineObj);
  var fromX = getX(from),
      fromOutside = wrongLine,
      toX = getX(to),
      toOutside = wrongLine;

  if (x > toX) return new PosWithInfo(lineNo, to, toOutside, 1);

  for ( ; ; ) {
    if (bidi ? to == from || to == moveVisually(lineObj, from, 1) : to - from <=
        1) {
      var ch = x < fromX || x - fromX <= toX - x ? from : to;
      var xDiff = x - (ch == from ? fromX : toX);
      while (isExtendingChar(lineObj.text.charAt(ch))) ++ch;
      var pos = new PosWithInfo(lineNo, ch, ch == from ? fromOutside :
          toOutside, xDiff < -1 ? -1 : xDiff > 1 ? 1 : 0);
      return pos;
    }
    var step = (dist / 2).ceil(),
        middle = from + step;
    if (bidi) {
      middle = from;
      for (var i = 0; i < step; ++i) middle = moveVisually(lineObj, middle, 1);
    }
    var middleX = getX(middle);
    if (middleX > x) {
      to = middle;
      toX = middleX;
      if (toOutside = wrongLine) toX += 1000;
      dist = step;
    } else {
      from = middle;
      fromX = middleX;
      fromOutside = wrongLine;
      dist -= step;
    }
  }
}

textHeight(display) {
  if (display.cachedTextHeight != null) return display.cachedTextHeight;
  if (measureText == null) {
    measureText = elt("pre");


    for (var i = 0; i < 49; ++i) {
      measureText.appendChild(document.createTextNode("x"));
      measureText.appendChild(elt("br"));
    }
    measureText.appendChild(document.createTextNode("x"));
  }
  removeChildrenAndAdd(display.measure, measureText);
  var height = measureText.offsetHeight / 50;
  if (height > 3) display.cachedTextHeight = height;
  removeChildren(display.measure);
  return height || 1;
}

charWidth(display) {
  if (display.cachedCharWidth != null) return display.cachedCharWidth;
  var anchor = elt("span", "xxxxxxxxxx");
  var pre = elt("pre", [anchor]);
  removeChildrenAndAdd(display.measure, pre);
  var rect = anchor.getBoundingClientRect(),
      width = (rect.right - rect.left) / 10;
  if (width > 2) display.cachedCharWidth = width;
  return width || 10;
}

startOperation(cm) {
  cm.curOp = {
    'viewChanged': false,
    'startHeight': cm.doc.height,
    'forceUpdate': false,
    'updateInput': null,
    'typing': false,
    'changeObjs': null,
    'origin': null,
    'cursorActivity': false,
    'selectionChanged': false,
    'updateMaxLine': false,
    'scrollLeft': null,
    'scrollTop': null,
    'scrollToPos': null,
    'id': ++nextOpId
  };
  if (!delayedCallbackDepth++) delayedCallbacks = [];
}

endOperation(cm) {
  var op = cm.curOp,
      doc = cm.doc,
      display = cm.display;
  cm.curOp = null;

  if (op.updateMaxLine) findMaxLine(cm);


  if (op.viewChanged || op.forceUpdate || op.scrollTop != null || op.scrollToPos
      && (op.scrollToPos.from.line < display.viewFrom || op.scrollToPos.to.line >=
      display.viewTo) || display.maxLineChanged && cm.options.lineWrapping) {
    var updated = updateDisplay(cm, {
      'top': op.scrollTop,
      'ensure': op.scrollToPos
    }, op.forceUpdate);
    if (cm.display.scroller.offsetHeight) cm.doc.scrollTop =
        cm.display.scroller.scrollTop;
  }

  if (!updated && op.selectionChanged) updateSelection(cm);
  if (!updated && op.startHeight != cm.doc.height) updateScrollbars(cm);


  if (op.scrollTop != null && display.scroller.scrollTop != op.scrollTop) {
    var top = math.max(0, math.min(display.scroller.scrollHeight -
        display.scroller.clientHeight, op.scrollTop));
    display.scroller.scrollTop = display.scrollbarV.scrollTop = doc.scrollTop =
        top;
  }
  if (op.scrollLeft != null && display.scroller.scrollLeft != op.scrollLeft) {
    var left = math.max(0, math.min(display.scroller.scrollWidth -
        display.scroller.clientWidth, op.scrollLeft));
    display.scroller.scrollLeft = display.scrollbarH.scrollLeft = doc.scrollLeft
        = left;
    alignHorizontally(cm);
  }

  if (op.scrollToPos) {
    var coords = scrollPosIntoView(cm, _clipPos(cm.doc, op.scrollToPos.from),
        _clipPos(cm.doc, op.scrollToPos.to), op.scrollToPos.margin);
    if (op.scrollToPos.isCursor && cm.state.focused) maybeScrollWindow(cm,
        coords);
  }

  if (op.selectionChanged) restartBlink(cm);

  if (cm.state.focused && op.updateInput) resetInput(cm, op.typing);



  var hidden = op.maybeHiddenMarkers,
      unhidden = op.maybeUnhiddenMarkers;
  if (hidden) for (var i = 0; i < hidden.length; ++i) if
      (!hidden[i].lines.length) signal(hidden[i], "hide");
  if (unhidden) for (var i = 0; i < unhidden.length; ++i) if
      (unhidden[i].lines.length) signal(unhidden[i], "unhide");

  var delayed;
  if (!--delayedCallbackDepth) {
    delayed = delayedCallbacks;
    delayedCallbacks = null;
  }

  if (op.changeObjs) {
    for (var i = 0; i < op.changeObjs.length; i++) signal(cm, "change", cm,
        op.changeObjs[i]);
    signal(cm, "changes", cm, op.changeObjs);
  }
  if (op.cursorActivity) signal(cm, "cursorActivity", cm, op.origin);
  if (delayed) for (var i = 0; i < delayed.length; ++i) delayed[i]();
}

runInOp(cm, f) {
  if (cm.curOp) return f();
  startOperation(cm);
  try {
    return f();
  } finally {
    endOperation(cm);
  }
}

operation(cm, f) {
  return () {
    var arguments;  // XXX
    if (cm.curOp) return f.apply(cm, arguments);
    startOperation(cm);
    try {
      return f.apply(cm, arguments);
    } finally {
      endOperation(cm);
    }
  };
}

methodOp(f) {
  return () {
    var that; // XXX: this
    var arguments; // XXX
    if (that.curOp) return f.apply(that, arguments);
    startOperation(that);
    try {
      return f.apply(that, arguments);
    } finally {
      endOperation(that);
    }
  };
}

docMethodOp(f) {
  return () {
    var that; // XXX: this
    var arguments; // XXX
    var cm = that.cm;
    if (!cm || cm.curOp) return f.apply(that, arguments);
    startOperation(cm);
    try {
      return f.apply(that, arguments);
    } finally {
      endOperation(cm);
    }
  };
}

buildViewArray(cm, from, to) {
  var array = [],
      nextPos;
  for (var pos = from; pos < to; pos = nextPos) {
    var view = new LineView(cm.doc, getLine(cm.doc, pos), pos);
    nextPos = pos + view.size;
    array.push(view);
  }
  return array;
}

regChange(cm, [from, to, lendiff = 0]) {
  if (from == null) from = cm.doc.first;
  if (to == null) to = cm.doc.first + cm.doc.size;

  var display = cm.display;
  if (lendiff && to < display.viewTo && (display.updateLineNumbers == null ||
      display.updateLineNumbers > from)) display.updateLineNumbers = from;

  cm.curOp.viewChanged = true;

  if (from >= display.viewTo) {
    if (sawCollapsedSpans && visualLineNo(cm.doc, from) < display.viewTo)
        resetView(cm);
  } else if (to <= display.viewFrom) {
    if (sawCollapsedSpans && visualLineEndNo(cm.doc, to + lendiff) >
        display.viewFrom) {
      resetView(cm);
    } else {
      display.viewFrom += lendiff;
      display.viewTo += lendiff;
    }
  } else if (from <= display.viewFrom && to >= display.viewTo) {
    resetView(cm);
  } else if (from <= display.viewFrom) {
    var cut = viewCuttingPoint(cm, to, to + lendiff, 1);
    if (cut) {
      display.view = display.view.slice(cut.index);
      display.viewFrom = cut.lineN;
      display.viewTo += lendiff;
    } else {
      resetView(cm);
    }
  } else if (to >= display.viewTo) {
    var cut = viewCuttingPoint(cm, from, from, -1);
    if (cut) {
      display.view = display.view.slice(0, cut.index);
      display.viewTo = cut.lineN;
    } else {
      resetView(cm);
    }
  } else {
    var cutTop = viewCuttingPoint(cm, from, from, -1);
    var cutBot = viewCuttingPoint(cm, to, to + lendiff, 1);
    if (cutTop && cutBot) {
      display.view = display.view.slice(0, cutTop.index).concat(buildViewArray(
          cm, cutTop.lineN, cutBot.lineN)).concat(display.view.slice(cutBot.index));
      display.viewTo += lendiff;
    } else {
      resetView(cm);
    }
  }

  var ext = display.externalMeasured;
  if (ext) {
    if (to < ext.lineN) {
      ext.lineN += lendiff;
    } else if (from < ext.lineN + ext.size) display.externalMeasured = null;
  }
}

regLineChange(cm, line, type) {
  cm.curOp.viewChanged = true;
  var display = cm.display,
      ext = cm.display.externalMeasured;
  if (ext && line >= ext.lineN && line < ext.lineN + ext.size)
      display.externalMeasured = null;

  if (line < display.viewFrom || line >= display.viewTo) return;
  var lineView = display.view[findViewIndex(cm, line)];
  if (lineView.node == null) return;
  var arr = lineView.changes || (lineView.changes = []);
  if (indexOf(arr, type) == -1) arr.push(type);
}

resetView(cm) {
  cm.display.viewFrom = cm.display.viewTo = cm.doc.first;
  cm.display.view = [];
  cm.display.viewOffset = 0;
}

findViewIndex(cm, n) {
  if (n >= cm.display.viewTo) return null;
  n -= cm.display.viewFrom;
  if (n < 0) return null;
  var view = cm.display.view;
  for (var i = 0; i < view.length; i++) {
    n -= view[i].size;
    if (n < 0) return i;
  }
}

viewCuttingPoint(cm, oldN, newN, dir) {
  var index = findViewIndex(cm, oldN),
      diff,
      view = cm.display.view;
  if (!sawCollapsedSpans) return {
    index: index,
    lineN: newN
  };
  var n = cm.display.viewFrom;
  for (var i = 0; i < index; i++) n += view[i].size;
  if (n != oldN) {
    if (dir > 0) {
      if (index == view.length - 1) return null;
      diff = (n + view[index].size) - oldN;
      index++;
    } else {
      diff = n - oldN;
    }
    oldN += diff;
    newN += diff;
  }
  while (visualLineNo(cm.doc, newN) != newN) {
    if (index == (dir < 0 ? 0 : view.length - 1)) return null;
    newN += dir * view[index - (dir < 0 ? 1 : 0)].size;
    index += dir;
  }
  return {
    'index': index,
    'lineN': newN
  };
}

adjustView(cm, from, to) {
  var display = cm.display,
      view = display.view;
  if (view.length == 0 || from >= display.viewTo || to <= display.viewFrom) {
    display.view = buildViewArray(cm, from, to);
    display.viewFrom = from;
  } else {
    if (display.viewFrom > from) {
      display.view = buildViewArray(cm, from, display.viewFrom).concat(
          display.view);
    } else if (display.viewFrom < from) display.view = display.view.slice(
        findViewIndex(cm, from));
    display.viewFrom = from;
    if (display.viewTo < to) {
      display.view = display.view.concat(buildViewArray(cm, display.viewTo, to)
          );
    } else if (display.viewTo > to) display.view = display.view.slice(0,
        findViewIndex(cm, to));
  }
  display.viewTo = to;
}

countDirtyView(cm) {
  var view = cm.display.view,
      dirty = 0;
  for (var i = 0; i < view.length; i++) {
    var lineView = view[i];
    if (!lineView.hidden && (!lineView.node || lineView.changes)) ++dirty;
  }
  return dirty;
}

slowPoll(cm) {
  if (cm.display.pollingFast) return;
  cm.display.poll.set(cm.options.pollInterval, () {
    readInput(cm);
    if (cm.state.focused) slowPoll(cm);
  });
}

fastPoll(cm) {
  var missed = false;
  cm.display.pollingFast = true;
  p() {
    var changed = readInput(cm);
    if (!changed && !missed) {
      missed = true;
      cm.display.poll.set(60, p);
    } else {
      cm.display.pollingFast = false;
      slowPoll(cm);
    }
  }
  cm.display.poll.set(20, p);
}

readInput(cm) {
  var input = cm.display.input,
      prevInput = cm.display.prevInput,
      doc = cm.doc;




  if (!cm.state.focused || hasSelection(input) || isReadOnly(cm) ||
      cm.options.disableInput) return false;

  if (cm.state.pasteIncoming && cm.state.fakedLastChar) {
    input.value = input.value.substring(0, input.value.length - 1);
    cm.state.fakedLastChar = false;
  }
  var text = input.value;

  if (text == prevInput && !cm.somethingSelected()) return false;

  if (ie && !ie_upto8 && cm.display.inputHasSelection == text) {
    resetInput(cm);
    return false;
  }

  var withOp = !cm.curOp;
  if (withOp) startOperation(cm);
  cm.display.shift = false;


  var same = 0,
      l = math.min(prevInput.length, text.length);
  while (same < l && prevInput.charCodeAt(same) == text.charCodeAt(same))
      ++same;
  var inserted = text.slice(same),
      textLines = splitLines(inserted);


  var multiPaste = cm.state.pasteIncoming && textLines.length > 1 &&
      doc.sel.ranges.length == textLines.length;


  for (var i = doc.sel.ranges.length - 1; i >= 0; i--) {
    var range = doc.sel.ranges[i];
    var from = range.from(),
        to = range.to();

    if (same < prevInput.length) {
      from = newPos(from.line, from.ch - (prevInput.length - same));
    } else if (cm.state.overwrite && range.empty() && !cm.state.pasteIncoming)
        to = newPos(to.line, math.min(getLine(doc, to.line).text.length, to.ch + lst(
        textLines).length));
    var updateInput = cm.curOp.updateInput;
    var changeEvent = {
      'from': from,
      'to': to,
      'text': multiPaste ? [textLines[i]] : textLines,
      'origin': cm.state.pasteIncoming ? "paste" : cm.state.cutIncoming ? "cut" :
          "+input"
    };
    makeChange(cm.doc, changeEvent);
    signalLater(cm, "inputRead", cm, changeEvent);

    if (inserted && !cm.state.pasteIncoming && cm.options.electricChars &&
        cm.options.smartIndent && range.head.ch < 100 && (!i || doc.sel.ranges[i -
        1].head.line != range.head.line)) {
      var mode = cm.getModeAt(range.head);
      if (mode.electricChars) {
        for (var j = 0; j < mode.electricChars.length; j++) if
            (inserted.indexOf(mode.electricChars.charAt(j)) > -1) {
          indentLine(cm, range.head.line, "smart");
          break;
        }
      } else if (mode.electricInput) {
        var end = changeEnd(changeEvent);
        if (mode.electricInput.test(getLine(doc, end.line).text.slice(0, end.ch)
            )) indentLine(cm, range.head.line, "smart");
      }
    }
  }
  ensureCursorVisible(cm);
  cm.curOp.updateInput = updateInput;
  cm.curOp.typing = true;


  if (text.length > 1000 || text.indexOf("\n") > -1) {
    input.value = cm.display.prevInput = "";
  } else {
    cm.display.prevInput = text;
  }
  if (withOp) endOperation(cm);
  cm.state.pasteIncoming = cm.state.cutIncoming = false;
  return true;
}

resetInput(cm, typing) {
  var minimal,
      selected,
      doc = cm.doc;
  if (cm.somethingSelected()) {
    cm.display.prevInput = "";
    var range = doc.sel.primary();
    minimal = hasCopyEvent && (range.to().line - range.from().line > 100 ||
        (selected = cm.getSelection()).length > 1000);
    var content = minimal ? "-" : selected || cm.getSelection();
    cm.display.input.value = content;
    if (cm.state.focused) selectInput(cm.display.input);
    if (ie && !ie_upto8) cm.display.inputHasSelection = content;
  } else if (!typing) {
    cm.display.prevInput = cm.display.input.value = "";
    if (ie && !ie_upto8) cm.display.inputHasSelection = null;
  }
  cm.display.inaccurateSelection = minimal;
}

focusInput(cm) {
  if (cm.options.readOnly != "nocursor" && (!mobile || activeElt() !=
      cm.display.input)) cm.display.input.focus();
}

ensureFocus(cm) {
  if (!cm.state.focused) {
    focusInput(cm);
    onFocus(cm);
  }
}

isReadOnly(cm) {
  return cm.options.readOnly || cm.doc.cantEdit;
}

registerEventHandlers(cm) {
  var d = cm.display;
  _on(d.scroller, "mousedown", operation(cm, onMouseDown));

  if (ie_upto10) {
    _on(d.scroller, "dblclick", operation(cm, (e) {
      if (signalDOMEvent(cm, e)) return;
      var pos = posFromMouse(cm, e);
      if (!pos || clickInGutter(cm, e) || eventInWidget(cm.display, e)) return;
      e_preventDefault(e);
      var word = findWordAt(cm.doc, pos);
      extendSelection(cm.doc, word.anchor, word.head);
    }));
  } else {
    _on(d.scroller, "dblclick", (e) {
      signalDOMEvent(cm, e) || e_preventDefault(e);
    });
  }
  _on(d.lineSpace, "selectstart", (e) {
    if (!eventInWidget(d, e)) e_preventDefault(e);
  });



  if (!captureRightClick) _on(d.scroller, "contextmenu", (e) {
    onContextMenu(cm, e);
  });



  _on(d.scroller, "scroll", () {
    if (d.scroller.clientHeight) {
      setScrollTop(cm, d.scroller.scrollTop);
      setScrollLeft(cm, d.scroller.scrollLeft, true);
      signal(cm, "scroll", cm);
    }
  });
  _on(d.scrollbarV, "scroll", () {
    if (d.scroller.clientHeight) setScrollTop(cm, d.scrollbarV.scrollTop);
  });
  _on(d.scrollbarH, "scroll", () {
    if (d.scroller.clientHeight) setScrollLeft(cm, d.scrollbarH.scrollLeft);
  });


  _on(d.scroller, "mousewheel", (e) {
    onScrollWheel(cm, e);
  });
  _on(d.scroller, "DOMMouseScroll", (e) {
    onScrollWheel(cm, e);
  });


  reFocus() {
    if (cm.state.focused) setTimeout(bind(focusInput, cm), 0);
  }
  _on(d.scrollbarH, "mousedown", reFocus);
  _on(d.scrollbarV, "mousedown", reFocus);

  _on(d.wrapper, "scroll", () {
    d.wrapper.scrollTop = d.wrapper.scrollLeft = 0;
  });


  var resizeTimer;
  onResize() {
    if (resizeTimer == null) resizeTimer = setTimeout(() {
      resizeTimer = null;

      d.cachedCharWidth = d.cachedTextHeight = d.cachedPaddingH =
          knownScrollbarWidth = null;
      cm.setSize();
    }, 100);
  }
  _on(window, "resize", onResize);



  unregister() {
    if (contains(document.body, d.wrapper)) {
      setTimeout(unregister, 5000);
    } else {
      _off(window, "resize", onResize);
    }
  }
  setTimeout(unregister, 5000);

  _on(d.input, "keyup", operation(cm, onKeyUp));
  _on(d.input, "input", () {
    if (ie && !ie_upto8 && cm.display.inputHasSelection)
        cm.display.inputHasSelection = null;
    fastPoll(cm);
  });
  _on(d.input, "keydown", operation(cm, onKeyDown));
  _on(d.input, "keypress", operation(cm, onKeyPress));
  _on(d.input, "focus", bind(onFocus, cm));
  _on(d.input, "blur", bind(onBlur, cm));

  drag_(e) {
    if (!signalDOMEvent(cm, e)) e_stop(e);
  }
  if (cm.options.dragDrop) {
    _on(d.scroller, "dragstart", (e) {
      onDragStart(cm, e);
    });
    _on(d.scroller, "dragenter", drag_);
    _on(d.scroller, "dragover", drag_);
    _on(d.scroller, "drop", operation(cm, onDrop));
  }
  _on(d.scroller, "paste", (e) {
    if (eventInWidget(d, e)) return;
    cm.state.pasteIncoming = true;
    focusInput(cm);
    fastPoll(cm);
  });
  _on(d.input, "paste", () {



    if (webkit && !cm.state.fakedLastChar && !(new Date() -
        cm.state.lastMiddleDown < 200)) {
      var start = d.input.selectionStart,
          end = d.input.selectionEnd;
      d.input.value += "\$";
      d.input.selectionStart = start;
      d.input.selectionEnd = end;
      cm.state.fakedLastChar = true;
    }
    cm.state.pasteIncoming = true;
    fastPoll(cm);
  });

  prepareCopyCut(e) {
    if (cm.somethingSelected()) {
      if (d.inaccurateSelection) {
        d.prevInput = "";
        d.inaccurateSelection = false;
        d.input.value = cm.getSelection();
        selectInput(d.input);
      }
    } else {
      var text = "",
          ranges = [];
      for (var i = 0; i < cm.doc.sel.ranges.length; i++) {
        var line = cm.doc.sel.ranges[i].head.line;
        var lineRange = {
          'anchor': newPos(line, 0),
          'head': newPos(line + 1, 0)
        };
        ranges.push(lineRange);
        text += cm.getRange(lineRange.anchor, lineRange.head);
      }
      if (e.type == "cut") {
        cm.setSelections(ranges, null, sel_dontScroll);
      } else {
        d.prevInput = "";
        d.input.value = text;
        selectInput(d.input);
      }
    }
    if (e.type == "cut") cm.state.cutIncoming = true;
  }
  _on(d.input, "cut", prepareCopyCut);
  _on(d.input, "copy", prepareCopyCut);


  if (khtml) _on(d.sizer, "mouseup", () {
    if (activeElt() == d.input) d.input.blur();
    focusInput(cm);
  });
}

eventInWidget(display, e) {
  for (var n = e_target(e); n != display.wrapper; n = n.parentNode) {
    if (!n || n.ignoreEvents || n.parentNode == display.sizer && n !=
        display.mover) return true;
  }
}

posFromMouse(cm, e, liberal, forRect) {
  var display = cm.display;
  if (!liberal) {
    var target = e_target(e);
    if (target == display.scrollbarH || target == display.scrollbarV || target
        == display.scrollbarFiller || target == display.gutterFiller) return null;
  }
  var x,
      y,
      space = display.lineSpace.getBoundingClientRect();

  try {
    x = e.clientX - space.left;
    y = e.clientY - space.top;
  } catch (e) {
    return null;
  }
  var coords = coordsChar(cm, x, y),
      line;
  if (forRect && coords.xRel == 1 && (line = getLine(cm.doc, coords.line
      ).text).length == coords.ch) {
    var colDiff = countColumn(line, line.length, cm.options.tabSize) -
        line.length;
    coords = newPos(coords.line, ((x - paddingH(cm.display).left) /
        charWidth(cm.display)).round() - colDiff);
  }
  return coords;
}

onMouseDown(e) {
  var that; // XXX: this
  if (signalDOMEvent(that, e)) return;
  var cm = that,
      display = cm.display;
  display.shift = e.shiftKey;

  if (eventInWidget(display, e)) {
    if (!webkit) {


      display.scroller.draggable = false;
      setTimeout(() {
        display.scroller.draggable = true;
      }, 100);
    }
    return;
  }
  if (clickInGutter(cm, e)) return;
  var start = posFromMouse(cm, e);
  window.focus();

  switch (e_button(e)) {
    case 1:
      if (start) {
        leftButtonDown(cm, e, start);
      } else if (e_target(e) == display.scroller) e_preventDefault(e);
      break;
    case 2:
      if (webkit) cm.state.lastMiddleDown = currentTimeInMs();
      if (start) extendSelection(cm.doc, start);
      setTimeout(bind(focusInput, cm), 20);
      e_preventDefault(e);
      break;
    case 3:
      if (captureRightClick) onContextMenu(cm, e);
      break;
  }
}

leftButtonDown(cm, e, start) {
  setTimeout(bind(ensureFocus, cm), 0);

  var now = currentTimeInMs(),
      type;
  if (lastDoubleClick && lastDoubleClick.time > now - 400 && cmp(
      lastDoubleClick.pos, start) == 0) {
    type = "triple";
  } else if (lastClick && lastClick.time > now - 400 && cmp(lastClick.pos, start
      ) == 0) {
    type = "double";
    lastDoubleClick = {
      'time': now,
      'pos': start
    };
  } else {
    type = "single";
    lastClick = {
      'time': now,
      'pos': start
    };
  }

  var sel = cm.doc.sel,
      addNew = mac ? e.metaKey : e.ctrlKey;
  if (cm.options.dragDrop && dragAndDrop && !addNew && !isReadOnly(cm) && type
      == "single" && sel.contains(start) > -1 && sel.somethingSelected()) {
    leftButtonStartDrag(cm, e, start);
  } else {
    leftButtonSelect(cm, e, start, type, addNew);
  }
}

leftButtonStartDrag(cm, e, start) {
  var display = cm.display;
  var dragEnd;
  dragEnd = operation(cm, (e2) {
    if (webkit) display.scroller.draggable = false;
    cm.state.draggingText = false;
    _off(document, "mouseup", dragEnd);
    _off(display.scroller, "drop", dragEnd);
    if ((e.clientX - e2.clientX).abs() + (e.clientY - e2.clientY).abs() <
        10) {
      e_preventDefault(e2);
      extendSelection(cm.doc, start);
      focusInput(cm);

      if (ie_upto10 && !ie_upto8) setTimeout(() {
        document.body.focus();
        focusInput(cm);
      }, 20);
    }
  });

  if (webkit) display.scroller.draggable = true;
  cm.state.draggingText = dragEnd;

  if (display.scroller.dragDrop) display.scroller.dragDrop();
  _on(document, "mouseup", dragEnd);
  _on(display.scroller, "drop", dragEnd);
}

leftButtonSelect(cm, e, start, type, addNew) {
  var display = cm.display,
      doc = cm.doc;
  e_preventDefault(e);

  var ourRange,
      ourIndex,
      startSel = doc.sel;
  if (addNew) {
    ourIndex = doc.sel.contains(start);
    if (ourIndex > -1) {
      ourRange = doc.sel.ranges[ourIndex];
    } else {
      ourRange = new Range(start, start);
    }
  } else {
    ourRange = doc.sel.primary();
  }

  if (e.altKey) {
    type = "rect";
    if (!addNew) ourRange = new Range(start, start);
    start = posFromMouse(cm, e, true, true);
    ourIndex = -1;
  } else if (type == "double") {
    var word = findWordAt(doc, start);
    if (cm.display.shift || doc.extend) {
      ourRange = extendRange(doc, ourRange, word.anchor, word.head);
    } else {
      ourRange = word;
    }
  } else if (type == "triple") {
    var line = new Range(newPos(start.line, 0), _clipPos(doc, newPos(start.line
        + 1, 0)));
    if (cm.display.shift || doc.extend) {
      ourRange = extendRange(doc, ourRange, line.anchor, line.head);
    } else {
      ourRange = line;
    }
  } else {
    ourRange = extendRange(doc, ourRange, start);
  }

  if (!addNew) {
    ourIndex = 0;
    _setSelection(doc, new Selection([ourRange], 0), sel_mouse);
  } else if (ourIndex > -1) {
    replaceOneSelection(doc, ourIndex, ourRange, sel_mouse);
  } else {
    ourIndex = doc.sel.ranges.length;
    _setSelection(doc, normalizeSelection(doc.sel.ranges.concat([ourRange]),
        ourIndex), {
      'scroll': false,
      'origin': "*mouse"
    });
  }

  var lastPos = start;
  extendTo(pos) {
    if (cmp(lastPos, pos) == 0) return;
    lastPos = pos;

    if (type == "rect") {
      var ranges = [],
          tabSize = cm.options.tabSize;
      var startCol = countColumn(getLine(doc, start.line).text, start.ch,
          tabSize);
      var posCol = countColumn(getLine(doc, pos.line).text, pos.ch, tabSize);
      var left = math.min(startCol, posCol),
          right = math.max(startCol, posCol);
      for (var line = math.min(start.line, pos.line),
          end = math.min(cm.lastLine(), math.max(start.line, pos.line)); line <=
              end; line++) {
        var text = getLine(doc, line).text,
            leftPos = findColumn(text, left, tabSize);
        if (left == right) {
          ranges.push(new Range(newPos(line, leftPos), newPos(line, leftPos)));
        } else if (text.length > leftPos) ranges.push(new Range(newPos(line,
            leftPos), newPos(line, findColumn(text, right, tabSize))));
      }
      if (!ranges.length) ranges.push(new Range(start, start));
      _setSelection(doc, normalizeSelection(startSel.ranges.slice(0, ourIndex
          ).concat(ranges), ourIndex), sel_mouse);
    } else {
      var oldRange = ourRange;
      var anchor = oldRange.anchor,
          head = pos;
      if (type != "single") {
        if (type == "double") {
          var range = findWordAt(doc, pos);
        } else {
          var range = new Range(newPos(pos.line, 0), _clipPos(doc, newPos(
              pos.line + 1, 0)));
        }
        if (cmp(range.anchor, anchor) > 0) {
          head = range.head;
          anchor = minPos(oldRange.from(), range.anchor);
        } else {
          head = range.anchor;
          anchor = maxPos(oldRange.to(), range.head);
        }
      }
      var ranges = startSel.ranges.slice(0);
      ranges[ourIndex] = new Range(_clipPos(doc, anchor), head);
      _setSelection(doc, normalizeSelection(ranges, ourIndex), sel_mouse);
    }
  }

  var editorSize = display.wrapper.getBoundingClientRect();




  var counter = 0;

  extend(e) {
    var curCount = ++counter;
    var cur = posFromMouse(cm, e, true, type == "rect");
    if (!cur) return;
    if (cmp(cur, lastPos) != 0) {
      ensureFocus(cm);
      extendTo(cur);
      var visible = visibleLines(display, doc);
      if (cur.line >= visible.to || cur.line < visible.from) setTimeout(
          operation(cm, () {
        if (counter == curCount) extend(e);
      }), 150);
    } else {
      var outside = e.clientY < editorSize.top ? -20 : e.clientY >
          editorSize.bottom ? 20 : 0;
      if (outside) setTimeout(operation(cm, () {
        if (counter != curCount) return;
        display.scroller.scrollTop += outside;
        extend(e);
      }), 50);
    }
  }

  var up, move;
  done(e) {
    counter = double.INFINITY;
    e_preventDefault(e);
    focusInput(cm);
    _off(document, "mousemove", move);
    _off(document, "mouseup", up);
    doc.history.lastSelOrigin = null;
  }

  move = operation(cm, (e) {
    if ((ie && !ie_upto9) ? !e.buttons : !e_button(e)) {
      done(e);
    } else {
      extend(e);
    }
  });
  up = operation(cm, done);
  _on(document, "mousemove", move);
  _on(document, "mouseup", up);
}
