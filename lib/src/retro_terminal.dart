library malison.retro_terminal;

import 'dart:html' as html;

import 'package:piecemeal/piecemeal.dart';

import 'glyph.dart';
import 'display.dart';
import 'terminal.dart';

/// A [RenderableTerminal] that draws to a canvas using the old school DOS
/// [code page 437][font] font.
///
/// [font]: http://en.wikipedia.org/wiki/Code_page_437
class RetroTerminal extends RenderableTerminal {
  final Display _display;

  final html.CanvasElement _canvas;
  html.CanvasRenderingContext2D _context;
  html.ImageElement _font;

  int get width => _display.width;
  int get height => _display.height;
  Vec get size => _display.size;

  /// A cache of the tinted font images. Each key is a color, and the image
  /// will is the font in that color.
  final Map<Color, html.CanvasElement> _fontColorCache = {};

  /// The drawing scale, used to adapt to Retina displays.
  int _scale = 1;

  bool _imageLoaded = false;

  final int _charWidth;
  final int _charHeight;

  static final _UNICODE_MAP = const {
    CharCode.BULLET: 7,
    CharCode.BULLET_OPERATOR: 249,
    CharCode.MIDDLE_DOT: 250,
    CharCode.UP_DOWN_ARROW: 18,
    CharCode.LEFT_RIGHT_ARROW: 29,
    CharCode.BLACK_UP_POINTING_TRIANGLE: 30,
    CharCode.BLACK_SPADE_SUIT: 6,
    CharCode.BLACK_CLUB_SUIT: 5,
    CharCode.SOLID: 219,
    CharCode.HALF_LEFT: 221,
    CharCode.BOX_DRAWINGS_LIGHT_VERTICAL: 179,
    CharCode.TRIPLE_BAR: 240,
    CharCode.PI: 227,
    CharCode.BLACK_HEART_SUIT: 3
  };

  /// Creates a new terminal using a built-in DOS-like font.
  RetroTerminal.dos(int width, int height, html.CanvasElement canvas)
      : this(width, height, canvas, "packages/malison/dos.png",
            charWidth: 9, charHeight: 16);

  /// Creates a new terminal using a short built-in DOS-like font.
  RetroTerminal.shortDos(int width, int height, html.CanvasElement canvas)
      : this(width, height, canvas, "packages/malison/dos-short.png",
            charWidth: 9, charHeight: 13);

  /// Creates a new terminal using a font image at [imageUrl].
  RetroTerminal(int width, int height, this._canvas, String imageUrl,
      {int charWidth, int charHeight})
      : _display = new Display(width, height),
        _charWidth = charWidth,
        _charHeight = charHeight {
    _context = _canvas.context2D;

    // Handle high-resolution (i.e. retina) displays.
    if (html.window.devicePixelRatio > 1) {
      _scale = 2;
    }

    var canvasWidth = _charWidth * width;
    var canvasHeight = _charHeight * height;
    _canvas.width = canvasWidth * _scale;
    _canvas.height = canvasHeight * _scale;
    _canvas.style.width = '${canvasWidth}px';
    _canvas.style.height = '${canvasHeight}px';

    _font = new html.ImageElement(src: imageUrl);
    _font.onLoad.listen((_) {
      _imageLoaded = true;
      render();
    });
  }

  void drawGlyph(int x, int y, Glyph glyph) {
    _display.setGlyph(x, y, glyph);
  }

  void render() {
    if (!_imageLoaded) return;

    _display.render((x, y, glyph) {
      var char = glyph.char;

      // See if it's a Unicode character that needs to be remapped.
      var fromUnicode = _UNICODE_MAP[char];
      if (fromUnicode != null) char = fromUnicode;

      var sx = (char % 32) * _charWidth;
      var sy = (char ~/ 32) * _charHeight;

      // Fill the background.
      _context.fillStyle = glyph.back.cssColor;
      _context.fillRect(
          x * _charWidth * _scale,
          y * _charHeight * _scale,
          _charWidth * _scale,
          _charHeight * _scale);

      // Don't bother drawing empty characters.
      if (char == 0 || char == CharCode.SPACE) return;

      var color = _getColorFont(glyph.fore);
      // *2 because the font image is double-sized. That ensures it stays
      // sharp on retina displays and doesn't render scaled up.
      _context.drawImageScaledFromSource(color,
          sx * 2, sy * 2, _charWidth * 2, _charHeight * 2,
          x * _charWidth * _scale,
          y * _charHeight * _scale,
          _charWidth * _scale,
          _charHeight * _scale);
    });
  }

  Vec pixelToChar(Vec pixel) =>
      new Vec(pixel.x ~/ _charWidth, pixel.y ~/ _charHeight);

  html.CanvasElement _getColorFont(Color color) {
    var cached = _fontColorCache[color];
    if (cached != null) return cached;

    // Create a font using the given color.
    var tint = new html.CanvasElement(width: _font.width, height: _font.height);
    var context = tint.context2D;

    // Draw the font.
    context.drawImage(_font, 0, 0);

    // Tint it by filling in the existing alpha with the color.
    context.globalCompositeOperation = 'source-atop';
    context.fillStyle = color.cssColor;
    context.fillRect(0, 0, _font.width, _font.height);

    _fontColorCache[color] = tint;
    return tint;
  }
}
