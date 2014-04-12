part of codemirror.dart;


gutterEvent(cm, e, type, prevent, signalfn) {
  var mX, mY;
  try {
    mX = e.clientX;
    mY = e.clientY;
  } catch (e) {
    return false;
  }
  if (mX >= (cm.display.gutters.getBoundingClientRect().right).floor()) return
      false;
  if (prevent) e_preventDefault(e);

  var display = cm.display;
  var lineBox = display.lineDiv.getBoundingClientRect();

  if (mY > lineBox.bottom || !hasHandler(cm, type)) return e_defaultPrevented(e
      );
  mY -= lineBox.top - display.viewOffset;

  for (var i = 0; i < cm.options.gutters.length; ++i) {
    var g = display.gutters.childNodes[i];
    if (g && g.getBoundingClientRect().right >= mX) {
      var line = lineAtHeight(cm.doc, mY);
      var gutter = cm.options.gutters[i];
      signalfn(cm, type, cm, line, gutter, e);
      return e_defaultPrevented(e);
    }
  }
}

clickInGutter(cm, e) {
  return gutterEvent(cm, e, "gutterClick", true, signalLater);
}

onDrop(e) {
  var cm; // XXX: this;
  if (signalDOMEvent(cm, e) || eventInWidget(cm.display, e)) return;
  e_preventDefault(e);
  if (ie_upto10) lastDrop = currentTimeInMs();
  var pos = posFromMouse(cm, e, true),
      files = e.dataTransfer.files;
  if (!pos || isReadOnly(cm)) return;


  if (files && files.length && window.FileReader && window.File) {
    var n = files.length,
        text = Array(n),
        read = 0;
    var loadFile = (file, i) {
      var reader = new FileReader();
      reader.onload = operation(cm, () {
        text[i] = reader.result;
        if (++read == n) {
          pos = _clipPos(cm.doc, pos);
          var change = {
            from: pos,
            to: pos,
            text: splitLines(text.join("\n")),
            origin: "paste"
          };
          makeChange(cm.doc, change);
          setSelectionReplaceHistory(cm.doc, simpleSelection(pos, changeEnd(
              change)));
        }
      });
      reader.readAsText(file);
    };
    for (var i = 0; i < n; ++i) loadFile(files[i], i);
  } else {

    if (cm.state.draggingText && cm.doc.sel.contains(pos) > -1) {
      cm.state.draggingText(e);

      setTimeout(bind(focusInput, cm), 20);
      return;
    }
    try {
      var text = e.dataTransfer.getData("Text");
      if (text) {
        var selected = cm.state.draggingText && cm.listSelections();
        setSelectionNoUndo(cm.doc, simpleSelection(pos, pos));
        if (selected) for (var i = 0; i < selected.length; ++i) replaceRange(
            cm.doc, "", selected[i].anchor, selected[i].head, "drag");
        cm.replaceSelection(text, "around", "paste");
        focusInput(cm);
      }
    } catch (e) {}
  }
}

onDragStart(cm, e) {
  if (ie_upto10 && (!cm.state.draggingText || currentTimeInMs() - lastDrop <
      100)) {
    e_stop(e);
    return;
  }
  if (signalDOMEvent(cm, e) || eventInWidget(cm.display, e)) return;

  e.dataTransfer.setData("Text", cm.getSelection());



  if (e.dataTransfer.setDragImage && !safari) {
    var img = elt("img", null, null, "position: fixed; left: 0; top: 0;");
    img.src =
        "data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw==";
    if (presto) {
      img.width = img.height = 1;
      cm.display.wrapper.appendChild(img);

      img._top = img.offsetTop;
    }
    e.dataTransfer.setDragImage(img, 0, 0);
    if (presto) img.parentNode.removeChild(img);
  }
}

setScrollTop(cm, val) {
  if ((cm.doc.scrollTop - val).abs() < 2) return;
  cm.doc.scrollTop = val;
  if (!gecko) updateDisplay(cm, {
    'top': val
  });
  if (cm.display.scroller.scrollTop != val) cm.display.scroller.scrollTop = val;
  if (cm.display.scrollbarV.scrollTop != val) cm.display.scrollbarV.scrollTop =
      val;
  if (gecko) updateDisplay(cm);
  startWorker(cm, 100);
}

setScrollLeft(cm, val, [isScroller]) {
  if (isScroller ? val == cm.doc.scrollLeft : (cm.doc.scrollLeft - val).abs()
      < 2) return;
  val = math.min(val, cm.display.scroller.scrollWidth -
      cm.display.scroller.clientWidth);
  cm.doc.scrollLeft = val;
  alignHorizontally(cm);
  if (cm.display.scroller.scrollLeft != val) cm.display.scroller.scrollLeft =
      val;
  if (cm.display.scrollbarH.scrollLeft != val) cm.display.scrollbarH.scrollLeft
      = val;
}

