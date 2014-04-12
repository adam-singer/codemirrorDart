part of codemirror.dart;


loadMode(cm) {
  cm.doc.mode = CodeMirror.getMode(cm.options, cm.doc.modeOption);
  resetModeState(cm);
}

resetModeState(cm) {
  cm.doc.iter((line) {
    if (line.stateAfter) line.stateAfter = null;
    if (line.styles) line.styles = null;
  });
  cm.doc.frontier = cm.doc.first;
  startWorker(cm, 100);
  cm.state.modeGen++;
  if (cm.curOp) regChange(cm);
}

wrappingChanged(cm) {
  if (cm.options.lineWrapping) {
    addClass(cm.display.wrapper, "CodeMirror-wrap");
    cm.display.sizer.style.minWidth = "";
  } else {
    rmClass(cm.display.wrapper, "CodeMirror-wrap");
    findMaxLine(cm);
  }
  estimateLineHeights(cm);
  regChange(cm);
  clearCaches(cm);
  setTimeout(() {
    updateScrollbars(cm);
  }, 100);
}

estimateHeight(cm) {
  var th = textHeight(cm.display),
      wrapping = cm.options.lineWrapping;
  var perLine = wrapping && math.max(5, cm.display.scroller.clientWidth /
      charWidth(cm.display) - 3);
  return (line) {
    if (lineIsHidden(cm.doc, line)) return 0;

    var widgetsHeight = 0;
    if (line.widgets) for (var i = 0; i < line.widgets.length; i++) {
      if (line.widgets[i].height) widgetsHeight += line.widgets[i].height;
    }
    if (wrapping) return widgetsHeight + ((line.text.length / perLine).ceil()
        || 1) * th; else return widgetsHeight + th;
  };
}

estimateLineHeights(cm) {
  var doc = cm.doc,
      est = estimateHeight(cm);
  doc.iter((line) {
    var estHeight = est(line);
    if (estHeight != line.height) updateLineHeight(line, estHeight);
  });
}

keyMapChanged(cm) {
  var map = keyMap[cm.options.keyMap],
      style = map.style;
  cm.display.wrapper.className = cm.display.wrapper.className.replace(
      new Refexp("/\s*cm-keymap-\S+/g"), "") + (style ? " cm-keymap-" + style : "");
}

themeChanged(cm) {
  cm.display.wrapper.className = cm.display.wrapper.className.replace(
      new Refexp("/\s*cm-s-\S+/g"), "") + cm.options.theme.replace(new Refexp(
      "/(^|\s)\s*/g"), " cm-s-");
  clearCaches(cm);
}

guttersChanged(cm) {
  updateGutters(cm);
  regChange(cm);
  setTimeout(() {
    alignHorizontally(cm);
  }, 20);
}

updateGutters(cm) {
  var gutters = cm.display.gutters,
      specs = cm.options.gutters;
  removeChildren(gutters);
  var i = 0;
  for (; i < specs.length; ++i) {
    var gutterClass = specs[i];
    var gElt = gutters.appendChild(elt("div", null, "CodeMirror-gutter " +
        gutterClass));
    if (gutterClass == "CodeMirror-linenumbers") {
      cm.display.lineGutter = gElt;
      
      //XXX
      var tst = cm.display.lineNumWidth;
      
      gElt.style.width = (tst != 0 ? tst : 1).toString() + "px";
    }
  }
  gutters.style.display = i ? "" : "none";
  updateGutterSpace(cm);
}

updateGutterSpace(cm) {
  var width = cm.display.gutters.offsetWidth;
  cm.display.sizer.style.marginLeft = width + "px";
  cm.display.scrollbarH.style.left = cm.options.fixedGutter ? width + "px" : 0;
}

