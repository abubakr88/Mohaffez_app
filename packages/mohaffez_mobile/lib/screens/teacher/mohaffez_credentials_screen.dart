// lib/screens/mohaffez_credentials_screen.dart
import 'package:flutter/material.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../shared/widgets/empty_state.dart';
import '../../services/credential_service.dart';
import 'dart:io';

class MohaffezCredentialsScreen extends StatefulWidget {
  const MohaffezCredentialsScreen({super.key});

  @override
  State<MohaffezCredentialsScreen> createState() =>
      _MohaffezCredentialsScreenState();
}

class _MohaffezCredentialsScreenState extends State<MohaffezCredentialsScreen> {
  final user = FirebaseAuth.instance.currentUser;

  void _showAddCredentialDialog() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddCredentialScreen()),
    );
  }

  Future<void> _deleteCredential(String credentialId) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف الشهادة'),
          content: const Text('هل أنت متأكد من حذف هذه الشهادة؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppThemeConstants.error),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      try {
        await CredentialService.deleteCredential(credentialId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف الشهادة')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل الحذف: $e')),
          );
        }
      }
    }
  }

  void _viewCredentialImages(List<String> imageUrls, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ImageGalleryScreen(
          imageUrls: imageUrls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('الرجاء تسجيل الدخول')),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            // Modern App Bar
            SliverAppBar(
              expandedHeight: 120,
              floating: true,
              pinned: true,
              automaticallyImplyLeading: false,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppThemeConstants.primary,
                        AppThemeConstants.primaryVariant,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppThemeConstants.surface.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.verified_user,
                                  size: 28,
                                  color: AppThemeConstants.onPrimary,
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'الشهادات والمؤهلات',
                                      style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                        color: AppThemeConstants.white,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'أضف شهاداتك لتوثيق حسابك',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: AppThemeConstants.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Credentials List
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user!.uid)
                  .collection('credentials')
                  .orderBy('uploadedAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return SliverToBoxAdapter(
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height - 200,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return SliverToBoxAdapter(
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height - 200,
                      child: EmptyState(
                        icon: Icons.workspace_premium,
                        title: 'لا توجد شهادات',
                        message: 'أضف شهاداتك لتعزيز مصداقيتك.',
                        animated: true,
                        action: ElevatedButton.icon(
                          onPressed: _showAddCredentialDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('إضافة شهادة'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppThemeConstants.accentPurple,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final doc = snapshot.data!.docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        return _CredentialCard(
                          credentialId: doc.id,
                          data: data,
                          onDelete: () => _deleteCredential(doc.id),
                          onImageTap: (imageUrls, initialIndex) =>
                              _viewCredentialImages(imageUrls, initialIndex),
                        );
                      },
                      childCount: snapshot.data!.docs.length,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddCredentialDialog,
          icon: const Icon(Icons.add),
          label: const Text('إضافة شهادة'),
          backgroundColor: AppThemeConstants.accentPurple,
        ),
      ),
    );
  }
}

// ============================================================================
// CREDENTIAL CARD WIDGET
// ============================================================================
class _CredentialCard extends StatelessWidget {
  final String credentialId;
  final Map<String, dynamic> data;
  final VoidCallback onDelete;
  final Function(List<String>, int) onImageTap;

  const _CredentialCard({
    required this.credentialId,
    required this.data,
    required this.onDelete,
    required this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = data['title'] as String? ?? 'بدون عنوان';
    final organization = data['organization'] as String? ?? 'بدون جهة';
    final type = data['type'] as String? ?? 'ijazah';
    final status =
        data['status'] as String? ?? 'approved'; // ✅ Default approved
    final issueDate = (data['issueDate'] as Timestamp?)?.toDate();
    final imageUrls =
        List<String>.from(data['imageUrls'] ?? []); // ✅ Can be empty

    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);
    final statusLabel = _getStatusLabel(status);
    final typeColor = _getTypeColor(type);
    final typeIcon = _getTypeIcon(type);
    final typeLabel = _getTypeLabel(type);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: statusColor.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(typeIcon, color: typeColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        organization,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppThemeConstants.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor, width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 6),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: typeColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(typeIcon, size: 16, color: typeColor),
                      const SizedBox(width: 6),
                      Text(
                        typeLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: typeColor,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Issue Date
                if (issueDate != null)
                  Row(
                    children: [
                      const Icon(Icons.date_range,
                          size: 16, color: AppThemeConstants.grey600),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('yyyy/MM/dd').format(issueDate),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppThemeConstants.grey600,
                        ),
                      ),
                    ],
                  ),

