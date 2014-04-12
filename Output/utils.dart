library codemirror.dart.utils;

import 'dart:math' as math;
import 'cmout.dart' show Pos;

part '../Input/patch.dart';

class Delayed {
  var id;
  Delayed();
  set(ms, f) {
    clearTimeout(this.id);
    this.id = setTimeout(f, ms);
  }
}

// Number of pixels added to scroller and sizer to hide scrollbar
int scrollerCutOff = 30;

// One-char codes used for character types:
// L (L):   Left-to-Right
// R (R):   Right-to-Left
// r (AL):  Right-to-Left Arabic
// 1 (EN):  European Number
// + (ES):  European Number Separator
// % (ET):  European Number Terminator
// n (AN):  Arabic Number
// , (CS):  Common Number Separator
// m (NSM): Non-Spacing Mark
// b (BN):  Boundary Neutral
// s (B):   Paragraph Separator
// t (S):   Segment Separator
// w (WS):  Whitespace
// N (ON):  Other Neutrals

// Character types for codepoints 0 to 0xff
String lowTypes =
    "bbbbbbbbbtstwsbbbbbbbbbbbbbbssstwNN%%%NNNNNN,N,N1111111111NNNNNNNLLLLLLLLLLLLLLLLLLLLLLLLLLNNNNNNLLLLLLLLLLLLLLLLLLLLLLLLLLNNNNbbbbbbsbbbbbbbbbbbbbbbbbbbbbbbbbb,N%%%%NNNNLNNNNN%%11NLNNN1LNNNNNLLLLLLLLLLLLLLLLLLLLLLLNLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLN";
// Character types for codepoints 0x600 to 0x6ff
String arabicTypes =
    "rrrrrrrrrrrr,rNNmmmmmmrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrmmmmmmmmmmmmmmrrrrrrrnnnnnnnnnn%nnrrrmrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrmmmmmmmmmmmmmmmmmmmNmmmm";

String charType(code) {
  if (code <= 0xf7) {
    return lowTypes[code];
  } else if (0x590 <= code && code <= 0x5f4) {
    return "R";
  } else if (0x600 <= code && code <= 0x6ed) {
    return arabicTypes[code - 0x600];
  } else if (0x6ee <= code && code <= 0x8ac) {
    return "r";
  } else if (0x2000 <= code && code <= 0x200b) {
    return "w";
  } else if (code == 0x200c) {
    return "b";
  } else {
    return "L";
  }
}

findColumn(string, goal, tabSize) {
  for (var pos = 0,
      col = 0; ; ) {
    var nextTab = string.indexOf("\t", pos);
    if (nextTab == -1) nextTab = string.length;
    var skipped = nextTab - pos;
    if (nextTab == string.length || col + skipped >= goal) return pos +
        math.min(skipped, goal - col);
    col += nextTab - pos;
    col += tabSize - (col % tabSize);
    pos = nextTab + 1;
    if (col >= goal) return pos;
  }
}

spaceStr(n) {
  while (spaceStrs.length <= n) spaceStrs.push(lst(spaceStrs) + " ");
  return spaceStrs[n];
}

lst(arr) {
  return arr[arr.length - 1];
}

indexOf(array, elt) {
  return array.indexOf(elt);
}

map(array, f) {
  return array.map(f);
}

createObj(base, props) {
  var inst;
  if (Object.create) {
    inst = Object.create(base);
  } else {
    var ctor = () {};
    ctor.prototype = base;
    inst = new ctor();
  }
  if (props) copyObj(props, inst);
  return inst;
}

copyObj(obj, [target, overwrite]) {
  if (target == null) target = {};
  for (var prop in obj) if (obj.hasOwnProperty(prop) && (overwrite != false ||
      !target.hasOwnProperty(prop))) target[prop] = obj[prop];
  return target;
}

bind(f, [a, b, c]) {
  var arguments = [f, a, b, c]; //XXX Add in extra params
  
  var args = []; // XXX: Array.prototype.slice.call(arguments, 1);
  //Note from lukechurch, the above call converts the arguments into a real array
  //https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Functions_and_function_scope/arguments
  return () {
    return f.apply(null, args);
  };
}

isEmpty(obj) {
  for (var n in obj) if (obj.hasOwnProperty(n) && obj[n]) return false;
  return true;
}

isExtendingChar(ch) {
  return ch.charCodeAt(0) >= 768 && extendingChars.test(ch);
}