lineLength(line) {
  if (line.height == 0) return 0;
  var len = line.text.length,
      merged,
      cur = line;
  while (merged = collapsedSpanAtStart(cur)) {
    var found = merged.find(0, true);
    cur = found.from.line;
    len += found.from.ch - found.to.ch;
  }
  cur = line;
  while (merged = collapsedSpanAtEnd(cur)) {
    var found = merged.find(0, true);
    len -= cur.text.length - found.from.ch;
    cur = found.to.line;
    len += cur.text.length - found.to.ch;
  }
  return len;
}

findMaxLine(cm) {
  var d = cm.display,
      doc = cm.doc;
  d.maxLine = getLine(doc, doc.first);
  d.maxLineLength = lineLength(d.maxLine);
  d.maxLineChanged = true;
  doc.iter((line) {
    var len = lineLength(line);
    if (len > d.maxLineLength) {
      d.maxLineLength = len;
      d.maxLine = line;
    }
  });
}

setGuttersForLineNumbers(options) {
  var found = indexOf(options.gutters, "CodeMirror-linenumbers");
  if (found == -1 && options.lineNumbers) {
    options.gutters = options.gutters.concat(["CodeMirror-linenumbers"]);
  } else if (found > -1 && !options.lineNumbers) {
    options.gutters = options.gutters.slice(0);
    options.gutters.splice(found, 1);
  }
}

measureForScrollbars(cm) {
  var scroll = cm.display.scroller;
  return {
    'clientHeight': scroll.clientHeight,
    'barHeight': cm.display.scrollbarV.clientHeight,
    'scrollWidth': scroll.scrollWidth,
    'clientWidth': scroll.clientWidth,
    'barWidth': cm.display.scrollbarH.clientWidth,
    'docHeight': (cm.doc.height + paddingVert(cm.display)).round()
  };
}

updateScrollbars(cm, [measure]) {
  if (measure == null) measure = measureForScrollbars(cm);
  var d = cm.display;
  var scrollHeight = measure.docHeight + scrollerCutOff;
  var needsH = measure.scrollWidth > measure.clientWidth;
  var needsV = scrollHeight > measure.clientHeight;
  if (needsV) {
    d.scrollbarV.style.display = "block";
    d.scrollbarV.style.bottom = needsH ? scrollbarWidth(d.measure) + "px" : "0";

    d.scrollbarV.firstChild.style.height = math.max(0, scrollHeight -
        measure.clientHeight + (measure.barHeight || d.scrollbarV.clientHeight)).toString() + "px";
  } else {
    d.scrollbarV.style.display = "";
    d.scrollbarV.firstChild.style.height = "0";
  }
  if (needsH) {
    d.scrollbarH.style.display = "block";
    d.scrollbarH.style.right = needsV ? scrollbarWidth(d.measure) + "px" : "0";
    d.scrollbarH.firstChild.style.width = (measure.scrollWidth -
        measure.clientWidth + (measure.barWidth || d.scrollbarH.clientWidth)) + "px";
  } else {
    d.scrollbarH.style.display = "";
    d.scrollbarH.firstChild.style.width = "0";
  }
  if (needsH && needsV) {
    d.scrollbarFiller.style.display = "block";
    d.scrollbarFiller.style.height = d.scrollbarFiller.style.width =
        scrollbarWidth(d.measure) + "px";
  } else d.scrollbarFiller.style.display = "";
  if (needsH && cm.options.coverGutterNextToScrollbar && cm.options.fixedGutter)
      {
    d.gutterFiller.style.display = "block";
    d.gutterFiller.style.height = scrollbarWidth(d.measure) + "px";
    d.gutterFiller.style.width = d.gutters.offsetWidth + "px";
  } else d.gutterFiller.style.display = "";

  if (mac_geLion && scrollbarWidth(d.measure) == 0) {
    d.scrollbarV.style.minWidth = d.scrollbarH.style.minHeight =
        mac_geMountainLion ? "18px" : "12px";
    var barMouseDown = (e) {
      if (e_target(e) != d.scrollbarV && e_target(e) != d.scrollbarH) operation(
          cm, onMouseDown)(e);
    };
    _on(d.scrollbarV, "mousedown", barMouseDown);
    _on(d.scrollbarH, "mousedown", barMouseDown);
  }
}

