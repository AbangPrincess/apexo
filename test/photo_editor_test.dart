import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:apexo/core/photo_crop.dart';
import 'package:apexo/features/me/photo_editor.dart';

Uint8List _jpeg(int w, int h) =>
    img.encodeJpg(img.Image(width: w, height: h)..clear(img.ColorRgb8(200, 40, 30)));

void main() {
  group('CropView', () {
    test('zoom 1 just covers the frame and stays inside the photo', () {
      // A 1200x800 photo in a 300x100 cover frame: the width decides.
      const v = CropView(center: (x: 0, y: 0), zoom: 1);
      final c = v.clamped(1200, 800, 300, 100);
      final r = c.rect(1200, 800, 300, 100);
      expect(r.w, 1200);
      expect(r.h, 400);
      expect(r.x, 0, reason: 'pushed back inside the photo');
      expect(r.y, 0);
    });

    test('zooming in shows a smaller part around the center', () {
      const v = CropView(center: (x: 600, y: 400), zoom: 2);
      final r = v.clamped(1200, 800, 200, 200).rect(1200, 800, 200, 200);
      expect(r.w, 400);
      expect(r.h, 400);
      expect(r.x, 400);
      expect(r.y, 200);
    });

    test('zoom is limited to 1x to 4x', () {
      const v = CropView(center: (x: 50, y: 50), zoom: 9);
      expect(v.clamped(100, 100, 50, 50).zoom, CropView.maxZoom);
    });
  });

  test('crops to the saved size as a JPEG with no metadata', () {
    final photo = decodeUpright(_jpeg(900, 600))!;
    final jpg = cropToJpeg(CropRequest(photo, 0, 0, 900, 300, 1500, 500, 500 * 1024));
    final out = img.decodeJpg(jpg)!;
    expect(out.width, 1500);
    expect(out.height, 500);
    expect(out.exif.isEmpty, isTrue);
  });

  testWidgets('the editor saves a 3:1 cover after dragging', (tester) async {
    Uint8List? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => saved = await editPhoto(context, _jpeg(800, 800), avatar: false),
            child: const Text('Pick'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Pick'));
    await tester.pump();
    Future<void> waitFor(bool Function() done) async {
      for (var i = 0; i < 100 && !done(); i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    await waitFor(() => find.byType(RawImage).evaluate().isNotEmpty);
    await tester.pumpAndSettle();
    expect(find.text('Position your cover'), findsOneWidget);
    await tester.drag(find.byType(RawImage), const Offset(0, -80), warnIfMissed: false);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('photo-save')));
    await waitFor(() => saved != null);
    final out = img.decodeJpg(saved!)!;
    expect((out.width, out.height), (1500, 500));
  });
}