onScrollWheel(cm, e) {
  var dx = e.wheelDeltaX,
      dy = e.wheelDeltaY;
  if (dx == null && e.detail && e.axis == e.HORIZONTAL_AXIS) dx = e.detail;
  if (dy == null && e.detail && e.axis == e.VERTICAL_AXIS) dy = e.detail; else
      if (dy == null) dy = e.wheelDelta;

  var display = cm.display,
      scroll = display.scroller;

  if (!(dx && scroll.scrollWidth > scroll.clientWidth || dy &&
      scroll.scrollHeight > scroll.clientHeight)) return;





  if (dy && mac && webkit) {
    outer: for (var cur = e.target,
        view = display.view; cur != scroll; cur = cur.parentNode) {
      for (var i = 0; i < view.length; i++) {
        if (view[i].node == cur) {
          cm.display.currentWheelTarget = cur;
          break outer;
        }
      }
    }
  }







  if (dx && !gecko && !presto && wheelPixelsPerUnit != null) {
    if (dy) setScrollTop(cm, math.max(0, math.min(scroll.scrollTop + dy *
        wheelPixelsPerUnit, scroll.scrollHeight - scroll.clientHeight)));
    setScrollLeft(cm, math.max(0, math.min(scroll.scrollLeft + dx *
        wheelPixelsPerUnit, scroll.scrollWidth - scroll.clientWidth)));
    e_preventDefault(e);
    display.wheelStartX = null;
    return;
  }



  if (dy && wheelPixelsPerUnit != null) {
    var pixels = dy * wheelPixelsPerUnit;
    var top = cm.doc.scrollTop,
        bot = top + display.wrapper.clientHeight;
    if (pixels < 0) top = math.max(0, top + pixels - 50); else bot = math.min(
        cm.doc.height, bot + pixels + 50);
    updateDisplay(cm, {
      'top': top,
      'bottom': bot
    });
  }

  if (wheelSamples < 20) {
    if (display.wheelStartX == null) {
      display.wheelStartX = scroll.scrollLeft;
      display.wheelStartY = scroll.scrollTop;
      display.wheelDX = dx;
      display.wheelDY = dy;
      setTimeout(() {
        if (display.wheelStartX == null) return;
        var movedX = scroll.scrollLeft - display.wheelStartX;
        var movedY = scroll.scrollTop - display.wheelStartY;
        var sample = (movedY && display.wheelDY && movedY / display.wheelDY) ||
            (movedX && display.wheelDX && movedX / display.wheelDX);
        display.wheelStartX = display.wheelStartY = null;
        if (!sample) return;
        wheelPixelsPerUnit = (wheelPixelsPerUnit * wheelSamples + sample) /
            (wheelSamples + 1);
        ++wheelSamples;
      }, 200);
    } else {
      display.wheelDX += dx;
      display.wheelDY += dy;
    }
  }
}

doHandleBinding(cm, bound, [dropShift]) {
  if (typeOfReplacement(bound, "string")) {
    bound = commands[bound];
    if (!bound) return false;
  }


  if (cm.display.pollingFast && readInput(cm)) cm.display.pollingFast = false;
  var prevShift = cm.display.shift,
      done = false;
  try {
    if (isReadOnly(cm)) cm.state.suppressEdits = true;
    if (dropShift) cm.display.shift = false;
    done = bound(cm) != Pass;
  } finally {
    cm.display.shift = prevShift;
    cm.state.suppressEdits = false;
  }
  return done;
}

allKeyMaps(cm) {
  var maps = cm.state.keyMaps.slice(0);
  if (cm.options.extraKeys) maps.push(cm.options.extraKeys);
  maps.push(cm.options.keyMap);
  return maps;
}

handleKeyBinding(cm, e) {

  var startMap = getKeyMap(cm.options.keyMap),
      next = startMap.auto;
  clearTimeout(maybeTransition);
  if (next && !isModifierKey(e)) maybeTransition = setTimeout(() {
    if (getKeyMap(cm.options.keyMap) == startMap) {
      cm.options.keyMap = (next.call ? next.call(null, cm) : next);
      keyMapChanged(cm);
    }
  }, 50);

  var name = keyName(e, true),
      handled = false;
  if (!name) return false;
  var keymaps = allKeyMaps(cm);

  if (e.shiftKey) {



    handled = lookupKey("Shift-" + name, keymaps, (b) {
      return doHandleBinding(cm, b, true);
    }) || lookupKey(name, keymaps, (b) {
      if (typeOfReplacement(b, "string") ? new Refexp("/^go[A-Z]/").test(b) :
          b.motion) return doHandleBinding(cm, b);
    });
  } else {
    handled = lookupKey(name, keymaps, (b) {
      return doHandleBinding(cm, b);
    });
  }

  if (handled) {
    e_preventDefault(e);
    restartBlink(cm);
    signalLater(cm, "keyHandled", cm, name, e);
  }
  return handled;
}

