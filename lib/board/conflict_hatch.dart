import 'package:flutter/material.dart';

/// Diagonal lines across a cell, so a broken rule is readable without colour.
///
/// Shared by every board that marks a cell: Sudoku hatches a repeated digit and
/// Stars hatches a star in breach, and both draw the same lines in the same
/// [NookColors.conflictLine] so the marking is one language across the app.
class ConflictHatch extends CustomPainter {
  const ConflictHatch({required this.colour});

  final Color colour;

  /// The gap between one line and the next, in logical pixels.
  ///
  /// Fixed rather than a fraction of the cell: the hatch has to stay a hatch on
  /// a 9x9's small cells, and a pattern that scaled with them would turn into
  /// two fat stripes.
  static const double step = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..color = colour
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (double x = -size.height; x < size.width; x += step) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        stroke,
      );
    }
  }

  @override
  bool shouldRepaint(ConflictHatch oldDelegate) => oldDelegate.colour != colour;
}
