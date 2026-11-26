import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/motion/casama_motion.dart';
import '../../../data/models.dart';
import '../../../data/repository_provider.dart';
import '../../../shared/widgets/casama_button.dart';
import '../../../shared/widgets/casama_sheet_scaffold.dart';
import '../../../shared/widgets/casama_text_field.dart';

/// Slide-up sheet allowing a housemate to report finding an open lost item.
Future<void> showSubmitFoundMatchSheet(
  BuildContext context, {
  required LostFoundItem lostItem,
}) {
  return showCasamaSheet<void>(
    context,
    icon: Icons.where_to_vote_outlined,
    title: 'Report Found Match',
    subtitle: 'For "${lostItem.title}" • Earn +5 pts when confirmed',
    builder: (sheetCtx) => _SubmitFoundMatchBody(
      hostContext: context,
      lostItem: lostItem,
    ),
  );
}

class _SubmitFoundMatchBody extends ConsumerStatefulWidget {
  final BuildContext hostContext;
  final LostFoundItem lostItem;

  const _SubmitFoundMatchBody({
    required this.hostContext,
    required this.lostItem,
  });

  @override
  ConsumerState<_SubmitFoundMatchBody> createState() =>
      _SubmitFoundMatchBodyState();
}

class _SubmitFoundMatchBodyState extends ConsumerState<_SubmitFoundMatchBody> {
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  XFile? _pickedImageFile;
  Uint8List? _pickedImageBytes;
  String? _pickedImageBase64;
  bool _submitting = false;

  @override
  void dispose() {
    _locationController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 800,
        imageQuality: 70,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        if (!mounted) return;
        setState(() {
          _pickedImageFile = image;
          _pickedImageBytes = bytes;
          _pickedImageBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        });
      }
    } catch (_) {
      // Gracefully ignore missing camera permissions in tests.
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    final location = _locationController.text.trim();
    final note = _noteController.text.trim();

    final err = await ref.read(repositoryProvider).submitLostItemFind(
      lostItem: widget.lostItem,
      foundLocation: location.isEmpty ? null : location,
      description: note.isEmpty ? null : note,
      imageUrl: _pickedImageBase64,
      imageBytes: _pickedImageBytes,
      imageFile: _pickedImageFile,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (err != null) {
      showCasamaToast(
        widget.hostContext.mounted ? widget.hostContext : context,
        err,
        icon: Icons.info_outline_rounded,
      );
      return;
    }

    Navigator.of(context).pop();
    if (widget.hostContext.mounted) {
      showCasamaToast(
        widget.hostContext,
        'Find submitted for ${widget.lostItem.reportedByName} to review!',
        icon: Icons.check_circle_outline_rounded,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CasamaTextField(
          controller: _locationController,
          label: 'Found Location',
          hint: 'e.g., Under the study room desk',
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: CasamaSpacing.md),
        CasamaTextField(
          controller: _noteController,
          label: 'Note (optional)',
          hint: 'e.g., Placed on the kitchen counter',
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: CasamaSpacing.md),
        Row(
          children: [
            Expanded(
              child: CasamaPressable(
                onTap: () => _pickPhoto(ImageSource.camera),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: pal.track,
                    borderRadius: CasamaSpacing.roundedMd,
                    border: Border.all(color: pal.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.camera_alt_outlined,
                        size: 16,
                        color: pal.primaryCoral,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Take Photo',
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: pal.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: CasamaSpacing.xs),
            Expanded(
              child: CasamaPressable(
                onTap: () => _pickPhoto(ImageSource.gallery),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: pal.track,
                    borderRadius: CasamaSpacing.roundedMd,
                    border: Border.all(color: pal.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.photo_library_outlined,
                        size: 16,
                        color: pal.forestTeal,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Gallery',
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: pal.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_pickedImageBytes != null) ...[
          const SizedBox(height: CasamaSpacing.sm),
          ClipRRect(
            borderRadius: CasamaSpacing.roundedMd,
            child: Stack(
              children: [
                Image.memory(
                  _pickedImageBytes!,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: CasamaPressable(
                    onTap: () => setState(() {
                      _pickedImageFile = null;
                      _pickedImageBytes = null;
                      _pickedImageBase64 = null;
                    }),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: CasamaSpacing.lg),
        CasamaButton(
          label: 'Submit Find',
          icon: Icons.check_circle_outline_rounded,
          isLoading: _submitting,
          onPressed: _submit,
        ),
      ],
    );
  }
}
