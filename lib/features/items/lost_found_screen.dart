import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../data/casama_repository.dart';
import '../../data/models.dart';
import '../../data/repository_provider.dart';
import '../../shared/widgets/cas_mascot_view.dart';
import '../../shared/widgets/casama_button.dart';
import '../../shared/widgets/status_chip.dart';

class LostFoundScreen extends ConsumerStatefulWidget {
  final bool initialOpenPostModal;

  const LostFoundScreen({super.key, this.initialOpenPostModal = false});

  @override
  ConsumerState<LostFoundScreen> createState() => _LostFoundScreenState();
}

class _LostFoundScreenState extends ConsumerState<LostFoundScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    if (widget.initialOpenPostModal) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showPostItemModal(context);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);
    final lostItems = repo.items.where((i) => i.type == ItemType.lost).toList();
    final foundItems = repo.items
        .where((i) => i.type == ItemType.found)
        .toList();
    final borrowedItems = repo.items
        .where((i) => i.type == ItemType.shared)
        .toList();

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: const Text('Lost & Found'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            child: TabBar(
              controller: _tabController,
              indicatorColor: CasamaColors.primaryCoral,
              indicatorWeight: 3,
              labelColor: CasamaColors.primaryCoral,
              unselectedLabelColor: context.textSecondaryColor,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
              tabs: const [
                Tab(text: 'Lost'),
                Tab(text: 'Found'),
                Tab(text: 'Borrowed'),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildItemList(lostItems, ItemType.lost),
              _buildItemList(foundItems, ItemType.found),
              _buildItemList(borrowedItems, ItemType.shared),
            ],
          ),

          // Pinned Bottom Button: "📷 Post an Item" (Matching Screen 4)
          Positioned(
            left: 20,
            right: 20,
            bottom: 24,
            child: CasamaButton(
              label: 'Post an Item',
              icon: Icons.camera_alt_outlined,
              onPressed: () => _showPostItemModal(context),
              isPill: true,
              height: 52,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemList(List<LostFoundItem> items, ItemType type) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CasMascotView(
              pose: CasPose.together,
              width: 140,
              height: 140,
            ),
            const SizedBox(height: 16),
            Text(
              type == ItemType.lost
                  ? 'No lost items reported'
                  : (type == ItemType.found
                        ? 'No found items waiting'
                        : 'No borrowed items'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.textColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap "Post an Item" to alert your housemates.',
              style: TextStyle(color: context.textSecondaryColor),
            ),
            const SizedBox(height: 80),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(
        left: CasamaSpacing.lg,
        right: CasamaSpacing.lg,
        top: CasamaSpacing.lg,
        bottom: 90, // Leave room for bottom button
      ),
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final item = items[index];
        return _ItemCard(item: item);
      },
    );
  }

  void _showPostItemModal(BuildContext context) {
    ItemType type = ItemType.lost;
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String? selectedImageBase64;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> pickImage(ImageSource source) async {
              try {
                final picker = ImagePicker();
                final file = await picker.pickImage(
                  source: source,
                  maxWidth: 800,
                  maxHeight: 800,
                  imageQuality: 80,
                );
                if (file != null) {
                  final bytes = await file.readAsBytes();
                  setModalState(() {
                    selectedImageBase64 =
                        'data:image/jpeg;base64,${base64Encode(bytes)}';
                  });
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error picking image: $e')),
                  );
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Post an Item',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: context.textColor,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Type Selector (3 options: Lost, Found, Borrowed)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: const Text('Lost Item'),
                            selected: type == ItemType.lost,
                            onSelected: (_) =>
                                setModalState(() => type = ItemType.lost),
                            selectedColor: const Color(0xFFFFEBEE),
                            labelStyle: TextStyle(
                              color: type == ItemType.lost
                                  ? CasamaColors.primaryCoral
                                  : CasamaColors.ink,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Found Item'),
                            selected: type == ItemType.found,
                            onSelected: (_) =>
                                setModalState(() => type = ItemType.found),
                            selectedColor: const Color(0xFFFFF8E1),
                            labelStyle: TextStyle(
                              color: type == ItemType.found
                                  ? const Color(0xFFF57F17)
                                  : CasamaColors.ink,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Borrowed / Shared'),
                            selected: type == ItemType.shared,
                            onSelected: (_) =>
                                setModalState(() => type = ItemType.shared),
                            selectedColor: const Color(0xFFE8F5E9),
                            labelStyle: TextStyle(
                              color: type == ItemType.shared
                                  ? CasamaColors.homeGreen
                                  : CasamaColors.ink,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    TextField(
                      controller: titleController,
                      style: TextStyle(color: context.textColor),
                      decoration: const InputDecoration(
                        labelText: 'Item Title',
                        hintText: 'e.g., AirPods, Keys, Blue Backpack',
                      ),
                    ),
                    const SizedBox(height: 14),

                    TextField(
                      controller: descController,
                      style: TextStyle(color: context.textColor),
                      decoration: const InputDecoration(
                        labelText: 'Location / Details',
                        hintText:
                            'e.g., Common room counter, available to borrow',
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Photo Attachment Row
                    Row(
                      children: [
                        if (selectedImageBase64 != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              base64Decode(
                                selectedImageBase64!.split(',').last,
                              ),
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: context.isDark
                                  ? CasamaColors.darkSurface
                                  : CasamaColors.softNeutral,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: context.borderColor),
                            ),
                            child: Icon(
                              Icons.camera_alt_outlined,
                              color: context.textMutedColor,
                            ),
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Row(
                            children: [
                              OutlinedButton.icon(
                                icon: const Icon(Icons.camera_alt, size: 16),
                                label: const Text('Camera'),
                                onPressed: () => pickImage(ImageSource.camera),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                icon: const Icon(
                                  Icons.photo_library_outlined,
                                  size: 16,
                                ),
                                label: const Text('Gallery'),
                                onPressed: () => pickImage(ImageSource.gallery),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    CasamaButton(
                      label: 'Post to Housemates',
                      onPressed: () {
                        if (titleController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter an item title.'),
                            ),
                          );
                          return;
                        }

                        final fallbackImage = type == ItemType.lost
                            ? 'https://images.unsplash.com/photo-1600294037681-c80b4cb5b434?auto=format&fit=crop&w=300&q=80'
                            : (type == ItemType.found
                                  ? 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?auto=format&fit=crop&w=300&q=80'
                                  : 'https://images.unsplash.com/photo-1558317374-067fb5f30001?auto=format&fit=crop&w=300&q=80');

                        ref
                            .read(repositoryProvider)
                            .postItem(
                              type: type,
                              title: titleController.text.trim(),
                              description: descController.text.trim(),
                              imageUrl: selectedImageBase64 ?? fallbackImage,
                            );

                        Navigator.pop(context);

                        // Switch to the target tab
                        _tabController.animateTo(
                          type == ItemType.lost
                              ? 0
                              : (type == ItemType.found ? 1 : 2),
                        );

                        final categoryName = type == ItemType.lost
                            ? 'Lost'
                            : (type == ItemType.found ? 'Found' : 'Borrowed');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '$categoryName item posted successfully!',
                            ),
                            backgroundColor: CasamaColors.midnightNavy,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showItemDetailsSheet(
    BuildContext context,
    LostFoundItem item,
    CasamaRepository repo,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        String typeLabel = 'Lost Item';
        Color typeColor = CasamaColors.primaryCoral;
        if (item.type == ItemType.found) {
          typeLabel = 'Found Item';
          typeColor = const Color(0xFFF57F17);
        } else if (item.type == ItemType.shared) {
          typeLabel = 'Borrowed / Shared';
          typeColor = CasamaColors.homeGreen;
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.borderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Category pill & title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        typeLabel,
                        style: TextStyle(
                          color: typeColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Text(
                      '${DateTime.now().difference(item.createdAt).inHours}h ago',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textMutedColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: context.textColor,
                  ),
                ),
                const SizedBox(height: 12),

                // Image preview if present
                if (item.imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: item.imageUrl!.startsWith('data:image')
                        ? Image.memory(
                            base64Decode(item.imageUrl!.split(',').last),
                            width: double.infinity,
                            height: 180,
                            fit: BoxFit.cover,
                          )
                        : Image.network(
                            item.imageUrl!,
                            width: double.infinity,
                            height: 180,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              height: 100,
                              color: context.borderColor,
                              child: const Icon(Icons.broken_image, size: 40),
                            ),
                          ),
                  ),
                const SizedBox(height: 14),

                // Description
                Text(
                  'Details',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: context.textMutedColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description ?? 'No details provided.',
                  style: TextStyle(fontSize: 14, color: context.textColor),
                ),
                const SizedBox(height: 14),

                // Reported By
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: CasamaColors.primaryCoral,
                      child: Text(
                        item.reportedByName.isNotEmpty
                            ? item.reportedByName[0]
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reported by ${item.reportedByName}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.textColor,
                          ),
                        ),
                        Text(
                          'Casa 204 Housemate',
                          style: TextStyle(
                            fontSize: 11,
                            color: context.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Interactive Action Buttons
                if (item.type == ItemType.found &&
                    item.status == ItemStatus.unclaimed) ...[
                  CasamaButton(
                    label: 'Claim Item (This is Mine!)',
                    icon: Icons.check_circle_outline_rounded,
                    onPressed: () {
                      repo.claimItem(item.id);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Item marked as claimed! 🎉'),
                          backgroundColor: CasamaColors.homeGreen,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                ] else if (item.type == ItemType.shared) ...[
                  if (item.status == ItemStatus.open)
                    CasamaButton(
                      label: 'Borrow Item 🤝',
                      icon: Icons.handshake_outlined,
                      onPressed: () {
                        repo.borrowItem(item.id);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Item borrowed! Please return after use.',
                            ),
                            backgroundColor: CasamaColors.homeGreen,
                          ),
                        );
                      },
                    )
                  else if (item.status == ItemStatus.claimed)
                    CasamaButton(
                      label: 'Return Item ✅',
                      icon: Icons.assignment_return_outlined,
                      onPressed: () {
                        repo.returnItem(item.id);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Item returned! Thank you!'),
                            backgroundColor: CasamaColors.homeGreen,
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 10),
                ] else if (item.type == ItemType.lost &&
                    item.status == ItemStatus.open) ...[
                  CasamaButton(
                    label: 'Mark as Found / Recovered',
                    icon: Icons.check_rounded,
                    onPressed: () {
                      repo.claimItem(item.id);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Item marked as recovered! ✨'),
                          backgroundColor: CasamaColors.homeGreen,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                ],

                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    side: BorderSide(color: context.borderColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: CasamaColors.primaryCoral,
                  ),
                  label: Text(
                    'Message ${item.reportedByName}',
                    style: TextStyle(
                      color: context.textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.push(
                      '/direct-chat?contact=${item.reportedByName.toLowerCase()}&name=${Uri.encodeComponent(item.reportedByName)}',
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ItemCard extends StatelessWidget {
  final LostFoundItem item;

  const _ItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    ChipVariant chipVariant;
    String statusLabel;

    switch (item.status) {
      case ItemStatus.open:
        chipVariant = ChipVariant.open;
        statusLabel = item.type == ItemType.shared ? 'Available' : 'Open';
        break;
      case ItemStatus.unclaimed:
        chipVariant = ChipVariant.unclaimed;
        statusLabel = 'Unclaimed';
        break;
      case ItemStatus.claimed:
        chipVariant = ChipVariant.medium;
        statusLabel = item.type == ItemType.shared ? 'In Use' : 'Claimed';
        break;
      case ItemStatus.returned:
        chipVariant = ChipVariant.returned;
        statusLabel = 'Returned';
        break;
    }

    final repo = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(repositoryProvider);

    return Material(
      color: context.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: CasamaSpacing.roundedLg,
        side: BorderSide(color: context.borderColor),
      ),
      child: InkWell(
        borderRadius: CasamaSpacing.roundedLg,
        onTap: () {
          // Open interactive details bottom sheet
          final state = context
              .findAncestorStateOfType<_LostFoundScreenState>();
          if (state != null) {
            state._showItemDetailsSheet(context, item, repo);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Item Image Thumbnail
              ClipRRect(
                borderRadius: CasamaSpacing.roundedMd,
                child: Container(
                  width: 72,
                  height: 72,
                  color: context.isDark
                      ? CasamaColors.darkSurface
                      : CasamaColors.softNeutral,
                  child: item.imageUrl != null
                      ? (item.imageUrl!.startsWith('data:image')
                            ? Image.memory(
                                base64Decode(item.imageUrl!.split(',').last),
                                fit: BoxFit.cover,
                              )
                            : Image.network(
                                item.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Icon(
                                      Icons.image_outlined,
                                      color: context.textMutedColor,
                                      size: 32,
                                    ),
                              ))
                      : Icon(
                          Icons.image_outlined,
                          color: context.textMutedColor,
                          size: 32,
                        ),
                ),
              ),
              const SizedBox(width: 14),

              // Details Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.description ?? 'No details provided',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.textSecondaryColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${DateTime.now().difference(item.createdAt).inHours}h ago • by ${item.reportedByName}',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.textMutedColor,
                      ),
                    ),
                  ],
                ),
              ),

              // Status Badge
              StatusChip(label: statusLabel, variant: chipVariant),
            ],
          ),
        ),
      ),
    );
  }
}
