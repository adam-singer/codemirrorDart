part of codemirror.dart;


option(name, deflt, handle, notOnInit) {
  CodeMirror.defaults[name] = deflt;
  if (handle) optionHandlers[name] = notOnInit ? (cm, val, old) {
    if (old != Init) handle(cm, val, old);
  } : handle;
}

getKeyMap(val) {
  if (typeOfReplacement(val, "string")) {
    return keyMap[val];
  } else {
    return val;
  }
}

markText(doc, from, to, options, type) {



  if (options && options.shared) return markTextShared(doc, from, to, options,
      type);

  if (doc.cm && !doc.cm.curOp) return operation(doc.cm, markText)(doc, from, to,
      options, type);

  var marker = new TextMarker(doc, type),
      diff = cmp(from, to);
  if (options) copyObj(options, marker, false);

  if (diff > 0 || diff == 0 && marker.clearWhenEmpty != false) return marker;
  if (marker.replacedWith) {

    marker.collapsed = true;
    marker.widgetNode = elt("span", [marker.replacedWith], "CodeMirror-widget");
    if (!options.handleMouseEvents) marker.widgetNode.ignoreEvents = true;
    if (options.insertLeft) marker.widgetNode.insertLeft = true;
  }
  if (marker.collapsed) {
    if (conflictingCollapsedRange(doc, from.line, from, to, marker) || from.line
        != to.line && conflictingCollapsedRange(doc, to.line, from, to, marker)) throw
        new Exception("Inserting collapsed marker partially overlapping an existing one");
    sawCollapsedSpans = true;
  }

  if (marker.addToHistory) addChangeToHistory(doc, {
    'from': from,
    'to': to,
    'origin': "markText"
  }, doc.sel, double.NAN);

  var curLine = from.line,
      cm = doc.cm,
      updateMaxLine;
  doc.iter(curLine, to.line + 1, (line) {
    if (cm && marker.collapsed && !cm.options.lineWrapping && visualLine(line)
        == cm.display.maxLine) updateMaxLine = true;
    if (marker.collapsed && curLine != from.line) updateLineHeight(line, 0);
    addMarkedSpan(line, new MarkedSpan(marker, curLine == from.line ? from.ch :
        null, curLine == to.line ? to.ch : null));
    ++curLine;
  });

  if (marker.collapsed) doc.iter(from.line, to.line + 1, (line) {
    if (lineIsHidden(doc, line)) updateLineHeight(line, 0);
  });

  if (marker.clearOnEnter) _on(marker, "beforeCursorEnter", () {
    marker.clear();
  });

  if (marker.readOnly) {
    sawReadOnlySpans = true;
    if (doc.history.done.length || doc.history.undone.length) doc.clearHistory(
        );
  }
  if (marker.collapsed) {
    marker.id = ++nextMarkerId;
    marker.atomic = true;
  }
  if (cm) {

    if (updateMaxLine) cm.curOp.updateMaxLine = true;
    if (marker.collapsed) {
      regChange(cm, from.line, to.line + 1);
    } else if (marker.className || marker.title || marker.startStyle ||
        marker.endStyle) for (var i = from.line; i <= to.line; i++) regLineChange(cm, i,
        "text");
    if (marker.atomic) reCheckSelection(cm.doc);
    signalLater(cm, "markerAdded", cm, marker);
  }
  return marker;
}

markTextShared(doc, from, to, options, type) {
  options = copyObj(options);
  options.shared = false;
  var markers = [markText(doc, from, to, options, type)],
      primary = markers[0];
  var widget = options.widgetNode;
  linkedDocs(doc, (doc) {
    if (widget) options.widgetNode = widget.cloneNode(true);
    markers.push(markText(doc, _clipPos(doc, from), _clipPos(doc, to), options,
        type));
    for (var i = 0; i < doc.linked.length; ++i) if (doc.linked[i].isParent)
        return;
    primary = lst(markers);
  });
  return new SharedTextMarker(markers, primary);
}

findSharedMarkers(doc) {
  return doc.findMarks(newPos(doc.first, 0), doc.clipPos(newPos(doc.lastLine())
      ), (m) {
    return m.parent;
  });
}

copySharedMarkers(doc, markers) {
  for (var i = 0; i < markers.length; i++) {
    var marker = markers[i],
        pos = marker.find();
    var mFrom = doc.clipPos(pos.from),
        mTo = doc.clipPos(pos.to);
    if (cmp(mFrom, mTo)) {
      var subMark = markText(doc, mFrom, mTo, marker.primary,
          marker.primary.type);
      marker.markers.push(subMark);
      subMark.parent = marker;
    }
  }
}