handleCharBinding(cm, e, ch) {
  var handled = lookupKey("'" + ch + "'", allKeyMaps(cm), (b) {
    return doHandleBinding(cm, b, true);
  });
  if (handled) {
    e_preventDefault(e);
    restartBlink(cm);
    signalLater(cm, "keyHandled", cm, "'" + ch + "'", e);
  }
  return handled;
}

onKeyDown(e) {
  var cm; // XXX: this;
  ensureFocus(cm);
  if (signalDOMEvent(cm, e)) return;

  if (ie_upto10 && e.keyCode == 27) e.returnValue = false;
  var code = e.keyCode;
  cm.display.shift = code == 16 || e.shiftKey;
  var handled = handleKeyBinding(cm, e);
  if (presto) {
    lastStoppedKey = handled ? code : null;

    if (!handled && code == 88 && !hasCopyEvent && (mac ? e.metaKey :
        e.ctrlKey)) cm.replaceSelection("", null, "cut");
  }


  if (code == 18 && !new Refexp("/\bCodeMirror-crosshair\b/").test(
      cm.display.lineDiv.className)) showCrossHair(cm);
}

showCrossHair(cm) {
  var lineDiv = cm.display.lineDiv;
  addClass(lineDiv, "CodeMirror-crosshair");

  up(e) {
    if (e.keyCode == 18 || !e.altKey) {
      rmClass(lineDiv, "CodeMirror-crosshair");
      _off(document, "keyup", up);
      _off(document, "mouseover", up);
    }
  }
  _on(document, "keyup", up);
  _on(document, "mouseover", up);
}

onKeyUp(e) {
  var that; // XXX: this
  if (signalDOMEvent(that, e)) return;
  if (e.keyCode == 16) that.doc.sel.shift = false;
}

onKeyPress(e) {
  var cm; // XXX: this;
  if (signalDOMEvent(cm, e)) return;
  var keyCode = e.keyCode,
      charCode = e.charCode;
  if (presto && keyCode == lastStoppedKey) {
    lastStoppedKey = null;
    e_preventDefault(e);
    return;
  }
  if (((presto && (!e.which || e.which < 10)) || khtml) && handleKeyBinding(cm,
      e)) return;
  var ch = String.fromCharCode(charCode == null ? keyCode : charCode);
  if (handleCharBinding(cm, e, ch)) return;
  if (ie && !ie_upto8) cm.display.inputHasSelection = null;
  fastPoll(cm);
}

onFocus(cm) {
  if (cm.options.readOnly == "nocursor") return;
  if (!cm.state.focused) {
    signal(cm, "focus", cm);
    cm.state.focused = true;
    addClass(cm.display.wrapper, "CodeMirror-focused");
    if (!cm.curOp) {
      resetInput(cm);
      if (webkit) setTimeout(bind(resetInput, cm, true), 0);
    }
  }
  slowPoll(cm);
  restartBlink(cm);
}

onBlur(cm) {
  if (cm.state.focused) {
    signal(cm, "blur", cm);
    cm.state.focused = false;
    rmClass(cm.display.wrapper, "CodeMirror-focused");
  }
  clearInterval(cm.display.blinker);
  setTimeout(() {
    if (!cm.state.focused) cm.display.shift = false;
  }, 150);
}

