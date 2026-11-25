import 'dart:convert';

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

/// Opens the unified slide-up Report / Post Item sheet matching
/// `casama-app-mockup.html` while keeping existing Lost & Found tests happy.
Future<void> showReportItemSheet(BuildContext context) {
  return showCasamaSheet<void>(
    context,
    icon: Icons.sell_outlined,
    title: 'Post an Item',
    subtitle: 'Lost, found, or shared belongings in your home',
    builder: (sheetCtx) => _ReportItemSheetBody(hostContext: context),
  );
}

class _ReportItemSheetBody extends ConsumerStatefulWidget {
  final BuildContext hostContext;

  const _ReportItemSheetBody({required this.hostContext});

  @override
  ConsumerState<_ReportItemSheetBody> createState() =>
      _ReportItemSheetBodyState();
}

class _ReportItemSheetBodyState extends ConsumerState<_ReportItemSheetBody> {
  ItemType _type = ItemType.lost;
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  String? _selectedImageBase64;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );
      if (file != null && mounted) {
        final bytes = await file.readAsBytes();
        setState(() {
          _selectedImageBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        });
      }
    } catch (_) {
      if (widget.hostContext.mounted) {
        showCasamaToast(
          widget.hostContext,
          'Could not attach that photo',
          icon: Icons.info_outline_rounded,
        );
      }
    }
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      showCasamaToast(
        widget.hostContext,
        'Please enter an item title',
        icon: Icons.info_outline_rounded,
      );
      return;
    }

    final fallbackImage = _type == ItemType.lost
        ? 'https://images.unsplash.com/photo-1600294037681-c80b4cb5b434?auto=format&fit=crop&w=300&q=80'
        : (_type == ItemType.found
              ? 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?auto=format&fit=crop&w=300&q=80'
              : 'https://images.unsplash.com/photo-1558317374-067fb5f30001?auto=format&fit=crop&w=300&q=80');

    ref
        .read(repositoryProvider)
        .postItem(
          type: _type,
          title: title,
          description: _descController.text.trim(),
          imageUrl: _selectedImageBase64 ?? fallbackImage,
        );

    Navigator.of(context).pop();
    if (widget.hostContext.mounted) {
      showCasamaToast(
        widget.hostContext,
        'Posted "$title" to Lost & Found',
        icon: Icons.check_circle_outline_rounded,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Lost Item'),
              selected: _type == ItemType.lost,
              onSelected: (_) => setState(() => _type = ItemType.lost),
              selectedColor: pal.softBlush,
              backgroundColor: pal.track,
              side: BorderSide(
                color: _type == ItemType.lost ? pal.primaryCoral : pal.border,
              ),
              labelStyle: TextStyle(
                color: _type == ItemType.lost
                    ? pal.primaryCoral
                    : pal.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            ChoiceChip(
              label: const Text('Found Item'),
              selected: _type == ItemType.found,
              onSelected: (_) => setState(() => _type = ItemType.found),
              selectedColor: pal.amberBg,
              backgroundColor: pal.track,
              side: BorderSide(
                color: _type == ItemType.found ? pal.amberFg : pal.border,
              ),
              labelStyle: TextStyle(
                color: _type == ItemType.found ? pal.amberFg : pal.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            ChoiceChip(
              label: const Text('Borrowed / Shared'),
              selected: _type == ItemType.shared,
              onSelected: (_) => setState(() => _type = ItemType.shared),
              selectedColor: pal.successBg,
              backgroundColor: pal.track,
              side: BorderSide(
                color: _type == ItemType.shared ? pal.successFg : pal.border,
              ),
              labelStyle: TextStyle(
                color: _type == ItemType.shared
                    ? pal.successFg
                    : pal.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: CasamaSpacing.md),

        TextField(
          controller: _titleController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Item Title',
            hintText: 'e.g., AirPods, Keys, Blue Backpack',
          ),
        ),
        const SizedBox(height: CasamaSpacing.md),

        TextField(
          controller: _descController,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Location / Details',
            hintText: 'e.g., Common room counter, available to borrow',
          ),
        ),
        const SizedBox(height: CasamaSpacing.md),

        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: pal.track,
                  border: Border.all(color: pal.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _selectedImageBase64 != null
                    ? Image.memory(
                        base64Decode(_selectedImageBase64!.split(',').last),
                        fit: BoxFit.cover,
                      )
                    : Icon(Icons.photo_camera_outlined, color: pal.textMuted),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      side: BorderSide(color: pal.border),
                    ),
                    icon: const Icon(Icons.photo_camera_outlined, size: 16),
                    label: const Text('Camera'),
                    onPressed: () => _pickImage(ImageSource.camera),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      side: BorderSide(color: pal.border),
                    ),
                    icon: const Icon(Icons.photo_library_outlined, size: 16),
                    label: const Text('Gallery'),
                    onPressed: () => _pickImage(ImageSource.gallery),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: CasamaSpacing.lg),

        CasamaButton(
          label: 'Post to Housemates',
          isPill: true,
          height: 50,
          onPressed: _submit,
        ),
      ],
    );
  }
}