detachSharedMarkers(markers) {
  for (var i = 0; i < markers.length; i++) {
    var marker = markers[i],
        linked = [marker.primary.doc];

    linkedDocs(marker.primary.doc, (d) {
      linked.push(d);
    });
    for (var j = 0; j < marker.markers.length; j++) {
      var subMarker = marker.markers[j];
      if (indexOf(linked, subMarker.doc) == -1) {
        subMarker.parent = null;
        marker.markers.splice(j--, 1);
      }
    }
  }
}


extraLeft(marker) {
  return marker.inclusiveLeft ? -1 : 0;
}

extraRight(marker) {
  return marker.inclusiveRight ? 1 : 0;
}

compareCollapsedMarkers(a, b) {
  var lenDiff = a.lines.length - b.lines.length;
  if (lenDiff != 0) return lenDiff;
  var aPos = a.find(),
      bPos = b.find();
  var fromCmp = cmp(aPos.from, bPos.from) || extraLeft(a) - extraLeft(b);
  if (fromCmp) return -fromCmp;
  var toCmp = cmp(aPos.to, bPos.to) || extraRight(a) - extraRight(b);
  if (toCmp) return toCmp;
  return b.id - a.id;
}

collapsedSpanAtSide(line, start) {
  var sps = sawCollapsedSpans && line.markedSpans,
      found;
  if (sps) for (var sp,
      i = 0; i < sps.length; ++i) {
    sp = sps[i];
    if (sp.marker.collapsed && (start ? sp.from : sp.to) == null && (!found ||
        compareCollapsedMarkers(found, sp.marker) < 0)) found = sp.marker;
  }
  return found;
}

collapsedSpanAtStart(line) {
  return collapsedSpanAtSide(line, true);
}

collapsedSpanAtEnd(line) {
  return collapsedSpanAtSide(line, false);
}

conflictingCollapsedRange(doc, lineNo, from, to, marker) {
  var line = getLine(doc, lineNo);
  var sps = sawCollapsedSpans && line.markedSpans;
  if (sps) for (var i = 0; i < sps.length; ++i) {
    var sp = sps[i];
    if (!sp.marker.collapsed) continue;
    var found = sp.marker.find(0);
    var fromCmp = cmp(found.from, from) || extraLeft(sp.marker) - extraLeft(
        marker);
    var toCmp = cmp(found.to, to) || extraRight(sp.marker) - extraRight(marker);
    if (fromCmp >= 0 && toCmp <= 0 || fromCmp <= 0 && toCmp >= 0) continue;
    if (fromCmp <= 0 && (cmp(found.to, from) || extraRight(sp.marker) -
        extraLeft(marker)) > 0 || fromCmp >= 0 && (cmp(found.from, to) || extraLeft(
        sp.marker) - extraRight(marker)) < 0) return true;
  }
}

visualLine(line) {
  var merged;
  while (merged = collapsedSpanAtStart(line)) line = merged.find(-1, true).line;
  return line;
}

visualLineContinued(line) {
  var merged, lines;
  while (merged = collapsedSpanAtEnd(line)) {
    line = merged.find(1, true).line;
    (lines || (lines = [])).push(line);
  }
  return lines;
}

visualLineNo(doc, lineN) {
  var line = getLine(doc, lineN),
      vis = visualLine(line);
  if (line == vis) return lineN;
  return _lineNo(vis);
}

visualLineEndNo(doc, lineN) {
  if (lineN > doc.lastLine()) return lineN;
  var line = getLine(doc, lineN),
      merged;
  if (!lineIsHidden(doc, line)) return lineN;
  while (merged = collapsedSpanAtEnd(line)) line = merged.find(1, true).line;
  return _lineNo(line) + 1;
}

lineIsHidden(doc, line) {
  var sps = sawCollapsedSpans && line.markedSpans;
  if (sps) for (var sp,
      i = 0; i < sps.length; ++i) {
    sp = sps[i];
    if (!sp.marker.collapsed) continue;
    if (sp.from == null) return true;
    if (sp.marker.widgetNode) continue;
    if (sp.from == 0 && sp.marker.inclusiveLeft && lineIsHiddenInner(doc, line,
        sp)) return true;
  }
}

lineIsHiddenInner(doc, line, span) {
  if (span.to == null) {
    var end = span.marker.find(1, true);
    return lineIsHiddenInner(doc, end.line, getMarkedSpanFor(
        end.line.markedSpans, span.marker));
  }
  if (span.marker.inclusiveRight && span.to == line.text.length) return true;
  for (var sp,
      i = 0; i < line.markedSpans.length; ++i) {
    sp = line.markedSpans[i];
    if (sp.marker.collapsed && !sp.marker.widgetNode && sp.from == span.to &&
        (sp.to == null || sp.to != span.from) && (sp.marker.inclusiveLeft ||
        span.marker.inclusiveRight) && lineIsHiddenInner(doc, line, sp)) return true;
  }
}

adjustScrollWhenAboveVisible(cm, line, diff) {
  if (heightAtLine(line) < ((cm.curOp && cm.curOp.scrollTop) ||
      cm.doc.scrollTop)) addToScrollPos(cm, null, diff);
}