onContextMenu(cm, e) {
  if (signalDOMEvent(cm, e, "contextmenu")) return;
  var display = cm.display;
  if (eventInWidget(display, e) || contextMenuInGutter(cm, e)) return;

  var pos = posFromMouse(cm, e),
      scrollPos = display.scroller.scrollTop;
  if (!pos || presto) return;



  var reset = cm.options.resetSelectionOnContextMenu;
  if (reset && cm.doc.sel.contains(pos) == -1) operation(cm, setSelection)(
      cm.doc, simpleSelection(pos), sel_dontScroll);

  var oldCSS = display.input.style.cssText;
  display.inputDiv.style.position = "absolute";
  display.input.style.cssText =
      "position: fixed; width: 30px; height: 30px; top: " + (e.clientY - 5) +
      "px; left: " + (e.clientX - 5) + "px; z-index: 1000; background: " + (ie ?
      "rgba(255, 255, 255, .05)" : "transparent") +
      "; outline: none; border-width: 0; outline: none; overflow: hidden; opacity: .05; filter: alpha(opacity=5);";
  focusInput(cm);
  resetInput(cm);

  if (!cm.somethingSelected()) display.input.value = display.prevInput = " ";




  prepareSelectAllHack() {
    if (display.input.selectionStart != null) {
      var extval = display.input.value = "\u200b" + (cm.somethingSelected() ?
          display.input.value : "");
      display.prevInput = "\u200b";
      display.input.selectionStart = 1;
      display.input.selectionEnd = extval.length;
    }
  }
  rehide() {
    display.inputDiv.style.position = "relative";
    display.input.style.cssText = oldCSS;
    if (ie_upto8) display.scrollbarV.scrollTop = display.scroller.scrollTop =
        scrollPos;
    slowPoll(cm);


    if (display.input.selectionStart != null) {
      if (!ie || ie_upto8) prepareSelectAllHack();
      clearTimeout(detectingSelectAll);
      var i = 0,
          poll;
      poll = () {
        if (display.prevInput == "\u200b" && display.input.selectionStart == 0)
            operation(cm, commands.selectAll)(cm); else if (i++ < 10) detectingSelectAll =
            setTimeout(poll, 500); else resetInput(cm);
      };
      detectingSelectAll = setTimeout(poll, 200);
    }
  }

  if (ie && !ie_upto8) prepareSelectAllHack();
  if (captureRightClick) {
    e_stop(e);
    var mouseup;
    mouseup = () {
      _off(window, "mouseup", mouseup);
      setTimeout(rehide, 20);
    };
    _on(window, "mouseup", mouseup);
  } else {
    setTimeout(rehide, 50);
  }
}

contextMenuInGutter(cm, e) {
  if (!hasHandler(cm, "gutterContextMenu")) return false;
  return gutterEvent(cm, e, "gutterContextMenu", false, signal);
}

adjustForChange(pos, change) {
  if (cmp(pos, change.from) < 0) return pos;
  if (cmp(pos, change.to) <= 0) return changeEnd(change);

  var line = pos.line + change.text.length - (change.to.line - change.from.line)
      - 1,
      ch = pos.ch;
  if (pos.line == change.to.line) ch += changeEnd(change).ch - change.to.ch;
  return newPos(line, ch);
}

computeSelAfterChange(doc, change, [a]) {
  var arguments = [doc, change, a];
  
  var out = [];
  for (var i = 0; i < doc.sel.ranges.length; i++) {
    var range = doc.sel.ranges[i];
    out.push(new Range(adjustForChange(range.anchor, change), adjustForChange(
        range.head, change)));
  }
  return normalizeSelection(out, doc.sel.primIndex);
}

offsetPos(pos, old, nw) {
  if (pos.line == old.line) return newPos(nw.line, pos.ch - old.ch + nw.ch);
      else return newPos(nw.line + (pos.line - old.line), pos.ch);
}

computeReplacedSel(doc, changes, hint) {
  var out = [];
  var oldPrev = newPos(doc.first, 0),
      newPrev = oldPrev;
  for (var i = 0; i < changes.length; i++) {
    var change = changes[i];
    var from = offsetPos(change.from, oldPrev, newPrev);
    var to = offsetPos(changeEnd(change), oldPrev, newPrev);
    oldPrev = change.to;
    newPrev = to;
    if (hint == "around") {
      var range = doc.sel.ranges[i],
          inv = cmp(range.head, range.anchor) < 0;
      out[i] = new Range(inv ? to : from, inv ? from : to);
    } else {
      out[i] = new Range(from, from);
    }
  }
  return new Selection(out, doc.sel.primIndex);
}

filterChange(doc, change, update) {
  var obj = {
    'canceled': false,
    'from': change.from,
    'to': change.to,
    'text': change.text,
    'origin': change.origin,
    'cancel': () {
      var that; // XXX: this
      that.canceled = true;
    }
  };
  var that; // XX: this
  if (update) obj.update = (from, to, text, origin) {
    if (from) that.from = _clipPos(doc, from);
    if (to) that.to = _clipPos(doc, to);
    if (text) that.text = text;
    if (origin != null) that.origin = origin;
  };
  signal(doc, "beforeChange", doc, obj);
  if (doc.cm) signal(doc.cm, "beforeChange", doc.cm, obj);

  if (obj.canceled) return null;
  return {
    'from': obj.from,
    'to': obj.to,
    'text': obj.text,
    'origin': obj.origin
  };
}

makeChange(doc, change, [ignoreReadOnly]) {
  if (doc.cm) {
    if (!doc.cm.curOp) return operation(doc.cm, makeChange)(doc, change,
        ignoreReadOnly);
    if (doc.cm.state.suppressEdits) return null;
  }

  if (hasHandler(doc, "beforeChange") || doc.cm && hasHandler(doc.cm,
      "beforeChange")) {
    change = filterChange(doc, change, true);
    if (!change) return null;
  }



  var split = sawReadOnlySpans && !ignoreReadOnly && removeReadOnlyRanges(doc,
      change.from, change.to);
  if (split) {
    for (var i = split.length - 1; i >= 0; --i) makeChangeInner(doc, {
      'from': split[i].from,
      'to': split[i].to,
      'text': i ? [""] : change.text
    });
  } else {
    makeChangeInner(doc, change);
  }
}

