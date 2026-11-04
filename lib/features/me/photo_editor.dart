import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/image_check.dart';
import '../../core/photo_crop.dart';
import '../../core/theme.dart';
import '../../widgets/crop_frame_painter.dart';

/// Lets the person place the photo before it is saved: a circle for the
/// profile photo, a 3:1 frame for the cover. Returns the cropped JPEG, or
/// null when they cancel.
Future<Uint8List?> editPhoto(BuildContext context, Uint8List bytes, {required bool avatar}) =>
    Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PhotoEditorScreen(bytes: bytes, avatar: avatar),
      ),
    );

class PhotoEditorScreen extends StatefulWidget {
  const PhotoEditorScreen({super.key, required this.bytes, required this.avatar});

  final Uint8List bytes;
  final bool avatar;

  @override
  State<PhotoEditorScreen> createState() => _PhotoEditorScreenState();
}

class _PhotoEditorScreenState extends State<PhotoEditorScreen> {
  UprightPhoto? _photo;
  ui.Image? _preview;
  CropView? _view;
  bool _failed = false;
  bool _saving = false;
  Size _frame = Size.zero;
  Offset _mid = Offset.zero;
  CropView? _startView;
  Offset _startFocal = Offset.zero;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _preview?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final photo = await compute(decodeUpright, widget.bytes);
    if (photo == null) {
      if (mounted) setState(() => _failed = true);
      return;
    }
    final done = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      photo.rgba,
      photo.width,
      photo.height,
      ui.PixelFormat.rgba8888,
      done.complete,
    );
    final preview = await done.future;
    if (!mounted) return preview.dispose();
    setState(() {
      _photo = photo;
      _preview = preview;
      _view = CropView(center: (x: photo.width / 2, y: photo.height / 2), zoom: 1);
    });
  }

  double get _w => _photo!.width.toDouble();
  double get _h => _photo!.height.toDouble();
  double get _base => CropView.baseScale(_w, _h, _frame.width, _frame.height);

  void _set(CropView v) => setState(() => _view = v.clamped(_w, _h, _frame.width, _frame.height));

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final start = _startView;
    if (start == null) return;
    final s0 = _base * start.zoom;
    final zoom = (start.zoom * d.scale).clamp(1.0, CropView.maxZoom);
    final s1 = _base * zoom;
    // The image point under the fingers stays under them.
    final px = start.center.x + (_startFocal.dx - _mid.dx) / s0;
    final py = start.center.y + (_startFocal.dy - _mid.dy) / s0;
    _set(
      CropView(
        center: (
          x: px - (d.localFocalPoint.dx - _mid.dx) / s1,
          y: py - (d.localFocalPoint.dy - _mid.dy) / s1,
        ),
        zoom: zoom,
      ),
    );
  }

  void _zoomTo(double zoom) => _set(CropView(center: _view!.center, zoom: zoom));

  Future<void> _save() async {
    setState(() => _saving = true);
    final r = _view!.rect(_w, _h, _frame.width, _frame.height);
    final out = widget.avatar ? avatarOut : coverOut;
    final limit = widget.avatar ? maxAvatarBytes : maxCoverBytes;
    final jpg = await compute(
      cropToJpeg,
      CropRequest(_photo!, r.x, r.y, r.w, r.h, out.w, out.h, limit),
    );
    if (mounted) Navigator.of(context).pop(jpg);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final ready = _view != null && _preview != null;
    return Scaffold(
      backgroundColor: AppColors.dark,
      appBar: AppBar(
        backgroundColor: AppColors.dark,
        foregroundColor: Colors.white,
        shape: const Border(),
        title: Text(
          widget.avatar ? 'Move and scale' : 'Position your cover',
          style: t.titleLarge?.copyWith(color: Colors.white),
        ),
        actions: [
          TextButton(
            key: const ValueKey('photo-save'),
            onPressed: ready && !_saving ? _save : null,
            style: TextButton.styleFrom(foregroundColor: AppColors.tracking),
            child: Text(_saving ? 'Saving…' : 'Save'),
          ),
        ],
      ),
      body: SafeArea(
        child: _failed
            ? Center(
                child: Text(
                  "Couldn't read that photo. Try another one.",
                  style: t.bodyLarge?.copyWith(color: Colors.white),
                ),
              )
            : !ready
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(child: LayoutBuilder(builder: (context, c) => _area(c))),
                  _controls(t),
                ],
              ),
      ),
    );
  }

  Widget _area(BoxConstraints c) {
    final w = (c.maxWidth - 2 * Space.l).clamp(120.0, 560.0);
    final side = widget.avatar ? w.clamp(120.0, c.maxHeight - 2 * Space.l) : w;
    _frame = widget.avatar ? Size(side, side) : Size(w, w / 3);
    _mid = Offset(c.maxWidth / 2, c.maxHeight / 2);
    final v = _view!.clamped(_w, _h, _frame.width, _frame.height);
    final s = _base * v.zoom;
    final frame = Rect.fromCenter(center: _mid, width: _frame.width, height: _frame.height);
    return Listener(
      // Mouse wheel zooms on the web and desktop.
      onPointerSignal: (e) {
        if (e is PointerScrollEvent) _zoomTo(v.zoom * (e.scrollDelta.dy > 0 ? 0.9 : 1.1));
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: (d) {
          _startView = v;
          _startFocal = d.localFocalPoint;
        },
        onScaleUpdate: _onScaleUpdate,
        child: ClipRect(
          child: Stack(
            children: [
              Positioned(
                left: _mid.dx - v.center.x * s,
                top: _mid.dy - v.center.y * s,
                width: _w * s,
                height: _h * s,
                child: RawImage(image: _preview, fit: BoxFit.fill),
              ),
              Positioned.fill(
                child: CustomPaint(painter: CropFramePainter(frame, circle: widget.avatar)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controls(TextTheme t) => Padding(
    padding: const EdgeInsets.fromLTRB(Space.l, 0, Space.l, Space.m),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Icon(Icons.photo_size_select_small_rounded, color: AppColors.onDarkMuted),
            Expanded(
              child: Slider(
                value: _view!.zoom,
                min: 1,
                max: CropView.maxZoom,
                label: 'Zoom',
                activeColor: AppColors.tracking,
                onChanged: _zoomTo,
              ),
            ),
            const Icon(Icons.photo_size_select_large_rounded, color: AppColors.onDarkMuted),
          ],
        ),
        Text(
          'Drag to move. Pinch or slide to zoom.',
          style: t.bodySmall?.copyWith(color: AppColors.onDarkMuted),
        ),
      ],
    ),
  );
}