widgetHeight(widget) {
  if (widget.height != null) return widget.height;
  if (!contains(document.body, widget.node)) removeChildrenAndAdd(
      widget.cm.display.measure, elt("div", [widget.node], null, "position: relative")
      );
  return widget.height = widget.node.offsetHeight;
}

addLineWidget(cm, handle, node, options) {
  var widget = new LineWidget(cm, node, options);
  if (widget.noHScroll) cm.display.alignWidgets = true;
  changeLine(cm, handle, "widget", (line) {
    var widgets = line.widgets || (line.widgets = []);
    if (widget.insertAt == null) {
      widgets.push(widget);
    } else {
      widgets.splice(math.min(widgets.length - 1, math.max(0, widget.insertAt)),
          0, widget);
    }
    widget.line = line;
    if (!lineIsHidden(cm.doc, line)) {
      var aboveVisible = heightAtLine(line) < cm.doc.scrollTop;
      updateLineHeight(line, line.height + widgetHeight(widget));
      if (aboveVisible) addToScrollPos(cm, null, widget.height);
      cm.curOp.forceUpdate = true;
    }
    return true;
  });
  return widget;
}

updateLine(line, text, markedSpans, estimateHeight) {
  line.text = text;
  if (line.stateAfter) line.stateAfter = null;
  if (line.styles) line.styles = null;
  if (line.order != null) line.order = null;
  detachMarkedSpans(line);
  attachMarkedSpans(line, markedSpans);
  var estHeight = estimateHeight ? estimateHeight(line) : 1;
  if (estHeight != line.height) updateLineHeight(line, estHeight);
}

cleanUpLine(line) {
  line.parent = null;
  detachMarkedSpans(line);
}

extractLineClasses(type, output) {
  if (type) for ( ; ; ) {
    var lineClass = type.match(new Refexp("/(?:^|\s+)line-(background-)?(\S+)/")
        );
    if (!lineClass) break;
    type = type.slice(0, lineClass.index) + type.slice(lineClass.index +
        lineClass[0].length);
    var prop = lineClass[1] ? "bgClass" : "textClass";
    if (output[prop] == null) {
      output[prop] = lineClass[2];
    } else if (!(new RegExp("(?:^|\s)" + lineClass[2] + "(?:\$|\s)")).test(
        output[prop])) output[prop] += " " + lineClass[2];
  }
  return type;
}

callBlankLine(mode, state) {
  if (mode.blankLine) return mode.blankLine(state);
  if (!mode.innerMode) return null;
  var inner = CodeMirror.innerMode(mode, state);
  if (inner.mode.blankLine) return inner.mode.blankLine(inner.state);
}

readToken(mode, stream, state) {
  var style = mode.token(stream, state);
  if (stream.pos <= stream.start) throw new Exception("Mode " + mode.name +
      " failed to advance stream.");
  return style;
}

runMode(cm, text, mode, state, f, lineClasses, [forceToEnd]) {
  var flattenSpans = mode.flattenSpans;
  if (flattenSpans == null) flattenSpans = cm.options.flattenSpans;
  var curStart = 0,
      curStyle = null;
  var stream = new StringStream(text, cm.options.tabSize),
      style;
  if (text == "") extractLineClasses(callBlankLine(mode, state), lineClasses);
  while (!stream.eol()) {
    if (stream.pos > cm.options.maxHighlightLength) {
      flattenSpans = false;
      if (forceToEnd) processLine(cm, text, state, stream.pos);
      stream.pos = text.length;
      style = null;
    } else {
      style = extractLineClasses(readToken(mode, stream, state), lineClasses);
    }
    if (cm.options.addModeClass) {
      var mName = CodeMirror.innerMode(mode, state).mode.name;
      if (mName) style = "m-" + (style ? mName + " " + style : mName);
    }
    if (!flattenSpans || curStyle != style) {
      if (curStart < stream.start) f(stream.start, curStyle);
      curStart = stream.start;
      curStyle = style;
    }
    stream.start = stream.pos;
  }
  while (curStart < stream.pos) {

    var pos = math.min(stream.pos, curStart + 50000);
    f(pos, curStyle);
    curStart = pos;
  }
}

highlightLine(cm, line, state, forceToEnd) {


  var st = [cm.state.modeGen],
      lineClasses = {};

  runMode(cm, line.text, cm.doc.mode, state, (end, style) {
    st.push(end, style);
  }, lineClasses, forceToEnd);


  for (var o = 0; o < cm.state.overlays.length; ++o) {
    var overlay = cm.state.overlays[o],
        i = 1,
        at = 0;
    runMode(cm, line.text, overlay.mode, true, (end, style) {
      var start = i;

      while (at < end) {
        var i_end = st[i];
        if (i_end > end) st.splice(i, 1, end, st[i + 1], i_end);
        i += 2;
        at = math.min(end, i_end);
      }
      if (!style) return;
      if (overlay.opaque) {
        st.splice(start, i - start, end, style);
        i = start + 2;
      } else {
        for ( ; start < i; start += 2) {
          var cur = st[start + 1];
          st[start + 1] = cur ? cur + " " + style : style;
        }
      }
    }, lineClasses);
  }

  return {
    'styles': st,
    'classes': lineClasses.bgClass || lineClasses.textClass ? lineClasses : null
  };
}

