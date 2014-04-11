part of codemirror.dart;

bidiOrdering(str) {
  if (!bidiRE.test(str)) return false;
  var len = str.length,
      types = [];
  for (var i = 0,
      type; i < len; ++i) types.push(type = charType(str.charCodeAt(i)));

  for (var i = 0,
      prev = outerType; i < len; ++i) {
    var type = types[i];
    if (type == "m") {
      types[i] = prev;
    } else {
      prev = type;
    }
  }

  for (var i = 0,
      cur = outerType; i < len; ++i) {
    var type = types[i];
    if (type == "1" && cur == "r") {
      types[i] = "n";
    } else if (isStrong.test(type)) {
      cur = type;
      if (type == "r") types[i] = "R";
    }
  }

  for (var i = 1,
      prev = types[0]; i < len - 1; ++i) {
    var type = types[i];
    if (type == "+" && prev == "1" && types[i + 1] == "1") {
      types[i] = "1";
    } else if (type == "," && prev == types[i + 1] && (prev == "1" || prev ==
        "n")) types[i] = prev;
    prev = type;
  }

  for (var i = 0; i < len; ++i) {
    var type = types[i];
    if (type == ",") {
      types[i] = "N";
    } else if (type == "%") {
      var end = i + 1;
      for (; end < len && types[end] == "%"; ++end) {}
      var replace = (i && types[i - 1] == "!") || (end < len && types[end] ==
          "1") ? "1" : "N";
      for (var j = i; j < end; ++j) types[j] = replace;
      i = end - 1;
    }
  }

  for (var i = 0,
      cur = outerType; i < len; ++i) {
    var type = types[i];
    if (cur == "L" && type == "1") {
      types[i] = "L";
    } else if (isStrong.test(type)) cur = type;
  }

  for (var i = 0; i < len; ++i) {
    if (isNeutral.test(types[i])) {
      var end = i + 1;
      for (; end < len && isNeutral.test(types[end]); ++end) {}
      var before = (i ? types[i - 1] : outerType) == "L";
      var after = (end < len ? types[end] : outerType) == "L";
      var replace = before || after ? "L" : "R";
      for (var j = i; j < end; ++j) types[j] = replace;
      i = end - 1;
    }
  }

  var order = [],
      m;
  for (var i = 0; i < len; ) {
    if (countsAsLeft.test(types[i])) {
      var start = i;
      for (++i; i < len && countsAsLeft.test(types[i]); ++i) {}
      order.push(new BidiSpan(0, start, i));
    } else {
      var pos = i,
          at = order.length;
      for (++i; i < len && types[i] != "L"; ++i) {}
      for (var j = pos; j < i; ) {
        if (countsAsNum.test(types[j])) {
          if (pos < j) order.splice(at, 0, new BidiSpan(1, pos, j));
          var nstart = j;
          for (++j; j < i && countsAsNum.test(types[j]); ++j) {}
          order.splice(at, 0, new BidiSpan(2, nstart, j));
          pos = j;
        } else {
          ++j;
        }
      }
      if (pos < i) order.splice(at, 0, new BidiSpan(1, pos, i));
    }
  }
  if (order[0].level == 1 && (m = str.match(new Refexp("/^\s+/")))) {
    order[0].from = m[0].length;
    order.unshift(new BidiSpan(0, 0, m[0].length));
  }
  if (lst(order).level == 1 && (m = str.match(new Refexp("/\s+\$/")))) {
    lst(order).to -= m[0].length;
    order.push(new BidiSpan(0, len - m[0].length, len));
  }
  if (order[0].level != lst(order).level) order.push(new BidiSpan(
      order[0].level, len, len));

  return order;
}
