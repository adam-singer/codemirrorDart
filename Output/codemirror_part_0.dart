part of codemirror.dart;

var gecko;
var ie_upto10;
var ie_upto7;
var ie_upto8;
var ie_upto9;
var ie_11up;
var ie;
var webkit;
var qtwebkit;
var chrome;
var presto;
var safari;
var khtml;
var mac_geLion;
var mac_geMountainLion;
var phantom;

var ios;
var mobile;
var mac;
var windows;

var presto_version;
var flipCtrlCmd;
var captureRightClick;
var sawReadOnlySpans;

var modes = {};
var mimeModes = {};
var modeExtensions = {};

var keyNames = {};


cmp(a, b) {
  return a.line - b.line || a.ch - b.ch;
}

changeEnd(change) {
  if (!change.text) return change.to;
  return newPos(change.from.line + change.text.length - 1, lst(change.text
      ).length + (change.text.length == 1 ? change.from.ch : 0));
}


defineMode(name, mode) {
  if (!CodeMirror.defaults.mode && name != "null") CodeMirror.defaults.mode =
      name;
  /*
    if (arguments.length > 2) {
      mode.dependencies = [];
      for (var i = 2; i < arguments.length; ++i) mode.dependencies.push(arguments[i]);
    }
    */
  modes[name] = mode;
}

defineMIME(mime, spec) {
  mimeModes[mime] = spec;
}

resolveMode(spec) {
  if (typeOfReplacement(spec, "string") && mimeModes.hasOwnProperty(spec)) {
    spec = mimeModes[spec];
  } else if (spec && typeOfReplacement(spec.name, "string") &&
      mimeModes.hasOwnProperty(spec.name)) {
    var found = mimeModes[spec.name];
    if (typeOfReplacement(found, "string")) found = {
      'name': found
    };
    spec = createObj(found, spec);
    spec.name = found.name;
  }
  /* XXX else if (typeOfReplacement(spec, "string") && { new Refexp("/^[\w\-]+\/[\w\-]+\+xml/$/").test(spec)) {
      return CodeMirror.resolveMode("application/xml");
    } */
  if (typeOfReplacement(spec, "string")) {
    return {
      'name': spec
    };
  } else {
    return spec || {
      'name': "null"
    };
  }
}

getMode(options, spec) {
  spec = CodeMirror.resolveMode(spec);
  var mfactory = modes[spec.name];
  if (!mfactory) return CodeMirror.getMode(options, "text/plain");
  var modeObj = mfactory(options, spec);
  if (modeExtensions.hasOwnProperty(spec.name)) {
    var exts = modeExtensions[spec.name];
    for (var prop in exts) {
      if (!exts.hasOwnProperty(prop)) continue;
      if (modeObj.hasOwnProperty(prop)) modeObj["_" + prop] = modeObj[prop];
      modeObj[prop] = exts[prop];
    }
  }
  modeObj.name = spec.name;
  if (spec.helperType) modeObj.helperType = spec.helperType;
  if (spec.modeProps) for (var prop in spec.modeProps) modeObj[prop] =
      spec.modeProps[prop];

  return modeObj;
}

extendMode(mode, properties) {
  var exts = modeExtensions.hasOwnProperty(mode) ? modeExtensions[mode] :
      (modeExtensions[mode] = {});
  copyObj(properties, exts);
}

defineExtension(name, func) {
  //CodeMirror.prototype[name] = func;
}

defineDocExtension(name, func) {
  //Doc.prototype[name] = func;
}

defineOption(name, deflt, handle, notOnInit) {
  CodeMirror.defaults[name] = deflt;
  if (handle) optionHandlers[name] = notOnInit ? (cm, val, old) {
    if (old != Init) handle(cm, val, old);
  } : handle;
}

defineInitHook(f) {
  initHooks.push(f);
}

registerHelper(type, name, value) {
  if (!helpers.hasOwnProperty(type)) helpers[type] = CodeMirror[type] = {
    _global: []
  };
  helpers[type][name] = value;
}

registerGlobalHelper(type, name, predicate, value) {
  registerHelper(type, name, value);
  helpers[type]._global.push({
    'pred': predicate,
    'val': value
  });
}

copyState(mode, state) {
  if (state == true) return state;
  if (mode.copyState) return mode.copyState(state);
  var nstate = {};
  for (var n in state) {
    var val = state[n];
    if (val is List) val = new List.from(val);
    nstate[n] = val;
  }
  return nstate;
}

startState(mode, [a1, a2]) {
  return mode.startState ? mode.startState(a1, a2) : true;
}

innerMode(mode, state) {
  var info;
  while (mode.innerMode) {
    info = mode.innerMode(state);
    if (!info || info.mode == mode) break;
    state = info.state;
    mode = info.mode;
  }
  return (info == null) ? {
    mode: mode,
    state: state
  } : info;
}

lookupKey(name, maps, handle) {
  lookup(map) {
    map = getKeyMap(map);
    var found = map[name];
    if (found == false) return "stop";
    if (found != null && handle(found)) return true;
    if (map.nofallthrough) return "stop";

    var fallthrough = map.fallthrough;
    if (fallthrough == null) return false;
    if (Object.prototype.toString.call(fallthrough) != "[object Array]") return
        lookup(fallthrough);
    for (var i = 0; i < fallthrough.length; ++i) {
      var done = lookup(fallthrough[i]);
      if (done) return done;
    }
    return false;
  }

  for (var i = 0; i < maps.length; ++i) {
    var done = lookup(maps[i]);
    if (done) return done != "stop";
  }
}