getLineStyles(cm, line) {
  if (!line.styles || line.styles[0] != cm.state.modeGen) {
    var result = highlightLine(cm, line, line.stateAfter = getStateBefore(cm,
        _lineNo(line)));
    line.styles = result.styles;
    if (result.classes) {
      line.styleClasses = result.classes;
    } else if (line.styleClasses) line.styleClasses = null;
  }
  return line.styles;
}

processLine(cm, text, state, [startAt]) {
  var mode = cm.doc.mode;
  var stream = new StringStream(text, cm.options.tabSize);
  stream.start = stream.pos = startAt || 0;
  if (text == "") callBlankLine(mode, state);
  while (!stream.eol() && stream.pos <= cm.options.maxHighlightLength) {
    readToken(mode, stream, state);
    stream.start = stream.pos;
  }
}

interpretTokenStyle(style, options) {
  if (!style || new Refexp("/^\s*\$/").test(style)) return null;
  var cache = options.addModeClass ? styleToClassCacheWithMode :
      styleToClassCache;
  return cache[style] || (cache[style] = style.replace(new Refexp("/\S+/g"),
      "cm-\$&"));
}

buildLineContent(cm, lineView) {



  var content = elt("span", null, null, webkit ? "padding-right: .1px" : null);
  var builder = {
    'pre': elt("pre", [content]),
    'content': content,
    'col': 0,
    'pos': 0,
    'cm': cm
  };
  lineView.measure = {};


  for (var i = 0; i <= (lineView.rest ? lineView.rest.length : 0); i++) {
    var line = i ? lineView.rest[i - 1] : lineView.line,
        order;
    builder.pos = 0;
    builder.addToken = buildToken;


    if ((ie || webkit) && cm.getOption("lineWrapping")) builder.addToken =
        buildTokenSplitSpaces(builder.addToken);
    if (hasBadBidiRects(cm.display.measure) && (order = getOrder(line)))
        builder.addToken = buildTokenBadBidi(builder.addToken, order);
    builder.map = [];
    insertLineContent(line, builder, getLineStyles(cm, line));
    if (line.styleClasses) {
      if (line.styleClasses.bgClass) builder.bgClass = joinClasses(
          line.styleClasses.bgClass, builder.bgClass || "");
      if (line.styleClasses.textClass) builder.textClass = joinClasses(
          line.styleClasses.textClass, builder.textClass || "");
    }


    if (builder.map.length == 0) builder.map.push(0, 0,
        builder.content.appendChild(zeroWidthElement(cm.display.measure)));


    if (i == 0) {
      lineView.measure.map = builder.map;
      lineView.measure.cache = {};
    } else {
      (lineView.measure.maps || (lineView.measure.maps = [])).push(builder.map);
      (lineView.measure.caches || (lineView.measure.caches = [])).push({});
    }
  }

  signal(cm, "renderLine", cm, lineView.line, builder.pre);
  return builder;
}

defaultSpecialCharPlaceholder(ch) {
  var token = elt("span", "\u2022", "cm-invalidchar");
  token.title = "\\u" + ch.charCodeAt(0).toString(16);
  return token;
}

buildToken(builder, text, style, startStyle, endStyle, title) {
  if (!text) return null;
  var special = builder.cm.options.specialChars,
      mustWrap = false;
  if (!special.test(text)) {
    builder.col += text.length;
    var content = document.createTextNode(text);
    builder.map.push(builder.pos, builder.pos + text.length, content);
    if (ie_upto8) mustWrap = true;
    builder.pos += text.length;
  } else {
    var content = document.createDocumentFragment(),
        pos = 0;
    while (true) {
      special.lastIndex = pos;
      var m = special.exec(text);
      var skipped = m ? m.index - pos : text.length - pos;
      if (skipped) {
        var txt = document.createTextNode(text.slice(pos, pos + skipped));
        if (ie_upto8) {
          content.appendChild(elt("span", [txt]));
        } else {
          content.appendChild(txt);
        }
        builder.map.push(builder.pos, builder.pos + skipped, txt);
        builder.col += skipped;
        builder.pos += skipped;
      }
      if (!m) break;
      pos += skipped + 1;
      if (m[0] == "\t") {
        var tabSize = builder.cm.options.tabSize,
            tabWidth = tabSize - builder.col % tabSize;
        var txt = content.appendChild(elt("span", spaceStr(tabWidth), "cm-tab")
            );
        builder.col += tabWidth;
      } else {
        var txt = builder.cm.options.specialCharPlaceholder(m[0]);
        if (ie_upto8) {
          content.appendChild(elt("span", [txt]));
        } else {
          content.appendChild(txt);
        }
        builder.col += 1;
      }
      builder.map.push(builder.pos, builder.pos + 1, txt);
      builder.pos++;
    }
  }
  if (style || startStyle || endStyle || mustWrap) {
    var fullStyle = style || "";
    if (startStyle) fullStyle += startStyle;
    if (endStyle) fullStyle += endStyle;
    var token = elt("span", [content], fullStyle);
    if (title) token.title = title;
    return builder.content.appendChild(token);
  }
  builder.content.appendChild(content);
}