                // ✅ UPDATED: Images - show only if available
                if (imageUrls.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: imageUrls.length,
                      itemBuilder: (context, index) {
                        return InkWell(
                          onTap: () => onImageTap(imageUrls, index),
                          borderRadius: BorderRadius.circular(12),
                          child: Hero(
                            tag: '${credentialId}_$index',
                            child: Container(
                              width: 100,
                              margin: const EdgeInsets.only(left: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppThemeConstants.grey300,
                                  width: 2,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: CachedNetworkImage(
                                  imageUrl: imageUrls[index],
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: AppThemeConstants.grey200,
                                    child: const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      const Icon(Icons.broken_image),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ] else ...[
                  // ✅ NEW: Show message when no images
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppThemeConstants.grey100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 18, color: AppThemeConstants.grey600),
                        SizedBox(width: 8),
                        Text(
                          'لا توجد صور مرفقة',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppThemeConstants.grey600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Rejection Reason (if any)
                if (status == 'rejected' &&
                    data['rejectionReason'] != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppThemeConstants.error.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppThemeConstants.error.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: AppThemeConstants.error,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'سبب الرفض:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppThemeConstants.error,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          data['rejectionReason'],
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppThemeConstants.errorDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Delete Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete, size: 18),
                    label: const Text('حذف الشهادة'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppThemeConstants.error,
                      side: const BorderSide(color: AppThemeConstants.error),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return AppThemeConstants.success;
      case 'rejected':
        return AppThemeConstants.error;
      default:
        return AppThemeConstants.warning;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.pending;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'مُعتمدة';
      case 'rejected':
        return 'مرفوضة';
      default:
        return 'قيد المراجعة';
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'ijazah':
        return AppThemeConstants.accentPurple;
      case 'education':
        return AppThemeConstants.accentBlue;
      case 'license':
        return AppThemeConstants.success;
      case 'award':
        return AppThemeConstants.accentAmber;
      default:
        return AppThemeConstants.grey500;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'ijazah':
        return Icons.book;
      case 'education':
        return Icons.school;
      case 'license':
        return Icons.card_membership;
      case 'award':
        return Icons.emoji_events;
      default:
        return Icons.description;
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'ijazah':
        return 'إجازة';
      case 'education':
        return 'مؤهل تعليمي';
      case 'license':
        return 'ترخيص';
      case 'award':
        return 'جائزة';
      default:
        return 'شهادة';
    }
  }
}

// ============================================================================
// IMAGE GALLERY SCREEN
// ============================================================================
class ImageGalleryScreen extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const ImageGalleryScreen({
    super.key,
    required this.imageUrls,
    required this.initialIndex,
  });

  @override
  State<ImageGalleryScreen> createState() => _ImageGalleryScreenState();
}

class _ImageGalleryScreenState extends State<ImageGalleryScreen> {
  late PageController _pageController;
  late int currentIndex;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeConstants.black,
      appBar: AppBar(
        leading: context.canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios),
                onPressed: () => context.pop(),
                tooltip: 'رجوع',
              )
            : null,
        backgroundColor: AppThemeConstants.black,
        iconTheme: const IconThemeData(color: AppThemeConstants.white),
        title: Text(
          '${currentIndex + 1} / ${widget.imageUrls.length}',
          style: const TextStyle(color: AppThemeConstants.white),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.imageUrls.length,
        onPageChanged: (index) {
          setState(() => currentIndex = index);
        },
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: CachedNetworkImage(
                imageUrl: widget.imageUrls[index],
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(color: AppThemeConstants.white),
                ),
                errorWidget: (context, url, error) => const Icon(
                  Icons.broken_image,
                  color: AppThemeConstants.white,
                  size: 64,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// ADD CREDENTIAL SCREEN
// ============================================================================
class AddCredentialScreen extends StatefulWidget {
  const AddCredentialScreen({super.key});

  @override
  State<AddCredentialScreen> createState() => _AddCredentialScreenState();
}

class _AddCredentialScreenState extends State<AddCredentialScreen> {
  final _formKey = GlobalKey<FormState>();
  final titleController = TextEditingController();
  final organizationController = TextEditingController();
  String selectedType = 'ijazah';
  DateTime? issueDate;
  List<String> selectedImagePaths = [];
  bool uploading = false;

  @override
  void dispose() {
    titleController.dispose();
    organizationController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final images = await CredentialService.pickImages(maxImages: 3);
      setState(() {
        selectedImagePaths = images.map((img) => img.path).toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _submitCredential() async {
    if (!_formKey.currentState!.validate()) return;

    if (issueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار تاريخ الإصدار')),
      );
      return;
    }

    // ✅ REMOVED: Image validation - now optional
    // if (selectedImagePaths.isEmpty) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     const SnackBar(content: Text('يرجى إضافة صورة واحدة على الأقل')),
    //   );
    //   return;
    // }

    setState(() => uploading = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;

      // ✅ Upload images only if selected
      List<String> imageUrls = [];
      if (selectedImagePaths.isNotEmpty) {
        final images = selectedImagePaths.map((path) => XFile(path)).toList();
        imageUrls = await CredentialService.uploadCredentialImages(
          images,
          user.uid,
        );
      }

      // Add credential
      await CredentialService.addCredential(
        type: selectedType,
        title: titleController.text.trim(),
        organization: organizationController.text.trim(),
        issueDate: issueDate!,
        imageUrls: imageUrls,
      );

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تمت إضافة الشهادة بنجاح ✅'),
            backgroundColor: AppThemeConstants.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشلت الإضافة: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => uploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          leading: context.canPop()
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios),
                  onPressed: () => context.pop(),
                  tooltip: 'رجوع',
                )
              : null,
          title: const Text('إضافة شهادة'),
          backgroundColor: AppThemeConstants.primary,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type selection
                const Text(
                  'نوع الشهادة',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('إجازة'),
                      selected: selectedType == 'ijazah',
                      onSelected: (_) =>
                          setState(() => selectedType = 'ijazah'),
                    ),
                    ChoiceChip(
                      label: const Text('مؤهل تعليمي'),
                      selected: selectedType == 'education',
                      onSelected: (_) =>
                          setState(() => selectedType = 'education'),
                    ),
                    ChoiceChip(
                      label: const Text('ترخيص'),
                      selected: selectedType == 'license',
                      onSelected: (_) =>
                          setState(() => selectedType = 'license'),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Title
                TextFormField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'اسم الشهادة',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'يرجى إدخال اسم الشهادة' : null,
                ),

                const SizedBox(height: 16),

                // Organization
                TextFormField(
                  controller: organizationController,
                  decoration: const InputDecoration(
                    labelText: 'الجهة المانحة',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value?.isEmpty ?? true
                      ? 'يرجى إدخال الجهة المانحة'
                      : null,
                ),

                const SizedBox(height: 16),

                // Issue Date
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('تاريخ الإصدار'),
                  subtitle: Text(
                    issueDate != null
                        ? DateFormat('yyyy/MM/dd').format(issueDate!)
                        : 'اختر التاريخ',
                  ),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(1950),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => issueDate = date);
                    }
                  },
                ),

                const SizedBox(height: 24),

                // ✅ UPDATED: Images - now optional
                const Text(
                  'صور الشهادة (اختياري)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                if (selectedImagePaths.isEmpty)
                  GestureDetector(
                    onTap: _pickImages,
                    child: Container(
                      height: 150,
                      decoration: BoxDecoration(
                        color: AppThemeConstants.grey100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppThemeConstants.grey300,
                          width: 2,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate,
                                size: 48, color: AppThemeConstants.grey500),
                            SizedBox(height: 8),
                            Text('اضغط لإضافة صور (اختياري)'),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Column(
                    children: [
                      SizedBox(
                        height: 150,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: selectedImagePaths.length,
                          itemBuilder: (context, index) {
                            return Container(
                              width: 150,
                              margin: const EdgeInsets.only(left: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppThemeConstants.grey300),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  File(selectedImagePaths[index]),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: _pickImages,
                        icon: const Icon(Icons.add),
                        label: const Text('إضافة المزيد من الصور'),
                      ),
                    ],
                  ),

                const SizedBox(height: 32),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: uploading ? null : _submitCredential,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppThemeConstants.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: uploading
                        ? const CircularProgressIndicator(color: AppThemeConstants.white)
                        : const Text(
                            'إضافة الشهادة',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