visibleLines(display, doc, [viewPort]) {
  var top = viewPort && viewPort.top != null ? viewPort.top :
      display.scroller.scrollTop;
  top = (top - paddingTop(display)).floor();
  var bottom = viewPort && viewPort.bottom != null ? viewPort.bottom : top +
      display.wrapper.clientHeight;

  var from = lineAtHeight(doc, top),
      to = lineAtHeight(doc, bottom);


  if (viewPort && viewPort.ensure) {
    var ensureFrom = viewPort.ensure.from.line,
        ensureTo = viewPort.ensure.to.line;
    if (ensureFrom < from) return {
      from: ensureFrom,
      to: lineAtHeight(doc, heightAtLine(getLine(doc, ensureFrom)) +
          display.wrapper.clientHeight)
    };
    if (math.min(ensureTo, doc.lastLine()) >= to) return {
      from: lineAtHeight(doc, heightAtLine(getLine(doc, ensureTo)) -
          display.wrapper.clientHeight),
      to: ensureTo
    };
  }
  return {
    from: from,
    to: to
  };
}

alignHorizontally(cm) {
  var display = cm.display,
      view = display.view;
  if (!display.alignWidgets && (!display.gutters.firstChild ||
      !cm.options.fixedGutter)) return;
  var comp = compensateForHScroll(display) - display.scroller.scrollLeft +
      cm.doc.scrollLeft;
  var gutterW = display.gutters.offsetWidth,
      left = comp + "px";
  for (var i = 0; i < view.length; i++) if (!view[i].hidden) {
    if (cm.options.fixedGutter && view[i].gutter) view[i].gutter.style.left =
        left;
    var align = view[i].alignable;
    if (align) for (var j = 0; j < align.length; j++) align[j].style.left =
        left;
  }
  if (cm.options.fixedGutter) display.gutters.style.left = (comp + gutterW) +
      "px";
}

maybeUpdateLineNumberWidth(cm) {
  if (!cm.options.lineNumbers) return false;
  var doc = cm.doc,
      last = lineNumberFor(cm.options, doc.first + doc.size - 1),
      display = cm.display;
  if (last.length != display.lineNumChars) {
    var test = display.measure.appendChild(elt("div", [elt("div", last)],
        "CodeMirror-linenumber CodeMirror-gutter-elt"));
    var innerW = test.firstChild.offsetWidth,
        padding = test.offsetWidth - innerW;
    display.lineGutter.style.width = "";
    display.lineNumInnerWidth = math.max(innerW, display.lineGutter.offsetWidth
        - padding);
    display.lineNumWidth = display.lineNumInnerWidth + padding;
    display.lineNumChars = display.lineNumInnerWidth ? last.length : -1;
    display.lineGutter.style.width = display.lineNumWidth + "px";
    updateGutterSpace(cm);
    return true;
  }
  return false;
}

lineNumberFor(options, i) {
  return options.lineNumberFormatter(i + options.firstLineNumber).toString();
}

compensateForHScroll(display) {
  return display.scroller.getBoundingClientRect().left -
      display.sizer.getBoundingClientRect().left;
}