buildTokenSplitSpaces(inner) {
  split(old) {
    var out = " ";
    for (var i = 0; i < old.length - 2; ++i) out += i % 2 ? " " : "\u00a0";
    out += " ";
    return out;
  }
  return (builder, text, style, startStyle, endStyle, title) {
    inner(builder, text.replace(new Refexp("/ {3,}/g"), split), style,
        startStyle, endStyle, title);
  };
}

buildTokenBadBidi(inner, order) {
  return (builder, text, style, startStyle, endStyle, title) {
    style = style ? style + " cm-force-border" : "cm-force-border";
    var start = builder.pos,
        end = start + text.length;
    for ( ; ; ) {

      for (var i = 0; i < order.length; i++) {
        var part = order[i];
        if (part.to > start && part.from <= start) break;
      }
      if (part.to >= end) return inner(builder, text, style, startStyle,
          endStyle, title);
      inner(builder, text.slice(0, part.to - start), style, startStyle, null,
          title);
      startStyle = null;
      text = text.slice(part.to - start);
      start = part.to;
    }
  };
}

buildCollapsedSpan(builder, size, marker, ignoreWidget) {
  var widget = !ignoreWidget && marker.widgetNode;
  if (widget) {
    builder.map.push(builder.pos, builder.pos + size, widget);
    builder.content.appendChild(widget);
  }
  builder.pos += size;
}

insertLineContent(line, builder, styles) {
  var spans = line.markedSpans,
      allText = line.text,
      at = 0;
  if (!spans) {
    for (var i = 1; i < styles.length; i += 2) builder.addToken(builder,
        allText.slice(at, at = styles[i]), interpretTokenStyle(styles[i + 1],
        builder.cm.options));
    return;
  }

  var len = allText.length,
      pos = 0,
      i = 1,
      text = "",
      style;
  var nextChange = 0,
      spanStyle,
      spanEndStyle,
      spanStartStyle,
      title,
      collapsed;
  for ( ; ; ) {
    if (nextChange == pos) {
      spanStyle = spanEndStyle = spanStartStyle = title = "";
      collapsed = null;
      nextChange = Infinity;
      var foundBookmarks = [];
      for (var j = 0; j < spans.length; ++j) {
        var sp = spans[j],
            m = sp.marker;
        if (sp.from <= pos && (sp.to == null || sp.to > pos)) {
          if (sp.to != null && nextChange > sp.to) {
            nextChange = sp.to;
            spanEndStyle = "";
          }
          if (m.className) spanStyle += " " + m.className;
          if (m.startStyle && sp.from == pos) spanStartStyle += " " +
              m.startStyle;
          if (m.endStyle && sp.to == nextChange) spanEndStyle += " " +
              m.endStyle;
          if (m.title && !title) title = m.title;
          if (m.collapsed && (!collapsed || compareCollapsedMarkers(
              collapsed.marker, m) < 0)) collapsed = sp;
        } else if (sp.from > pos && nextChange > sp.from) {
          nextChange = sp.from;
        }
        if (m.type == "bookmark" && sp.from == pos && m.widgetNode)
            foundBookmarks.push(m);
      }
      if (collapsed && (collapsed.from || 0) == pos) {
        buildCollapsedSpan(builder, (collapsed.to == null ? len + 1 :
            collapsed.to) - pos, collapsed.marker, collapsed.from == null);
        if (collapsed.to == null) return;
      }
      if (!collapsed && foundBookmarks.length) for (var j = 0; j <
          foundBookmarks.length; ++j) buildCollapsedSpan(builder, 0, foundBookmarks[j]);
    }
    if (pos >= len) break;

    var upto = math.min(len, nextChange);
    while (true) {
      if (text) {
        var end = pos + text.length;
        if (!collapsed) {
          var tokenText = end > upto ? text.slice(0, upto - pos) : text;
          builder.addToken(builder, tokenText, style ? style + spanStyle :
              spanStyle, spanStartStyle, pos + tokenText.length == nextChange ? spanEndStyle :
              "", title);
        }
        if (end >= upto) {
          text = text.slice(upto - pos);
          pos = upto;
          break;
        }
        pos = end;
        spanStartStyle = "";
      }
      text = allText.slice(at, at = styles[i++]);
      style = interpretTokenStyle(styles[i++], builder.cm.options);
    }
  }
}

