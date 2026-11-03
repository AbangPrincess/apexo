import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/image_check.dart';
import '../../core/theme.dart';

enum PhotoSlot { avatar, cover }

/// Lets the user pick, take or remove a photo. Returns a data URI, an empty
/// string for "remove", or null when cancelled or rejected.
Future<String?> pickProfilePhoto(
  BuildContext context, {
  required PhotoSlot slot,
  required bool hasPhoto,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final label = slot == PhotoSlot.avatar ? 'profile photo' : 'cover photo';
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 480),
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from library'),
            onTap: () => Navigator.pop(sheet, 'gallery'),
          ),
          if (!kIsWeb)
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(sheet, 'camera'),
            ),
          if (hasPhoto)
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.alert),
              title: Text('Remove $label', style: const TextStyle(color: AppColors.alert)),
              onTap: () => Navigator.pop(sheet, 'remove'),
            ),
          const SizedBox(height: Space.s),
        ],
      ),
    ),
  );
  if (choice == null) return null;
  if (choice == 'remove') return '';

  final avatar = slot == PhotoSlot.avatar;
  try {
    final file = await ImagePicker().pickImage(
      source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
      // Resized on the device so the photo fits in the profile document.
      maxWidth: avatar ? 512 : 1600,
      maxHeight: avatar ? 512 : 900,
      imageQuality: avatar ? 82 : 78,
      requestFullMetadata: false,
    );
    if (file == null) return null;
    final bytes = removeJpegLocation(await file.readAsBytes());
    final problem = imageProblem(bytes, maxBytes: avatar ? maxAvatarBytes : maxCoverBytes);
    if (problem != null) {
      messenger.showSnackBar(SnackBar(content: Text(problem)));
      return null;
    }
    return toDataUri(bytes);
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text("Couldn't open that photo. Check photo access and try again.")),
    );
    return null;
  }
}