updateDisplay(cm, [viewPort, forced]) {
  var oldFrom = cm.display.viewFrom,
      oldTo = cm.display.viewTo,
      updated;
  var visible = visibleLines(cm.display, cm.doc, viewPort);
  for (var first = true; ; first = false) {
    var oldWidth = cm.display.scroller.clientWidth;
    if (!updateDisplayInner(cm, visible, forced)) break;
    updated = true;



    if (cm.display.maxLineChanged && !cm.options.lineWrapping)
        adjustContentWidth(cm);

    var barMeasure = measureForScrollbars(cm);
    updateSelection(cm);
    setDocumentHeight(cm, barMeasure);
    updateScrollbars(cm, barMeasure);
    if (webkit && cm.options.lineWrapping) checkForWebkitWidthBug(cm, barMeasure
        );
    if (first && cm.options.lineWrapping && oldWidth !=
        cm.display.scroller.clientWidth) {
      forced = true;
      continue;
    }
    forced = false;


    if (viewPort && viewPort.top != null) viewPort = {
      'top': math.min(barMeasure.docHeight - scrollerCutOff -
          barMeasure.clientHeight, viewPort.top)
    };


    visible = visibleLines(cm.display, cm.doc, viewPort);
    if (visible.from >= cm.display.viewFrom && visible.to <= cm.display.viewTo)
        break;
  }

  cm.display.updateLineNumbers = null;
  if (updated) {
    signalLater(cm, "update", cm);
    if (cm.display.viewFrom != oldFrom || cm.display.viewTo != oldTo)
        signalLater(cm, "viewportChange", cm, cm.display.viewFrom, cm.display.viewTo);
  }
  return updated;
}

updateDisplayInner(cm, visible, forced) {
  var display = cm.display,
      doc = cm.doc;
  if (!display.wrapper.offsetWidth) {
    resetView(cm);
    return false;
  }


  if (!forced && visible.from >= display.viewFrom && visible.to <=
      display.viewTo && countDirtyView(cm) == 0) return false;

  if (maybeUpdateLineNumberWidth(cm)) resetView(cm);
  var dims = getDimensions(cm);


  var end = doc.first + doc.size;
  var from = math.max(visible.from - cm.options.viewportMargin, doc.first);
  var to = math.min(end, visible.to + cm.options.viewportMargin);
  if (display.viewFrom < from && from - display.viewFrom < 20) from = math.max(
      doc.first, display.viewFrom);
  if (display.viewTo > to && display.viewTo - to < 20) to = math.min(end,
      display.viewTo);
  if (sawCollapsedSpans) {
    from = visualLineNo(cm.doc, from);
    to = visualLineEndNo(cm.doc, to);
  }

  var different = from != display.viewFrom || to != display.viewTo ||
      display.lastSizeC != display.wrapper.clientHeight;
  adjustView(cm, from, to);

  display.viewOffset = heightAtLine(getLine(cm.doc, display.viewFrom));

  cm.display.mover.style.top = display.viewOffset + "px";

  var toUpdate = countDirtyView(cm);
  if (!different && toUpdate == 0 && !forced) return false;



  var focused = activeElt();
  if (toUpdate > 4) display.lineDiv.style.display = "none";
  patchDisplay(cm, display.updateLineNumbers, dims);
  if (toUpdate > 4) display.lineDiv.style.display = "";


  if (focused && activeElt() != focused && focused.offsetHeight) focused.focus(
      );



  removeChildren(display.cursorDiv);
  removeChildren(display.selectionDiv);

  if (different) {
    display.lastSizeC = display.wrapper.clientHeight;
    startWorker(cm, 400);
  }

  updateHeightsInViewport(cm);

  return true;
}

adjustContentWidth(cm) {
  var display = cm.display;
  var width = measureChar(cm, display.maxLine, display.maxLine.text.length
      ).left;
  display.maxLineChanged = false;
  var minWidth = math.max(0, width + 3);
  var maxScrollLeft = math.max(0, display.sizer.offsetLeft + minWidth +
      scrollerCutOff - display.scroller.clientWidth);
  display.sizer.style.minWidth = minWidth + "px";
  if (maxScrollLeft < cm.doc.scrollLeft) setScrollLeft(cm, math.min(
      display.scroller.scrollLeft, maxScrollLeft), true);
}

setDocumentHeight(cm, measure) {
  cm.display.sizer.style.minHeight = cm.display.heightForcer.style.top =
      measure.docHeight + "px";
  cm.display.gutters.style.height = math.max(measure.docHeight,
      measure.clientHeight - scrollerCutOff).toString() + "px";
}

