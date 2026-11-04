import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Saved sizes: a square profile photo and a 3:1 cover.
const avatarOut = (w: 400, h: 400);
const coverOut = (w: 1500, h: 500);

/// A photo turned upright (EXIF orientation applied) and no larger than
/// [maxSide], with its RGBA pixels for the editor preview.
class UprightPhoto {
  UprightPhoto(this.image)
    : rgba = image.convert(numChannels: 4).getBytes(order: img.ChannelOrder.rgba);

  final img.Image image;
  final Uint8List rgba;

  int get width => image.width;
  int get height => image.height;
}

const maxSide = 2400;

/// Null when the bytes are not a supported image. Top-level, so it can run
/// on a background isolate with compute().
UprightPhoto? decodeUpright(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  var upright = img.bakeOrientation(decoded);
  final longest = math.max(upright.width, upright.height);
  if (longest > maxSide) {
    upright = img.copyResize(
      upright,
      width: upright.width >= upright.height ? maxSide : null,
      height: upright.height > upright.width ? maxSide : null,
      interpolation: img.Interpolation.average,
    );
  }
  return UprightPhoto(upright);
}

/// What to cut out of an [UprightPhoto] (image pixels) and the saved size.
class CropRequest {
  const CropRequest(
    this.photo,
    this.x,
    this.y,
    this.w,
    this.h,
    this.outW,
    this.outH,
    this.maxBytes,
  );

  final UprightPhoto photo;
  final int x, y, w, h, outW, outH, maxBytes;
}

/// The cropped JPEG, re-encoded with no metadata (no location, no camera
/// details), at the best quality that fits [CropRequest.maxBytes].
Uint8List cropToJpeg(CropRequest r) {
  final src = r.photo.image;
  final x = r.x.clamp(0, src.width - 1);
  final y = r.y.clamp(0, src.height - 1);
  final cropped = img.copyCrop(
    src,
    x: x,
    y: y,
    width: r.w.clamp(1, src.width - x),
    height: r.h.clamp(1, src.height - y),
  );
  final sized = img.copyResize(
    cropped,
    width: r.outW,
    height: r.outH,
    interpolation: img.Interpolation.average,
  )..exif = img.ExifData();
  var quality = 86;
  var jpg = img.encodeJpg(sized, quality: quality);
  while (jpg.length > r.maxBytes && quality > 50) {
    quality -= 8;
    jpg = img.encodeJpg(sized, quality: quality);
  }
  return jpg;
}

/// The part of an image a frame shows. [center] is the image point at the
/// middle of the frame (image pixels); [zoom] 1 just covers the frame.
class CropView {
  const CropView({required this.center, required this.zoom});

  final ({double x, double y}) center;
  final double zoom;

  static const maxZoom = 4.0;

  /// Image pixels to screen pixels for an image of [imgW] x [imgH] in a
  /// frame of [frameW] x [frameH].
  static double baseScale(double imgW, double imgH, double frameW, double frameH) =>
      math.max(frameW / imgW, frameH / imgH);

  /// Keeps the frame inside the image.
  CropView clamped(double imgW, double imgH, double frameW, double frameH) {
    final z = zoom.clamp(1.0, maxZoom);
    final s = baseScale(imgW, imgH, frameW, frameH) * z;
    final halfW = math.min(frameW / (2 * s), imgW / 2);
    final halfH = math.min(frameH / (2 * s), imgH / 2);
    return CropView(
      center: (x: center.x.clamp(halfW, imgW - halfW), y: center.y.clamp(halfH, imgH - halfH)),
      zoom: z,
    );
  }

  /// The visible rectangle in image pixels: x, y, width, height.
  ({int x, int y, int w, int h}) rect(double imgW, double imgH, double frameW, double frameH) {
    final s = baseScale(imgW, imgH, frameW, frameH) * zoom;
    final w = frameW / s;
    final h = frameH / s;
    return (
      x: (center.x - w / 2).round(),
      y: (center.y - h / 2).round(),
      w: w.round(),
      h: h.round(),
    );
  }
}
