library malison.canvas_terminal;

import 'dart:html' as html;

import 'package:piecemeal/piecemeal.dart';

import 'glyph.dart';
import 'terminal.dart';

/// Draws to a canvas using a browser font.
class CanvasTerminal extends RenderableTerminal {
  /// The current display state. The glyphs here mirror what has been rendered.
  final Array2D<Glyph> glyphs;

  /// The glyphs that have been modified since the last call to [render].
  final Array2D<Glyph> changedGlyphs;

  final Font font;
  final html.CanvasElement canvas;
  html.CanvasRenderingContext2D context;

  int scale = 1;

  Vec get size => glyphs.size;
  int get width => glyphs.width;
  int get height => glyphs.height;

  CanvasTerminal(int width, int height, this.canvas, this.font)
      : glyphs = new Array2D<Glyph>(width, height),
        changedGlyphs = new Array2D<Glyph>(width, height, Glyph.CLEAR) {
    context = canvas.context2D;

    canvas.width = font.charWidth * width;
    canvas.height = font.lineHeight * height;

    // Handle high-resolution (i.e. retina) displays.
    if (html.window.devicePixelRatio > 1) {
      scale = 2;

      canvas.style.width = '${font.charWidth * width / scale}px';
      canvas.style.height = '${font.lineHeight * height / scale}px';
    }
  }

  void drawGlyph(int x, int y, Glyph glyph) {
    if (glyphs.get(x, y) != glyph) {
      changedGlyphs.set(x, y, glyph);
    } else {
      changedGlyphs.set(x, y, null);
    }
  }

  Terminal rect(int x, int y, int width, int height) {
    // TODO: Bounds check.
    return new PortTerminal(x, y, new Vec(width, height), this);
  }

  void render() {
    context.font = '${font.size * scale}px ${font.family}, monospace';

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        var glyph = changedGlyphs.get(x, y);

        // Only draw glyphs that are different since the last call.
        if (glyph == null) continue;

        // Up to date now.
        glyphs.set(x, y, glyph);
        changedGlyphs.set(x, y, null);

        var char = glyph.char;

        // Fill the background.
        context.fillStyle = glyph.back.cssColor;
        context.fillRect(x * font.charWidth, y * font.lineHeight,
            font.charWidth, font.lineHeight);

        // Don't bother drawing empty characters.
        if (char == 0 || char == CharCode.SPACE) continue;

        context.fillStyle = glyph.fore.cssColor;
        context.fillText(new String.fromCharCodes([char]),
            x * font.charWidth + font.x, y * font.lineHeight + font.y);
      }
    }
  }

  Vec pixelToChar(Vec pixel) =>
      new Vec(pixel.x ~/ font.charWidth, pixel.y ~/ font.lineHeight);
}

/// Describes a font used by [CanvasTerminal].
class Font {
  final String family;
  final int size;
  final int charWidth;
  final int lineHeight;
  final int x;
  final int y;

  Font(this.family, {this.size, int w, int h, this.x, this.y})
      : charWidth = w,
        lineHeight = h;
}