makeChangeInner(doc, change) {
  if (change.text.length == 1 && change.text[0] == "" && cmp(change.from,
      change.to) == 0) return;
  var selAfter = computeSelAfterChange(doc, change);
  addChangeToHistory(doc, change, selAfter, doc.cm ? doc.cm.curOp.id :
      double.NAN);

  makeChangeSingleDoc(doc, change, selAfter, stretchSpansOverChange(doc, change)
      );
  var rebased = [];

  linkedDocs(doc, (doc, sharedHist) {
    if (!sharedHist && indexOf(rebased, doc.history) == -1) {
      rebaseHist(doc.history, change);
      rebased.push(doc.history);
    }
    makeChangeSingleDoc(doc, change, null, stretchSpansOverChange(doc, change));
  });
}

makeChangeFromHistory(doc, type, allowSelectionOnly) {
  if (doc.cm && doc.cm.state.suppressEdits) return;

  var hist = doc.history,
      event,
      selAfter = doc.sel;
  var source = type == "undo" ? hist.done : hist.undone,
      dest = type == "undo" ? hist.undone : hist.done;


  var i;
  for (i = 0; i < source.length; i++) {
    event = source[i];
    if (allowSelectionOnly ? event.ranges && !event.equals(doc.sel) :
        !event.ranges) break;
  }
  if (i == source.length) return;
  hist.lastOrigin = hist.lastSelOrigin = null;

  for ( ; ; ) {
    event = source.pop();
    if (event.ranges) {
      pushSelectionToHistory(event, dest);
      if (allowSelectionOnly && !event.equals(doc.sel)) {
        _setSelection(doc, event, {
          clearRedo: false
        });
        return;
      }
      selAfter = event;
    } else break;
  }



  var antiChanges = [];
  pushSelectionToHistory(selAfter, dest);
  dest.push({
    'changes': antiChanges,
    'generation': hist.generation
  });
  hist.generation = event.generation || ++hist.maxGeneration;

  var filter = hasHandler(doc, "beforeChange") || doc.cm && hasHandler(doc.cm,
      "beforeChange");

  for (var i = event.changes.length - 1; i >= 0; --i) {
    var change = event.changes[i];
    change.origin = type;
    if (filter && !filterChange(doc, change, false)) {
      source.length = 0;
      return;
    }

    antiChanges.push(historyChangeFromChange(doc, change));

    var after = i ? computeSelAfterChange(doc, change, null) : lst(source);
    makeChangeSingleDoc(doc, change, after, mergeOldSpans(doc, change));
    if (doc.cm) ensureCursorVisible(doc.cm);
    var rebased = [];


    linkedDocs(doc, (doc, sharedHist) {
      if (!sharedHist && indexOf(rebased, doc.history) == -1) {
        rebaseHist(doc.history, change);
        rebased.push(doc.history);
      }
      makeChangeSingleDoc(doc, change, null, mergeOldSpans(doc, change));
    });
  }
}

shiftDoc(doc, distance) {
  doc.first += distance;
  doc.sel = new Selection(map(doc.sel.ranges, (range) {
    return new Range(newPos(range.anchor.line + distance, range.anchor.ch),
        newPos(range.head.line + distance, range.head.ch));
  }), doc.sel.primIndex);
  if (doc.cm) regChange(doc.cm, doc.first, doc.first - distance, distance);
}

makeChangeSingleDoc(doc, change, selAfter, spans) {
  if (doc.cm && !doc.cm.curOp) return operation(doc.cm, makeChangeSingleDoc)(
      doc, change, selAfter, spans);

  if (change.to.line < doc.first) {
    shiftDoc(doc, change.text.length - 1 - (change.to.line - change.from.line));
    return null;
  }
  if (change.from.line > doc.lastLine()) return null;


  if (change.from.line < doc.first) {
    var shift = change.text.length - 1 - (doc.first - change.from.line);
    shiftDoc(doc, shift);
    change = {
      'from': newPos(doc.first, 0),
      'to': newPos(change.to.line + shift, change.to.ch),
      'text': [lst(change.text)],
      'origin': change.origin
    };
  }
  var last = doc.lastLine();
  if (change.to.line > last) {
    change = {
      'from': change.from,
      'to': newPos(last, getLine(doc, last).text.length),
      'text': [change.text[0]],
      'origin': change.origin
    };
  }

  change.removed = getBetween(doc, change.from, change.to);

  if (!selAfter) selAfter = computeSelAfterChange(doc, change, null);
  if (doc.cm) makeChangeSingleDocInEditor(doc.cm, change, spans); else
      updateDoc(doc, change, spans);
  setSelectionNoUndo(doc, selAfter, sel_dontScroll);
}

