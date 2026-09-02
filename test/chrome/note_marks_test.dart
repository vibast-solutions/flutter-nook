import 'package:flutter_test/flutter_test.dart';
import 'package:nook/chrome/note_marks.dart';

void main() {
  group('pencil marks', () {
    test('a fresh cell has none', () {
      const NoteMarks marks = NoteMarks.empty();

      expect(marks.isEmpty, isTrue);
      expect(marks.isNotEmpty, isFalse);
      expect(marks.mask, 0);
      expect(marks.digits, isEmpty);
    });

    test('a digit goes in and comes back out with the same tap', () {
      const NoteMarks empty = NoteMarks.empty();

      final NoteMarks withFour = empty.toggled(4);
      expect(withFour.contains(4), isTrue);
      expect(withFour.digits, <int>[4]);

      final NoteMarks withoutFour = withFour.toggled(4);
      expect(withoutFour.contains(4), isFalse);
      expect(withoutFour, empty);
    });

    test('marks read back smallest first, however they went in', () {
      final NoteMarks marks = const NoteMarks.empty()
          .toggled(7)
          .toggled(2)
          .toggled(9);

      expect(marks.digits, <int>[2, 7, 9]);
      expect(marks, NoteMarks.of(<int>[9, 7, 2]));
    });

    test('a mark is one bit, so a cell of notes is one integer', () {
      expect(NoteMarks.of(<int>[1]).mask, 1);
      expect(NoteMarks.of(<int>[2]).mask, 2);
      expect(NoteMarks.of(<int>[9]).mask, 256);
      expect(NoteMarks.of(<int>[1, 2, 9]).mask, 259);
      expect(const NoteMarks(259).digits, <int>[1, 2, 9]);
    });

    test('digits no board has are ignored rather than corrupting the mask', () {
      const NoteMarks marks = NoteMarks.empty();

      expect(marks.toggled(0), marks);
      expect(marks.toggled(10), marks);
      expect(marks.toggled(-1), marks);
      expect(marks.contains(0), isFalse);
      expect(marks.contains(10), isFalse);
      expect(NoteMarks.of(<int>[0, 3, 12]).digits, <int>[3]);
    });

    test('two cells noted the same are the same marks', () {
      expect(NoteMarks.of(<int>[1, 5]), NoteMarks.of(<int>[5, 1]));
      expect(
        NoteMarks.of(<int>[1, 5]).hashCode,
        NoteMarks.of(<int>[5, 1]).hashCode,
      );
      expect(NoteMarks.of(<int>[1, 5]), isNot(NoteMarks.of(<int>[1, 6])));
    });
  });
}
