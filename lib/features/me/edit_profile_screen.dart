import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../data/models/user.dart';
import '../../data/repository.dart';
import '../../widgets/profile_image.dart';
import '../../widgets/responsive.dart';
import 'photo_picker.dart';
import 'settings_screen.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user.displayName);
  late final _bio = TextEditingController(text: widget.user.bio);
  late final _hometown = TextEditingController(text: widget.user.hometown);
  late String _photo = widget.user.photoUrl;
  late String _cover = widget.user.coverUrl;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _hometown.dispose();
    super.dispose();
  }

  Future<void> _pick(PhotoSlot slot) async {
    final current = slot == PhotoSlot.avatar ? _photo : _cover;
    final url = await pickProfilePhoto(context, slot: slot, hasPhoto: current.isNotEmpty);
    if (url == null || !mounted) return;
    setState(() => slot == PhotoSlot.avatar ? _photo = url : _cover = url);
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    await context.read<AppRepository>().updateProfile(
      widget.user.uid,
      displayName: _name.text.trim(),
      bio: _bio.text.trim(),
      hometown: _hometown.text.trim(),
      photoUrl: _photo,
      coverUrl: _cover,
    );
    navigator.pop();
    messenger.showSnackBar(const SnackBar(content: Text('Profile updated')));
  }

  @override
  Widget build(BuildContext context) {
    final cover = profileImage(_cover);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit profile'),
        actions: [
          TextButton(onPressed: _saving ? null : _save, child: const Text('Save')),
          const SizedBox(width: Space.s),
        ],
      ),
      body: Form(
        key: _form,
        child: PageListView(
          maxWidth: 640,
          children: [
            const SectionLabel('Profile photo'),
            Row(
              children: [
                UserAvatar(photoUrl: _photo, initial: widget.user.initial, radius: 40),
                const SizedBox(width: Space.m),
                OutlinedButton.icon(
                  onPressed: () => _pick(PhotoSlot.avatar),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Change photo'),
                ),
              ],
            ),
            const SizedBox(height: Space.l),
            const SectionLabel('Cover photo'),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 130,
                child: cover == null
                    ? const ColoredBox(
                        color: AppColors.accentSoft,
                        child: Center(
                          child: Text('Your longest route shows here until you add one'),
                        ),
                      )
                    : Image(image: cover, fit: BoxFit.cover, width: double.infinity),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _pick(PhotoSlot.cover),
                icon: const Icon(Icons.wallpaper_rounded),
                label: const Text('Change cover photo'),
              ),
            ),
            const SizedBox(height: Space.m),
            const SectionLabel('About you'),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              maxLength: 40,
              validator: validateDisplayName,
              decoration: const InputDecoration(labelText: 'Name', counterText: ''),
            ),
            const SizedBox(height: Space.m),
            TextFormField(
              controller: _bio,
              minLines: 2,
              maxLines: 4,
              maxLength: maxBioLength,
              textCapitalization: TextCapitalization.sentences,
              validator: validateBio,
              decoration: const InputDecoration(
                labelText: 'Bio',
                hintText: 'What do you ride? Favorite routes?',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: Space.s),
            TextFormField(
              controller: _hometown,
              maxLength: maxHometownLength,
              textCapitalization: TextCapitalization.words,
              validator: validateHometown,
              decoration: const InputDecoration(
                labelText: 'Hometown',
                prefixIcon: Icon(Icons.location_on_outlined),
                counterText: '',
              ),
            ),
            const SizedBox(height: Space.l),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: Text(_saving ? 'Saving…' : 'Save profile'),
            ),
          ],
        ),
      ),
    );
  }
}