makeChangeSingleDocInEditor(cm, change, spans) {
  var doc = cm.doc,
      display = cm.display,
      from = change.from,
      to = change.to;

  var recomputeMaxLength = false,
      checkWidthStart = from.line;
  if (!cm.options.lineWrapping) {
    checkWidthStart = _lineNo(visualLine(getLine(doc, from.line)));
    doc.iter(checkWidthStart, to.line + 1, (line) {
      if (line == display.maxLine) {
        recomputeMaxLength = true;
        return true;
      }
    });
  }

  if (doc.sel.contains(change.from, change.to) > -1) cm.curOp.cursorActivity =
      true;

  updateDoc(doc, change, spans, estimateHeight(cm));

  if (!cm.options.lineWrapping) {
    doc.iter(checkWidthStart, from.line + change.text.length, (line) {
      var len = lineLength(line);
      if (len > display.maxLineLength) {
        display.maxLine = line;
        display.maxLineLength = len;
        display.maxLineChanged = true;
        recomputeMaxLength = false;
      }
    });
    if (recomputeMaxLength) cm.curOp.updateMaxLine = true;
  }


  doc.frontier = math.min(doc.frontier, from.line);
  startWorker(cm, 400);

  var lendiff = change.text.length - (to.line - from.line) - 1;

  if (from.line == to.line && change.text.length == 1 && !isWholeLineUpdate(
      cm.doc, change)) regLineChange(cm, from.line, "text"); else regChange(cm,
      from.line, to.line + 1, lendiff);

  if (hasHandler(cm, "change") || hasHandler(cm, "changes"))
      (cm.curOp.changeObjs || (cm.curOp.changeObjs = [])).push({
    'from': from,
    'to': to,
    'text': change.text,
    'removed': change.removed,
    'origin': change.origin
  });
}

replaceRange(doc, code, from, to, origin) {
  if (!to) to = from;
  if (cmp(to, from) < 0) {
    var tmp = to;
    to = from;
    from = tmp;
  }
  if (typeOfReplacement(code, "string")) code = splitLines(code);
  makeChange(doc, {
    'from': from,
    'to': to,
    'text': code,
    'origin': origin
  });
}

maybeScrollWindow(cm, coords) {
  var display = cm.display,
      box = display.sizer.getBoundingClientRect(),
      doScroll = null;
  if (coords.top + box.top < 0) doScroll = true; else if (coords.bottom +
      box.top > (window.innerHeight || document.documentElement.clientHeight))
      doScroll = false;
  if (doScroll != null && !phantom) {
    var scrollNode = elt("div", "\u200b", null, "position: absolute; top: " +
        (coords.top - display.viewOffset - paddingTop(cm.display)) + "px; height: " +
        (coords.bottom - coords.top + scrollerCutOff) + "px; left: " + coords.left +
        "px; width: 2px;");
    cm.display.lineSpace.appendChild(scrollNode);
    scrollNode.scrollIntoView(doScroll);
    cm.display.lineSpace.removeChild(scrollNode);
  }
}

scrollPosIntoView(cm, pos, end, margin) {
  if (margin == null) margin = 0;
  for ( ; ; ) {
    var changed = false,
        coords = cursorCoords(cm, pos);
    var endCoords = !end || end == pos ? coords : cursorCoords(cm, end);
    var scrollPos = calculateScrollPos(cm, math.min(coords.left, endCoords.left
        ), math.min(coords.top, endCoords.top) - margin, math.max(coords.left,
        endCoords.left), math.max(coords.bottom, endCoords.bottom) + margin);
    var startTop = cm.doc.scrollTop,
        startLeft = cm.doc.scrollLeft;
    if (scrollPos.scrollTop != null) {
      setScrollTop(cm, scrollPos.scrollTop);
      if ((cm.doc.scrollTop - startTop).abs() > 1) changed = true;
    }
    if (scrollPos.scrollLeft != null) {
      setScrollLeft(cm, scrollPos.scrollLeft);
      if ((cm.doc.scrollLeft - startLeft).abs() > 1) changed = true;
    }
    if (!changed) return coords;
  }
}

scrollIntoView(cm, x1, y1, x2, y2) {
  var scrollPos = calculateScrollPos(cm, x1, y1, x2, y2);
  if (scrollPos.scrollTop != null) setScrollTop(cm, scrollPos.scrollTop);
  if (scrollPos.scrollLeft != null) setScrollLeft(cm, scrollPos.scrollLeft);
}

