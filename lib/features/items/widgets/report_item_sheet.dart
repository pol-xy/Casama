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
import '../../../shared/widgets/casama_lost_found_icon.dart';
import '../../../shared/widgets/casama_sheet_scaffold.dart';
import '../../../shared/widgets/casama_text_field.dart';

/// Opens the unified slide-up Report Item sheet matching
/// `casama-app-mockup.html` (`280ms` ease-out rise, Light/Dark parity).
Future<void> showReportItemSheet(
  BuildContext context, {
  ItemType initialType = ItemType.lost,
}) {
  return showCasamaSheet<void>(
    context,
    iconWidget: const CasamaLostFoundIcon(size: 24),
    title: 'Report an Item',
    subtitle: 'Post a lost or found item',
    builder: (sheetCtx) =>
        _ReportItemSheetBody(hostContext: context, initialType: initialType),
  );
}

class _ReportItemSheetBody extends ConsumerStatefulWidget {
  final BuildContext hostContext;
  final ItemType initialType;

  const _ReportItemSheetBody({
    required this.hostContext,
    required this.initialType,
  });

  @override
  ConsumerState<_ReportItemSheetBody> createState() =>
      _ReportItemSheetBodyState();
}

class _ReportItemSheetBodyState extends ConsumerState<_ReportItemSheetBody> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  late ItemType _selectedType;
  String? _pickedImageBase64;
  Uint8List? _pickedImageBytes;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType == ItemType.found
        ? ItemType.found
        : ItemType.lost;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
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
          _pickedImageBytes = bytes;
          _pickedImageBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        });
      }
    } catch (_) {
      // Gracefully ignore missing camera permissions in tests.
    }
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      showCasamaToast(
        widget.hostContext,
        'Please enter an item title.',
        icon: Icons.info_outline_rounded,
      );
      return;
    }

    final desc = _descController.text.trim();
    ref
        .read(repositoryProvider)
        .postItem(
          title: title,
          description: desc.isEmpty ? 'Posted via Casama' : desc,
          location: desc.isEmpty ? null : desc,
          type: _selectedType,
          imageUrl: _pickedImageBase64,
          imageBytes: _pickedImageBytes,
        );

    Navigator.of(context).pop();
    if (widget.hostContext.mounted) {
      showCasamaToast(
        widget.hostContext,
        'Posted "$title" to Lost & Found!',
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
        Text(
          'Type',
          style: theme.textTheme.labelMedium?.copyWith(
            color: pal.textSecondary,
          ),
        ),
        const SizedBox(height: CasamaSpacing.xs),
        Row(
          children: [
            Expanded(
              child: _TypePill(
                label: 'Lost Item',
                selected: _selectedType == ItemType.lost,
                onTap: () => setState(() => _selectedType = ItemType.lost),
              ),
            ),
            const SizedBox(width: CasamaSpacing.xs),
            Expanded(
              child: _TypePill(
                label: 'Found Item',
                selected: _selectedType == ItemType.found,
                onTap: () => setState(() => _selectedType = ItemType.found),
              ),
            ),
          ],
        ),
        const SizedBox(height: CasamaSpacing.md),

        CasamaTextField(
          controller: _titleController,
          label: 'Item Title',
          hint: 'e.g., Hydroflask Water Bottle',
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: CasamaSpacing.md),

        CasamaTextField(
          controller: _descController,
          label: 'Description / Location (optional)',
          hint: 'e.g., Left near kitchen counter',
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
          label: 'Post to Board',
          icon: Icons.send_rounded,
          onPressed: _submit,
        ),
      ],
    );
  }
}

class _TypePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TypePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: CasamaPressable(
        onTap: onTap,
        enableHaptic: true,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: CasamaSpacing.minTouchTarget,
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? pal.primaryCoral : pal.track,
            borderRadius: CasamaSpacing.roundedPill,
            border: Border.all(
              color: selected ? pal.primaryCoral : pal.border,
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: selected ? pal.onPrimaryCoral : pal.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
          ),
        ),
      ),
    );
  }
}