checkForWebkitWidthBug(cm, measure) {


  if (cm.display.sizer.offsetWidth + cm.display.gutters.offsetWidth <
      cm.display.scroller.clientWidth - 1) {
    cm.display.sizer.style.minHeight = cm.display.heightForcer.style.top =
        "0px";
    cm.display.gutters.style.height = measure.docHeight + "px";
  }
}

updateHeightsInViewport(cm) {
  var display = cm.display;
  var prevBottom = display.lineDiv.offsetTop;
  for (var i = 0; i < display.view.length; i++) {
    var cur = display.view[i],
        height;
    if (cur.hidden) continue;
    if (ie_upto7) {
      var bot = cur.node.offsetTop + cur.node.offsetHeight;
      height = bot - prevBottom;
      prevBottom = bot;
    } else {
      var box = cur.node.getBoundingClientRect();
      height = box.bottom - box.top;
    }
    var diff = cur.line.height - height;
    if (height < 2) height = textHeight(display);
    if (diff > .001 || diff < -.001) {
      updateLineHeight(cur.line, height);
      updateWidgetHeight(cur.line);
      if (cur.rest) for (var j = 0; j < cur.rest.length; j++)
          updateWidgetHeight(cur.rest[j]);
    }
  }
}

updateWidgetHeight(line) {
  if (line.widgets) for (var i = 0; i < line.widgets.length; ++i)
      line.widgets[i].height = line.widgets[i].node.offsetHeight;
}

getDimensions(cm) {
  var d = cm.display,
      left = {},
      width = {};
  for (var n = d.gutters.firstChild,
      i = 0; n; n = n.nextSibling, ++i) {
    left[cm.options.gutters[i]] = n.offsetLeft;
    width[cm.options.gutters[i]] = n.offsetWidth;
  }
  return {
    'fixedPos': compensateForHScroll(d),
    'gutterTotalWidth': d.gutters.offsetWidth,
    'gutterLeft': left,
    'gutterWidth': width,
    'wrapperWidth': d.wrapper.clientWidth
  };
}

patchDisplay(cm, updateNumbersFrom, dims) {
  var display = cm.display,
      lineNumbers = cm.options.lineNumbers;
  var container = display.lineDiv,
      cur = container.firstChild;

  rm(node) {
    var next = node.nextSibling;

    if (webkit && mac && cm.display.currentWheelTarget == node)
        node.style.display = "none"; else node.parentNode.removeChild(node);
    return next;
  }

  var view = display.view,
      lineN = display.viewFrom;


  for (var i = 0; i < view.length; i++) {
    var lineView = view[i];
    if (lineView.hidden) {
    } else if (!lineView.node) {
      var node = buildLineElement(cm, lineView, lineN, dims);
      container.insertBefore(node, cur);
    } else {
      while (cur != lineView.node) cur = rm(cur);
      var updateNumber = lineNumbers && updateNumbersFrom != null &&
          updateNumbersFrom <= lineN && lineView.lineNumber;
      if (lineView.changes) {
        if (indexOf(lineView.changes, "gutter") > -1) updateNumber = false;
        updateLineForChanges(cm, lineView, lineN, dims);
      }
      if (updateNumber) {
        removeChildren(lineView.lineNumber);
        lineView.lineNumber.appendChild(document.createTextNode(lineNumberFor(
            cm.options, lineN)));
      }
      cur = lineView.node.nextSibling;
    }
    lineN += lineView.size;
  }
  while (cur) cur = rm(cur);
}

updateLineForChanges(cm, lineView, lineN, dims) {
  for (var j = 0; j < lineView.changes.length; j++) {
    var type = lineView.changes[j];
    if (type == "text") updateLineText(cm, lineView); else if (type == "gutter")
        updateLineGutter(cm, lineView, lineN, dims); else if (type == "class")
        updateLineClasses(lineView); else if (type == "widget") updateLineWidgets(
        lineView, dims);
  }
  lineView.changes = null;
}