calculateScrollPos(cm, x1, y1, x2, y2) {
  var display = cm.display,
      snapMargin = textHeight(cm.display);
  if (y1 < 0) y1 = 0;
  var screentop = cm.curOp && cm.curOp.scrollTop != null ? cm.curOp.scrollTop :
      display.scroller.scrollTop;
  var screen = display.scroller.clientHeight - scrollerCutOff,
      result = {};
  var docBottom = cm.doc.height + paddingVert(display);
  var atTop = y1 < snapMargin,
      atBottom = y2 > docBottom - snapMargin;
  if (y1 < screentop) {
    result.scrollTop = atTop ? 0 : y1;
  } else if (y2 > screentop + screen) {
    var newTop = math.min(y1, (atBottom ? docBottom : y2) - screen);
    if (newTop != screentop) result.scrollTop = newTop;
  }

  var screenleft = cm.curOp && cm.curOp.scrollLeft != null ? cm.curOp.scrollLeft
      : display.scroller.scrollLeft;
  var screenw = display.scroller.clientWidth - scrollerCutOff;
  x1 += display.gutters.offsetWidth;
  x2 += display.gutters.offsetWidth;
  var gutterw = display.gutters.offsetWidth;
  var atLeft = x1 < gutterw + 10;
  if (x1 < screenleft + gutterw || atLeft) {
    if (atLeft) x1 = 0;
    result.scrollLeft = math.max(0, x1 - 10 - gutterw);
  } else if (x2 > screenw + screenleft - 3) {
    result.scrollLeft = x2 + 10 - screenw;
  }
  return result;
}

addToScrollPos(cm, left, top) {
  if (left != null || top != null) resolveScrollToPos(cm);
  if (left != null) cm.curOp.scrollLeft = (cm.curOp.scrollLeft == null ?
      cm.doc.scrollLeft : cm.curOp.scrollLeft) + left;
  if (top != null) cm.curOp.scrollTop = (cm.curOp.scrollTop == null ?
      cm.doc.scrollTop : cm.curOp.scrollTop) + top;
}

ensureCursorVisible(cm) {
  resolveScrollToPos(cm);
  var cur = cm.getCursor(),
      from = cur,
      to = cur;
  if (!cm.options.lineWrapping) {
    from = cur.ch ? newPos(cur.line, cur.ch - 1) : cur;
    to = newPos(cur.line, cur.ch + 1);
  }
  cm.curOp.scrollToPos = {
    'from': from,
    'to': to,
    'margin': cm.options.cursorScrollMargin,
    'isCursor': true
  };
}

resolveScrollToPos(cm) {
  var range = cm.curOp.scrollToPos;
  if (range) {
    cm.curOp.scrollToPos = null;
    var from = estimateCoords(cm, range.from),
        to = estimateCoords(cm, range.to);
    var sPos = calculateScrollPos(cm, math.min(from.left, to.left), math.min(
        from.top, to.top) - range.margin, math.max(from.right, to.right), math.max(
        from.bottom, to.bottom) + range.margin);
    cm.scrollTo(sPos.scrollLeft, sPos.scrollTop);
  }
}

indentLine(cm, n, how, [aggressive]) {
  var doc = cm.doc,
      state;
  if (how == null) how = "add";
  if (how == "smart") {


    if (!cm.doc.mode.indent) how = "prev"; else state = getStateBefore(cm, n);
  }

  var tabSize = cm.options.tabSize;
  var line = getLine(doc, n),
      curSpace = countColumn(line.text, null, tabSize);
  if (line.stateAfter) line.stateAfter = null;
  var curSpaceString = line.text.match(new Refexp("/^\s*/"))[0],
      indentation;
  if (!aggressive && !new Refexp("/\S/").test(line.text)) {
    indentation = 0;
    how = "not";
  } else if (how == "smart") {
    indentation = cm.doc.mode.indent(state, line.text.slice(
        curSpaceString.length), line.text);
    if (indentation == Pass) {
      if (!aggressive) return;
      how = "prev";
    }
  }
  if (how == "prev") {
    if (n > doc.first) indentation = countColumn(getLine(doc, n - 1).text, null,
        tabSize); else indentation = 0;
  } else if (how == "add") {
    indentation = curSpace + cm.options.indentUnit;
  } else if (how == "subtract") {
    indentation = curSpace - cm.options.indentUnit;
  } else if (typeOfReplacement(how, "number")) {
    indentation = curSpace + how;
  }
  indentation = math.max(0, indentation);

  var indentString = "",
      pos = 0;
  if (cm.options.indentWithTabs) for (var i = (indentation / tabSize).floor();
      i; --i) {
    pos += tabSize;
    indentString += "\t";
  }
  if (pos < indentation) indentString += spaceStr(indentation - pos);

  if (indentString != curSpaceString) {
    replaceRange(cm.doc, indentString, newPos(n, 0), newPos(n,
        curSpaceString.length), "+input");
  } else {


    for (var i = 0; i < doc.sel.ranges.length; i++) {
      var range = doc.sel.ranges[i];
      if (range.head.line == n && range.head.ch < curSpaceString.length) {
        var pos = newPos(n, curSpaceString.length);
        replaceOneSelection(doc, i, new Range(pos, pos));
        break;
      }
    }
  }
  line.stateAfter = null;
}