isWholeLineUpdate(doc, change) {
  return change.from.ch == 0 && change.to.ch == 0 && lst(change.text) == "" &&
      (!doc.cm || doc.cm.options.wholeLineUpdateBefore);
}

updateDoc(doc, change, [markedSpans, estimateHeight]) {
  spansFor(n) {
    return markedSpans ? markedSpans[n] : null;
  }
  update(line, text, spans) {
    updateLine(line, text, spans, estimateHeight);
    signalLater(line, "change", line, change);
  }

  var from = change.from,
      to = change.to,
      text = change.text;
  var firstLine = getLine(doc, from.line),
      lastLine = getLine(doc, to.line);
  var lastText = lst(text),
      lastSpans = spansFor(text.length - 1),
      nlines = to.line - from.line;


  if (isWholeLineUpdate(doc, change)) {


    for (var i = 0,
        added = []; i < text.length - 1; ++i) added.push(new Line(text[i],
            spansFor(i), estimateHeight));
    update(lastLine, lastLine.text, lastSpans);
    if (nlines) doc.remove(from.line, nlines);
    if (added.length) doc.insert(from.line, added);
  } else if (firstLine == lastLine) {
    if (text.length == 1) {
      update(firstLine, firstLine.text.slice(0, from.ch) + lastText +
          firstLine.text.slice(to.ch), lastSpans);
    } else {
      for (var added = [],
          i = 1; i < text.length - 1; ++i) added.push(new Line(text[i],
              spansFor(i), estimateHeight));
      added.push(new Line(lastText + firstLine.text.slice(to.ch), lastSpans,
          estimateHeight));
      update(firstLine, firstLine.text.slice(0, from.ch) + text[0], spansFor(0)
          );
      doc.insert(from.line + 1, added);
    }
  } else if (text.length == 1) {
    update(firstLine, firstLine.text.slice(0, from.ch) + text[0] +
        lastLine.text.slice(to.ch), spansFor(0));
    doc.remove(from.line + 1, nlines);
  } else {
    update(firstLine, firstLine.text.slice(0, from.ch) + text[0], spansFor(0));
    update(lastLine, lastText + lastLine.text.slice(to.ch), lastSpans);
    for (var i = 1,
        added = []; i < text.length - 1; ++i) added.push(new Line(text[i],
            spansFor(i), estimateHeight));
    if (nlines > 1) doc.remove(from.line + 1, nlines - 1);
    doc.insert(from.line + 1, added);
  }

  signalLater(doc, "change", doc, change);
}




linkedDocs(doc, f, [sharedHistOnly]) {
  propagate(doc, skip, sharedHist) {
    if (doc.linked) for (var i = 0; i < doc.linked.length; ++i) {
      var rel = doc.linked[i];
      if (rel.doc == skip) continue;
      var shared = sharedHist && rel.sharedHist;
      if (sharedHistOnly && !shared) continue;
      f(rel.doc, shared);
      propagate(rel.doc, doc, shared);
    }
  }
  propagate(doc, null, true);
}

attachDoc(cm, doc) {
  if (doc.cm) throw new Exception("This document is already in use.");
  cm.doc = doc;
  doc.cm = cm;
  estimateLineHeights(cm);
  loadMode(cm);
  if (!cm.options.lineWrapping) findMaxLine(cm);
  cm.options.mode = doc.modeOption;
  regChange(cm);
}

getLine(doc, n) {
  n -= doc.first;
  if (n < 0 || n >= doc.size) throw new Exception("There is no line " + (n +
      doc.first) + " in the document.");
  for (var chunk = doc; !chunk.lines; ) {
    for (var i = 0; ; ++i) {
      var child = chunk.children[i],
          sz = child.chunkSize();
      if (n < sz) {
        chunk = child;
        break;
      }
      n -= sz;
    }
  }
  return chunk.lines[n];
}

getBetween(doc, start, end) {
  var out = [],
      n = start.line;
  doc.iter(start.line, end.line + 1, (line) {
    var text = line.text;
    if (n == end.line) text = text.slice(0, end.ch);
    if (n == start.line) text = text.slice(start.ch);
    out.push(text);
    ++n;
  });
  return out;
}

getLines(doc, from, to) {
  var out = [];
  doc.iter(from, to, (line) {
    out.push(line.text);
  });
  return out;
}

updateLineHeight(line, height) {
  var diff = height - line.height;
  if (diff) for (var n = line; n; n = n.parent) n.height += diff;
}

