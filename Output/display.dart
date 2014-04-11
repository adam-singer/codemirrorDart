part of codemirror.dart;

class Display {
  var input;
  var inputDiv;
  var scrollbarH;
  var scrollbarV;
  var scrollbarFiller;
  var gutterFiller;
  var lineDiv;
  var selectionDiv;
  var cursorDiv;
  var measure;
  var lineMeasure;
  var lineSpace;

  var mover;
  var sizer;
  var heightForcer;
  var gutters;
  var lineGutter;
  var scroller;
  var wrapper;
  var viewFrom;
  var viewTo;
  var view;
  var externalMeasured;
  var viewOffset;
  var lastSizeC;
  var updateLineNumbers;
  var lineNumWidth;
  var lineNumInnerWidth;
  var lineNumChars;
  var prevInput;
  var alignWidgets;
  var pollingFast;
  var poll;
  var cachedCharWidth;
  var cachedTextHeight;
  var cachedPaddingH;
  var inaccurateSelection;
  var maxLine;
  var maxLineLength;
  var maxLineChanged;
  var wheelDX;
  var wheelDY;
  var wheelStartX;
  var wheelStartY;
  var shift;


  Display(place, doc) {
    var input = this.input = elt("textarea", null, null,
        "position: absolute; padding: 0; width: 1px; height: 1em; outline: none");




    if (webkit) {
      input.style.width = "1000px";
    } else {
      input.setAttribute("wrap", "off");
    }
    if (ios) input.style.border = "1px solid black";
    input.setAttribute("autocorrect", "off");
    input.setAttribute("autocapitalize", "off");
    input.setAttribute("spellcheck", "false");


    this.inputDiv = elt("div", [input], null,
        "overflow: hidden; position: relative; width: 3px; height: 0px;");

    this.scrollbarH = elt("div", [elt("div", null, null,
        "height: 100%; min-height: 1px")], "CodeMirror-hscrollbar");
    this.scrollbarV = elt("div", [elt("div", null, null, "min-width: 1px")],
        "CodeMirror-vscrollbar");

    this.scrollbarFiller = elt("div", null, "CodeMirror-scrollbar-filler");


    this.gutterFiller = elt("div", null, "CodeMirror-gutter-filler");

    this.lineDiv = elt("div", null, "CodeMirror-code");

    this.selectionDiv = elt("div", null, null, "position: relative; z-index: 1"
        );
    this.cursorDiv = elt("div", null, "CodeMirror-cursors");

    this.measure = elt("div", null, "CodeMirror-measure");

    this.lineMeasure = elt("div", null, "CodeMirror-measure");

    this.lineSpace = elt("div", [this.measure, this.lineMeasure,
        this.selectionDiv, this.cursorDiv, this.lineDiv], null,
        "position: relative; outline: none");

    this.mover = elt("div", [elt("div", [this.lineSpace], "CodeMirror-lines")],
        null, "position: relative");

    this.sizer = elt("div", [this.mover], "CodeMirror-sizer");



    this.heightForcer = elt("div", null, null, "position: absolute; height: " +
        scrollerCutOff.toString() + "px; width: 1px;");

    this.gutters = elt("div", null, "CodeMirror-gutters");
    this.lineGutter = null;

    this.scroller = elt("div", [this.sizer, this.heightForcer, this.gutters],
        "CodeMirror-scroll");
    this.scroller.setAttribute("tabIndex", "-1");

    this.wrapper = elt("div", [this.inputDiv, this.scrollbarH, this.scrollbarV,
        this.scrollbarFiller, this.gutterFiller, this.scroller], "CodeMirror");


    if (ie_upto7) {
      this.gutters.style.zIndex = -1;
      this.scroller.style.paddingRight = 0;
    }

    if (ios) input.style.width = "0px";
    if (!webkit) this.scroller.draggable = true;

    if (khtml) {
      this.inputDiv.style.height = "1px";
      this.inputDiv.style.position = "absolute";
    }

    if (ie_upto7) this.scrollbarH.style.minHeight =
        this.scrollbarV.style.minWidth = "18px";

    if (place.appendChild) {
      place.appendChild(this.wrapper);
    } else {
      place(this.wrapper);
    }
    this.viewFrom = this.viewTo = doc.first;

    this.view = [];


    this.externalMeasured = null;

    this.viewOffset = 0;
    this.lastSizeC = 0;
    this.updateLineNumbers = null;



    this.lineNumWidth = this.lineNumInnerWidth = this.lineNumChars = null;

    this.prevInput = "";



    this.alignWidgets = false;



    this.pollingFast = false;

    this.poll = new Delayed();

    this.cachedCharWidth = this.cachedTextHeight = this.cachedPaddingH = null;



    this.inaccurateSelection = false;



    this.maxLine = null;
    this.maxLineLength = 0;
    this.maxLineChanged = false;


    this.wheelDX = this.wheelDY = this.wheelStartX = this.wheelStartY = null;


    this.shift = false;
  }
}
