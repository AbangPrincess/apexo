import 'dart:convert';
import 'dart:typed_data';

enum ImageKind {
  jpeg('image/jpeg'),
  png('image/png'),
  webp('image/webp');

  const ImageKind(this.mime);
  final String mime;
}

/// Profile photos are small enough to live in the profile document, which
/// works on the free Firebase plan (no Cloud Storage bucket needed).
const int maxAvatarBytes = 200 * 1024;
const int maxCoverBytes = 500 * 1024;

/// Detects the format from the file's first bytes, not its name.
ImageKind? sniffImage(Uint8List b) {
  if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return ImageKind.jpeg;
  if (b.length >= 8 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) {
    return ImageKind.png;
  }
  if (b.length >= 12 &&
      ascii.decode(b.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
      ascii.decode(b.sublist(8, 12), allowInvalid: true) == 'WEBP') {
    return ImageKind.webp;
  }
  return null;
}

/// Error message for the user, or null when the image is acceptable.
String? imageProblem(Uint8List bytes, {required int maxBytes}) {
  if (sniffImage(bytes) == null) return 'Choose a JPEG, PNG or WebP photo.';
  if (bytes.length > maxBytes) {
    return 'That photo is too large. Try a smaller one (max ${maxBytes ~/ 1024} KB).';
  }
  return null;
}

String toDataUri(Uint8List bytes) {
  final kind = sniffImage(bytes) ?? ImageKind.jpeg;
  return 'data:${kind.mime};base64,${base64Encode(bytes)}';
}

/// Bytes from a `data:image/...;base64,` URI, or null for anything else.
Uint8List? bytesFromDataUri(String uri) {
  if (!uri.startsWith('data:image/')) return null;
  final comma = uri.indexOf(';base64,');
  if (comma < 0) return null;
  try {
    return base64Decode(uri.substring(comma + 8));
  } on FormatException {
    return null;
  }
}

/// Returns a copy of a JPEG with its GPS (location) tags removed, so a profile
/// photo never reveals where it was taken. Other EXIF data, including the
/// orientation, is kept. Non-JPEG or malformed input is returned unchanged.
Uint8List removeJpegLocation(Uint8List input) {
  if (sniffImage(input) != ImageKind.jpeg) return input;
  final out = Uint8List.fromList(input);
  var i = 2;
  while (i + 4 <= out.length && out[i] == 0xFF) {
    final marker = out[i + 1];
    if (marker == 0xDA || marker == 0xD9) break; // image data starts
    final len = (out[i + 2] << 8) | out[i + 3];
    if (len < 2 || i + 2 + len > out.length) break;
    final isExif =
        marker == 0xE1 &&
        len >= 16 &&
        ascii.decode(out.sublist(i + 4, i + 8), allowInvalid: true) == 'Exif';
    if (isExif) _scrubGps(out, i + 10, i + 2 + len);
    i += 2 + len;
  }
  return out;
}

void _scrubGps(Uint8List b, int tiff, int end) {
  if (tiff + 8 > end) return;
  final little = b[tiff] == 0x49; // "II" = little endian, "MM" = big
  int u16(int o) => little ? b[o] | (b[o + 1] << 8) : (b[o] << 8) | b[o + 1];
  int u32(int o) => little
      ? b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24)
      : (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];
  const typeSize = {1: 1, 2: 1, 3: 2, 4: 4, 5: 8, 7: 1, 9: 4, 10: 8};

  final ifd0 = tiff + u32(tiff + 4);
  if (ifd0 + 2 > end) return;
  for (var e = 0, n = u16(ifd0); e < n; e++) {
    final entry = ifd0 + 2 + e * 12;
    if (entry + 12 > end || u16(entry) != 0x8825) continue; // GPS IFD pointer
    final gps = tiff + u32(entry + 8);
    if (gps + 2 > end) return;
    final count = u16(gps);
    for (var g = 0; g < count; g++) {
      final ge = gps + 2 + g * 12;
      if (ge + 12 > end) break;
      final size = (typeSize[u16(ge + 2)] ?? 1) * u32(ge + 4);
      // Values over 4 bytes live elsewhere; zero them where they are.
      final at = size > 4 ? tiff + u32(ge + 8) : ge + 8;
      for (var k = at; k < at + (size > 4 ? size : 4) && k < end; k++) {
        b[k] = 0;
      }
      for (var k = ge; k < ge + 8; k++) {
        b[k] = 0;
      }
    }
    b[gps] = 0; // no GPS entries left
    b[gps + 1] = 0;
  }
}