_lineNo(line) {
  if (line.parent == null) return null;
  var cur = line.parent,
      no = indexOf(cur.lines, line);
  for (var chunk = cur.parent; chunk; cur = chunk, chunk = chunk.parent) {
    for (var i = 0; ; ++i) {
      if (chunk.children[i] == cur) break;
      no += chunk.children[i].chunkSize();
    }
  }
  return no + cur.first;
}

lineAtHeight(chunk, h) {
  var n = chunk.first;
  outer: do {
    for (var i = 0; i < chunk.children.length; ++i) {
      var child = chunk.children[i],
          ch = child.height;
      if (h < ch) {
        chunk = child;
        continue outer;
      }
      h -= ch;
      n += child.chunkSize();
    }
    return n;
  } while (!chunk.lines);
  for (var i = 0; i < chunk.lines.length; ++i) {
    var line = chunk.lines[i],
        lh = line.height;
    if (h < lh) break;
    h -= lh;
  }
  return n + i;
}

heightAtLine(lineObj) {
  lineObj = visualLine(lineObj);

  var h = 0,
      chunk = lineObj.parent;
  for (var i = 0; i < chunk.lines.length; ++i) {
    var line = chunk.lines[i];
    if (line == lineObj) {
      break;
    } else {
      h += line.height;
    }
  }
  for (var p = chunk.parent; p; chunk = p, p = chunk.parent) {
    for (var i = 0; i < p.children.length; ++i) {
      var cur = p.children[i];
      if (cur == chunk) {
        break;
      } else {
        h += cur.height;
      }
    }
  }
  return h;
}

getOrder(line) {
  var order = line.order;
  if (order == null) order = line.order = bidiOrdering(line.text);
  return order;
}


e_defaultPrevented(e) {
  return e.defaultPrevented != null ? e.defaultPrevented : e.returnValue ==
      false;
}

e_target(e) {
  return e.target || e.srcElement;
}

e_button(e) {
  var b = e.which;
  if (b == null) {
    if (e.button & 1) {
      b = 1;
    } else if (e.button & 2) {
      b = 3;
    } else if (e.button & 4) b = 2;
  }
  if (mac && e.ctrlKey && b == 1) b = 3;
  return b;
}

signalLater(emitter, type, [a, b, c]) {
  var arguments = [emitter, type, a, b, c];
  var arr = emitter._handlers && emitter._handlers[type];
  if (!arr) return;
  var args = []; //XXX Array.prototype.slice.call(arguments, 2);
  //Note: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Functions_and_function_scope/arguments
  if (!delayedCallbacks) {
    ++delayedCallbackDepth;
    delayedCallbacks = [];
    setTimeout(fireDelayed, 0);
  }
  bnd(f) {
    return () {
      f.apply(null, args);
    };
  }

  for (var i = 0; i < arr.length; ++i) delayedCallbacks.push(bnd(arr[i]));
}

fireDelayed() {
  --delayedCallbackDepth;
  var delayed = delayedCallbacks;
  delayedCallbacks = null;
  for (var i = 0; i < delayed.length; ++i) delayed[i]();
}

signalDOMEvent(cm, e, [override]) {
  signal(cm, override || e.type, cm, e);
  return e_defaultPrevented(e) || e.codemirrorIgnore;
}

hasHandler(emitter, type) {
  var arr = emitter._handlers && emitter._handlers[type];
  return arr && arr.length > 0;
}



elt(tag, [content, className, style]) {
  var e = document.createElement(tag);
  if (className != null) e.className = className;
  if (style != null) e.style.cssText = style;
  if (typeOfReplacement(content, "string")) {
    e.appendChild(document.createTextNode(content));
  } else if (content) for (var i = 0; i < content.length; ++i) e.appendChild(
      content[i]);
  return e;
}

removeChildren(e) {
  for (var count = e.childNodes.length; count > 0; --count) e.removeChild(
      e.firstChild);
  return e;
}

removeChildrenAndAdd(parent, e) {
  return removeChildren(parent).appendChild(e);
}

contains(parent, child) {
  if (parent.contains) return parent.contains(child);
  while (child = child.parentNode) if (child == parent) return true;
}

activeElt() {
  return document.activeElement;
}

classTest(cls) {
  return new RegExp("\\b" + cls + "\\b\\s*");
}

rmClass(node, cls) {
  var test = classTest(cls);
  if (test.test(node.className)) node.className = node.className.replace(test,
      "");
}

addClass(node, cls) {
  if (!classTest(cls).test(node.className)) node.className += " " + cls;
}

joinClasses(a, b) {
  var as = a.split(" ");
  for (var i = 0; i < as.length; i++) if (as[i] && !classTest(as[i]).test(b)) b
      += " " + as[i];
  return b;
}

scrollbarWidth(measure) {
  if (knownScrollbarWidth != null) return knownScrollbarWidth;
  var test = elt("div", null, null,
      "width: 50px; height: 50px; overflow-x: scroll");
  removeChildrenAndAdd(measure, test);
  if (test.offsetWidth) knownScrollbarWidth = test.offsetHeight -
      test.clientHeight;
  return knownScrollbarWidth || 0;
}