isModifierKey(event) {
  var name = keyNames[event.keyCode];
  return name == "Ctrl" || name == "Alt" || name == "Shift" || name == "Mod";
}

keyName(event, noShift) {
  if (presto && event.keyCode == 34 && event["char"]) return false;
  var name = keyNames[event.keyCode];
  if (name == null || event.altGraphKey) return false;
  if (event.altKey) name = "Alt-" + name;
  if (flipCtrlCmd ? event.metaKey : event.ctrlKey) name = "Ctrl-" + name;
  if (flipCtrlCmd ? event.ctrlKey : event.metaKey) name = "Cmd-" + name;
  if (!noShift && event.shiftKey) name = "Shift-" + name;
  return name;
}

fromTextArea(textarea, options) {
  if (!options) options = {};
  options.value = textarea.value;
  if (!options.tabindex && textarea.tabindex) options.tabindex =
      textarea.tabindex;
  if (!options.placeholder && textarea.placeholder) options.placeholder =
      textarea.placeholder;
  var cm;

  if (options.autofocus == null) {
    var hasFocus = activeElt();
    options.autofocus = hasFocus == textarea || textarea.getAttribute(
        "autofocus") != null && hasFocus == document.body;
  }

  save() {
    textarea.value = cm.getValue();
  }
  if (textarea.form) {
    _on(textarea.form, "submit", save);

    if (!options.leaveSubmitMethodAlone) {
      var form = textarea.form,
          realSubmit = form.submit;
      try {
        var wrappedSubmit;
        wrappedSubmit = form.submit = () {
          save();
          form.submit = realSubmit;
          form.submit();
          form.submit = wrappedSubmit;
        };
      } catch (e) {}
    }
  }

  textarea.style.display = "none";
  cm = new CodeMirror((node) {
    textarea.parentNode.insertBefore(node, textarea.nextSibling);
  }, options);
  cm.save = save;
  cm.getTextArea = () {
    return textarea;
  };
  cm.toTextArea = () {
    save();
    textarea.parentNode.removeChild(cm.etWrapperElement());
    textarea.style.display = "";
    if (textarea.form) {
      _off(textarea.form, "submit", save);
      if (typeOfReplacement(textarea.form.submit, "function"))
          textarea.form.submit = realSubmit;
    }
  };
  return cm;
}


e_preventDefault(e) {
  if (e.preventDefault) {
    e.preventDefault();
  } else {
    e.returnValue = false;
  }
}

e_stopPropagation(e) {
  if (e.stopPropagation) {
    e.stopPropagation();
  } else {
    e.cancelBubble = true;
  }
}

e_stop(e) {
  e_preventDefault(e);
  e_stopPropagation(e);
}

_on(emitter, type, f) {
  if (emitter.addEventListener) {
    emitter.addEventListener(type, f, false);
  } else if (emitter.attachEvent) {
    emitter.attachEvent("on" + type, f);
  } else {
    var map = emitter._handlers || (emitter._handlers = {});
    var arr = map[type] || (map[type] = []);
    arr.push(f);
  }
}

_off(emitter, type, f) {
  if (emitter.removeEventListener) {
    emitter.removeEventListener(type, f, false);
  } else if (emitter.detachEvent) {
    emitter.detachEvent("on" + type, f);
  } else {
    var arr = emitter._handlers && emitter._handlers[type];
    if (!arr) return;
    for (var i = 0; i < arr.length; ++i) if (arr[i] == f) {
      arr.splice(i, 1);
      break;
    }
  }
}

signal(emitter, type) {
  var arr = emitter._handlers && emitter._handlers[type];
  if (!arr) return;
  var args = []; // XXX: Array.prototype.slice.call(arguments, 2);
  for (var i = 0; i < arr.length; ++i) arr[i].apply(null, args);
}

countColumn(string, end, tabSize, [startIndex = 0, startValue = 0]) {
  if (end == null) {
    end = string.search(new Refexp("/[^\s\u00a0]/"));
    if (end == -1) end = string.length;
  }
  for (var i = startIndex,
      n = startValue; ; ) {
    var nextTab = string.indexOf("\t", i);
    if (nextTab < 0 || nextTab >= end) return n + (end - i);
    n += nextTab - i;
    n += tabSize - (n % tabSize);
    i = nextTab + 1;
  }
}

selectInput(node) {
  node.select();
}

isWordChar(ch) {
  return new Refexp("/\w/").test(ch) || ch > "\x80" && (ch.toUpperCase() !=
      ch.toLowerCase() || nonASCIISingleCaseWordChar.test(ch));
}

range(node, start, end) {
  var r = document.body.createTextRange();
  r.moveToElementText(node.parentNode);
  r.collapse(true);
  r.moveEnd("character", end);
  r.moveStart("character", start);
  return r;
}

splitLines(string) {
  return string.split(new Refexp("/\r\n?|\n/"));
}