changeLine(cm, handle, changeType, op) {
  var no = handle,
      line = handle,
      doc = cm.doc;
  if (typeOfReplacement(handle, "number")) line = getLine(doc, clipLine(doc,
      handle)); else no = _lineNo(handle);
  if (no == null) return null;
  if (op(line, no)) regLineChange(cm, no, changeType);
  return line;
}

deleteNearSelection(cm, compute) {
  var ranges = cm.doc.sel.ranges,
      kill = [];


  for (var i = 0; i < ranges.length; i++) {
    var toKill = compute(ranges[i]);
    while (kill.length && cmp(toKill.from, lst(kill).to) <= 0) {
      var replaced = kill.pop();
      if (cmp(replaced.from, toKill.from) < 0) {
        toKill.from = replaced.from;
        break;
      }
    }
    kill.push(toKill);
  }

  runInOp(cm, () {
    for (var i = kill.length - 1; i >= 0; i--) replaceRange(cm.doc, "",
        kill[i].from, kill[i].to, "+delete");
    ensureCursorVisible(cm);
  });
}

findPosH(doc, pos, dir, unit, visually) {
  var line = pos.line,
      ch = pos.ch,
      origDir = dir;
  var lineObj = getLine(doc, line);
  var possible = true;
  findNextLine() {
    var l = line + dir;
    if (l < doc.first || l >= doc.first + doc.size) return (possible = false);
    line = l;
    return lineObj = getLine(doc, l);
  }
  moveOnce([boundToLine]) {
    var next = (visually ? moveVisually : moveLogically)(lineObj, ch, dir, true
        );
    if (next == null) {
      if (!boundToLine && findNextLine()) {
        if (visually) ch = (dir < 0 ? lineRight : lineLeft)(lineObj); else ch =
            dir < 0 ? lineObj.text.length : 0;
      } else return (possible = false);
    } else ch = next;
    return true;
  }

  if (unit == "char") moveOnce(); else if (unit == "column") moveOnce(true);
      else if (unit == "word" || unit == "group") {
    var sawType = null,
        group = unit == "group";
    for (var first = true; ; first = false) {
      if (dir < 0 && !moveOnce(!first)) break;
      var cur = lineObj.text.charAt(ch) || "\n";
      var type = isWordChar(cur) ? "w" : group && cur == "\n" ? "n" : !group ||
          new Refexp("/\s/").test(cur) ? null : "p";
      if (group && !first && !type) type = "s";
      if (sawType && sawType != type) {
        if (dir < 0) {
          dir = 1;
          moveOnce();
        }
        break;
      }

      if (type) sawType = type;
      if (dir > 0 && !moveOnce(!first)) break;
    }
  }
  var result = skipAtomic(doc, newPos(line, ch), origDir, true);
  if (!possible) result.hitSide = true;
  return result;
}

findPosV(cm, pos, dir, unit) {
  var doc = cm.doc,
      x = pos.left,
      y;
  if (unit == "page") {
    
    //XXX
    var tst = window.innerHeight;
    var result = tst != 0 ? tst :
      document.documentElement.clientHeight;
    
    var pageSize = math.min(cm.display.wrapper.clientHeight, result);
    
    y = pos.top + dir * (pageSize - (dir < 0 ? 1.5 : .5) * textHeight(cm.display
        ));
  } else if (unit == "line") {
    y = dir > 0 ? pos.bottom + 3 : pos.top - 3;
  }
  for ( ; ; ) {
    var target = coordsChar(cm, x, y);
    if (!target.outside) break;
    if (dir < 0 ? y <= 0 : y >= doc.height) {
      target.hitSide = true;
      break;
    }
    y += dir * 5;
  }
  return target;
}

findWordAt(doc, pos) {
  var line = getLine(doc, pos.line).text;
  var start = pos.ch,
      end = pos.ch;
  if (line) {
    if ((pos.xRel < 0 || end == line.length) && start) --start; else ++end;
    var startChar = line.charAt(start);
    /*
      var check = isWordChar(startChar) ? isWordChar
        : new Refexp("/\s/.test(startChar) ? (ch) {return /\s/").test(ch);}
        : (ch) {return !new Refexp("/\s/").test(ch) && !isWordChar(ch);};
      while (start > 0 && check(line.charAt(start - 1))) --start;
      while (end < line.length && check(line.charAt(end))) ++end; */
  }
  return new Range(new Pos(pos.line, start), new Pos(pos.line, end));
}