zeroWidthElement(measure) {
  if (zwspSupported == null) {
    var test = elt("span", "\u200b");
    removeChildrenAndAdd(measure, elt("span", [test, document.createTextNode("x"
        )]));
    if (measure.firstChild.offsetHeight != 0) zwspSupported = test.offsetWidth
        <= 1 && test.offsetHeight > 2 && !ie_upto7;
  }
  if (zwspSupported) {
    return elt("span", "\u200b");
  } else {
    return elt("span", "\u00a0", null,
        "display: inline-block; width: 1px; margin-right: -1px");
  }
}

hasBadBidiRects(measure) {
  if (badBidiRects != null) return badBidiRects;
  var txt = removeChildrenAndAdd(measure, document.createTextNode("A\u062eA"));
  var r0 = range(txt, 0, 1).getBoundingClientRect();
  if (r0.left == r0.right) return false;
  var r1 = range(txt, 1, 2).getBoundingClientRect();
  return badBidiRects = (r1.right - r0.right < 3);
}

iterateBidiSections(order, from, to, f) {
  if (!order) return f(from, to, "ltr");
  var found = false;
  for (var i = 0; i < order.length; ++i) {
    var part = order[i];
    if (part.from < to && part.to > from || from == to && part.to == from) {
      f(math.max(part.from, from), math.min(part.to, to), part.level == 1 ?
          "rtl" : "ltr");
      found = true;
    }
  }
  if (!found) f(from, to, "ltr");
}

bidiLeft(part) {
  return part.level % 2 ? part.to : part.from;
}

bidiRight(part) {
  return part.level % 2 ? part.from : part.to;
}

lineLeft(line) {
  var order = getOrder(line);
  return order ? bidiLeft(order[0]) : 0;
}

lineRight(line) {
  var order = getOrder(line);
  if (!order) return line.text.length;
  return bidiRight(lst(order));
}

lineStart(cm, lineN) {
  var line = getLine(cm.doc, lineN);
  var visual = visualLine(line);
  if (visual != line) lineN = _lineNo(visual);
  var order = getOrder(visual);
  var ch = !order ? 0 : order[0].level % 2 ? lineRight(visual) : lineLeft(visual
      );
  return newPos(lineN, ch);
}

lineEnd(cm, lineN) {
  var merged,
      line = getLine(cm.doc, lineN);
  while (merged = collapsedSpanAtEnd(line)) {
    line = merged.find(1, true).line;
    lineN = null;
  }
  var order = getOrder(line);
  var ch = !order ? line.text.length : order[0].level % 2 ? lineLeft(line) :
      lineRight(line);
  return newPos(lineN == null ? _lineNo(line) : lineN, ch);
}

compareBidiLevel(order, a, b) {
  var linedir = order[0].level;
  if (a == linedir) return true;
  if (b == linedir) return false;
  return a < b;
}

getBidiPartAt(order, pos) {
  bidiOther = null;
  for (var i = 0,
      found; i < order.length; ++i) {
    var cur = order[i];
    if (cur.from < pos && cur.to > pos) return i;
    if ((cur.from == pos || cur.to == pos)) {
      if (found == null) {
        found = i;
      } else if (compareBidiLevel(order, cur.level, order[found].level)) {
        if (cur.from != cur.to) bidiOther = found;
        return i;
      } else {
        if (cur.from != cur.to) bidiOther = i;
        return found;
      }
    }
  }
  return found;
}

moveInLine(line, pos, dir, byUnit) {
  if (!byUnit) return pos + dir;
  do pos += dir; while (pos > 0 && isExtendingChar(line.text.charAt(pos)));
  return pos;
}

moveVisually(line, start, dir, [byUnit]) {
  var bidi = getOrder(line);
  if (!bidi) return moveLogically(line, start, dir, byUnit);
  var pos = getBidiPartAt(bidi, start),
      part = bidi[pos];
  var target = moveInLine(line, start, part.level % 2 ? -dir : dir, byUnit);

  for ( ; ; ) {
    if (target > part.from && target < part.to) return target;
    if (target == part.from || target == part.to) {
      if (getBidiPartAt(bidi, target) == pos) return target;
      part = bidi[pos += dir];
      return (dir > 0) == part.level % 2 ? part.to : part.from;
    } else {
      part = bidi[pos += dir];
      if (!part) return null;
      if ((dir > 0) == part.level % 2) {
        target = moveInLine(line, part.to, -1, byUnit);
      } else {
        target = moveInLine(line, part.from, 1, byUnit);
      }
    }
  }
}

moveLogically(line, start, dir, byUnit) {
  var target = start + dir;
  if (byUnit) while (target > 0 && isExtendingChar(line.text.charAt(target)))
      target += dir;
  return target < 0 || target > line.text.length ? null : target;
}