ensureLineWrapped(lineView) {
  if (lineView.node == lineView.text) {
    lineView.node = elt("div", null, null, "position: relative");
    if (lineView.text.parentNode) lineView.text.parentNode.replaceChild(
        lineView.node, lineView.text);
    lineView.node.appendChild(lineView.text);
    if (ie_upto7) lineView.node.style.zIndex = 2;
  }
  return lineView.node;
}

updateLineBackground(lineView) {
  var cls = lineView.bgClass ? lineView.bgClass + " " + (lineView.line.bgClass
      || "") : lineView.line.bgClass;
  if (cls) cls += " CodeMirror-linebackground";
  if (lineView.background) {
    if (cls) lineView.background.className = cls; else {
      lineView.background.parentNode.removeChild(lineView.background);
      lineView.background = null;
    }
  } else if (cls) {
    var wrap = ensureLineWrapped(lineView);
    lineView.background = wrap.insertBefore(elt("div", null, cls),
        wrap.firstChild);
  }
}

getLineContent(cm, lineView) {
  var ext = cm.display.externalMeasured;
  if (ext && ext.line == lineView.line) {
    cm.display.externalMeasured = null;
    lineView.measure = ext.measure;
    return ext.built;
  }
  return buildLineContent(cm, lineView);
}

updateLineText(cm, lineView) {
  var cls = lineView.text.className;
  var built = getLineContent(cm, lineView);
  if (lineView.text == lineView.node) lineView.node = built.pre;
  lineView.text.parentNode.replaceChild(built.pre, lineView.text);
  lineView.text = built.pre;
  if (built.bgClass != lineView.bgClass || built.textClass !=
      lineView.textClass) {
    lineView.bgClass = built.bgClass;
    lineView.textClass = built.textClass;
    updateLineClasses(lineView);
  } else if (cls) {
    lineView.text.className = cls;
  }
}

updateLineClasses(lineView) {
  updateLineBackground(lineView);
  if (lineView.line.wrapClass) ensureLineWrapped(lineView).className =
      lineView.line.wrapClass; else if (lineView.node != lineView.text)
      lineView.node.className = "";
  var textClass = lineView.textClass ? lineView.textClass + " " +
      (lineView.line.textClass || "") : lineView.line.textClass;
  lineView.text.className = textClass || "";
}

updateLineGutter(cm, lineView, lineN, dims) {
  if (lineView.gutter) {
    lineView.node.removeChild(lineView.gutter);
    lineView.gutter = null;
  }
  var markers = lineView.line.gutterMarkers;
  if (cm.options.lineNumbers || markers) {
    var wrap = ensureLineWrapped(lineView);
    var gutterWrap = lineView.gutter = wrap.insertBefore(elt("div", null,
        "CodeMirror-gutter-wrapper", "position: absolute; left: " +
        (cm.options.fixedGutter ? dims.fixedPos : -dims.gutterTotalWidth) + "px"),
        lineView.text);
    if (cm.options.lineNumbers && (!markers ||
        !markers["CodeMirror-linenumbers"])) lineView.lineNumber =
        gutterWrap.appendChild(elt("div", lineNumberFor(cm.options, lineN),
        "CodeMirror-linenumber CodeMirror-gutter-elt", "left: " +
        dims.gutterLeft["CodeMirror-linenumbers"] + "px; width: " +
        cm.display.lineNumInnerWidth + "px"));
    if (markers) for (var k = 0; k < cm.options.gutters.length; ++k) {
      var id = cm.options.gutters[k],
          found = markers.hasOwnProperty(id) && markers[id];
      if (found) gutterWrap.appendChild(elt("div", [found],
          "CodeMirror-gutter-elt", "left: " + dims.gutterLeft[id] + "px; width: " +
          dims.gutterWidth[id] + "px"));
    }
  }
}
