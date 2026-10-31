import 'dart:typed_data';

/// Minimal JPEG EXIF stripper (§7.2 privacy requirement).
///
/// EXIF (including GPS) lives in JPEG APP1/APP2 marker segments. This walks
/// the segment chain and rebuilds the file without them — no re-encode, no
/// quality loss, no dependency. Only valid JPEG is touched; anything else
/// is returned unchanged.
///
/// The GPS coordinate must be extracted BEFORE calling this.
Uint8List stripJpegExif(Uint8List bytes) {
  // JPEG: FFD8, then segments: FF marker, length(2B, includes itself)
  if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) {
    return bytes; // not a JPEG (PNG/HEIC/webp) — leave as-is
  }

  final out = BytesBuilder();
  out.add(bytes.sublist(0, 2)); // SOI

  var i = 2;
  while (i + 4 <= bytes.length) {
    if (bytes[i] != 0xFF) {
      // Malformed — return original rather than emitting a broken file.
      return bytes;
    }
    final marker = bytes[i + 1];

    // SOS: image data follows — copy the remainder and stop.
    if (marker == 0xDA) {
      out.add(bytes.sublist(i));
      return out.toBytes();
    }

    // Standalone markers without payload length
    if (marker == 0xD8 || marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) {
      out.add(bytes.sublist(i, i + 2));
      i += 2;
      continue;
    }

    final length = (bytes[i + 2] << 8) | bytes[i + 3];
    if (length < 2 || i + 2 + length > bytes.length) {
      return bytes; // malformed
    }

    final isApp1 = marker == 0xE1; // EXIF / XMP
    final isApp2 = marker == 0xE2; // ICC / FlashPix

    if (!isApp1 && !isApp2) {
      out.add(bytes.sublist(i, i + 2 + length));
    }
    // APP1/APP2 dropped: privacy (EXIF GPS) — ICC profiles sacrificed too;
    // acceptable for chat media.

    i += 2 + length;
  }

  return bytes;
}
