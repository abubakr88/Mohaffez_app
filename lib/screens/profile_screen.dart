import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import 'pick_location_screen.dart';
import '../shared/widgets/profile_completion_indicator.dart';
import '../shared/widgets/verification_badge.dart';
import '../shared/widgets/cached_avatar.dart';
import '../shared/widgets/shimmer_widgets.dart';
import '../services/profile_completion_service.dart';
import '../config/image_cache_config.dart';
import 'mohaffez_credentials_screen.dart';
import 'availability_management_screen.dart';
import '../shared/widgets/error_widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool uploading = false;

  /// Pick and upload profile photo
  Future<void> pickAndUploadPhoto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        imageQuality: 80,
      );

      if (picked == null) return;

      setState(() {
        uploading = true;
      });

      final file = File(picked.path);
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('user_photos')
          .child('${user.uid}.jpg');

      await storageRef.putFile(file);
      final url = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'photoUrl': url});

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث الصورة بنجاح')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          uploading = false;
        });
      }
    }
  }

  /// Pick and save location (for Mohaffez)
  Future<void> pickAndSaveImamAddress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => const PickLocationScreen(),
      ),
    );

    if (result == null) return;

    final locationName = result['locationName'] as String? ?? '';
    final lat = result['lat'] as double?;
    final lng = result['lng'] as double?;

    if (lat == null || lng == null || locationName.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار موقع صحيح')),
      );
      return;
    }

    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'addressText': locationName,
      'addressLat': lat,
      'addressLng': lng,
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تحديث العنوان بنجاح')),
    );
  }

  /// Show cache management dialog
  Future<void> _showCacheDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.cleaning_services,
                color: Colors.orange.shade700,
              ),
              const SizedBox(width: 8),
              const Text('مسح الذاكرة المؤقتة'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'سيتم مسح جميع الصور المخزنة مؤقتاً على جهازك.',
                style: TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'سيتم تحميل الصور مرة أخرى عند الحاجة',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                // Show loading
                Navigator.pop(ctx);

                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (loadingCtx) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                );

                // Clear cache
                await ImageCacheConfig.clearCache();

                // Small delay for better UX
                await Future.delayed(const Duration(milliseconds: 500));

                if (context.mounted) {
                  Navigator.pop(context); // Close loading
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.white),
                          SizedBox(width: 8),
                          Text('تم مسح الذاكرة المؤقتة بنجاح'),
                        ],
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.delete_sweep),
              label: const Text('مسح الآن'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Center(child: Text('يرجى تسجيل الدخول')),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الملف الشخصي'),
        ),
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
              builder: (context, snapshot) {
                // Show error if any
                if (snapshot.hasError) {
                  return ErrorDisplay.dataLoad(
                    onRetry: () {
                      setState(() {}); // Trigger rebuild
                    },
                  );
                }

                // Show shimmer while loading
                if (!snapshot.hasData) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: ShimmerWidgets.base(
                      child: ShimmerWidgets.profile(),
                    ),
                  );
                }

            final data = snapshot.data!.data() ?? {};
            final name = data['name'] as String? ?? 'مستخدم';
            final email = data['email'] as String? ?? '';
            final role = data['role'] as String? ?? 'student';
            final photoUrl = data['photoUrl'] as String?;
            final followers = data['followerCount'] as int? ?? 0;
            final following = data['followingCount'] as int? ?? 0;
            final addressText = data['addressText'] as String? ?? '';
            final hasAddress = addressText.isNotEmpty;
            final isMohaffez = role == 'mohaffez';

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // ===== PROFILE PHOTO SECTION =====
                  GestureDetector(
                    onTap: uploading ? null : pickAndUploadPhoto,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        // Avatar with cached image
                        CachedAvatar(
                          imageUrl: photoUrl,
                          radius: 45,
                        ),

                        // Camera/upload indicator
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                            ),
                            child: uploading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.camera_alt,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ===== NAME AND EMAIL =====
                  Text(
                    name,
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),

                  Text(
                    email,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 4),

                  // ===== ROLE AND BADGES =====
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isMohaffez ? 'محفظ' : 'طالب',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 14,
                        ),
                      ),

                      // Show badges for Mohaffez
                      if (isMohaffez && data['badges'] != null) ...[
                        const SizedBox(width: 8),
                        VerificationBadgesRow(
                          badges: Map<String, bool>.from(
                            data['badges'] as Map,
                          ),
                          size: 18,
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ===== FOLLOWERS/FOLLOWING =====
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStatColumn('متابِعون', followers),
                      const SizedBox(width: 32),
                      _buildStatColumn('متابَعون', following),
                    ],
                  ),

                  // ===== PROFILE COMPLETION (MOHAFFEZ ONLY) =====
                  if (isMohaffez) ...[
                    const SizedBox(height: 24),
                    FutureBuilder<ProfileCompletionData>(
                      future: ProfileCompletionService.calculateCompletion(
                        user.uid,
                      ),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const SizedBox.shrink();
                        }

                        final completionData = snapshot.data!;
                        return ProfileCompletionIndicator(
                          percentage: completionData.percentage,
                          missingFields: completionData.missingFields,
                          onTap: () => _showCompletionDialog(
                            context,
                            completionData,
                          ),
                        );
                      },
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ===== MOHAFFEZ MANAGEMENT BUTTONS =====
                  if (isMohaffez) ...[
                    _buildManagementCard(
                      icon: Icons.workspace_premium,
                      title: 'الشهادات والإجازات',
                      subtitle: 'إدارة المؤهلات والشهادات',
                      color: Colors.blue,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MohaffezCredentialsScreen(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    _buildManagementCard(
                      icon: Icons.calendar_today,
                      title: 'الأوقات المتاحة',
                      subtitle: 'إدارة جدول المواعيد',
                      color: Colors.green,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const AvailabilityManagementScreen(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    _buildManagementCard(
                      icon: Icons.edit,
                      title: 'تعديل البيانات',
                      subtitle: 'تحديث الاسم والتخصص والسيرة',
                      color: Colors.orange,
                      onTap: () => _showUpdateBasicInfoDialog(
                        context,
                        user.uid,
                        data,
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],

                  // ===== PASSWORD RESET BUTTON =====
                  ElevatedButton.icon(
                    onPressed: () async {
                      if (email.isEmpty) return;

                      await FirebaseAuth.instance.sendPasswordResetEmail(
                        email: email,
                      );

                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم إرسال رابط إعادة تعيين كلمة المرور'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.lock_reset),
                    label: const Text('إعادة تعيين كلمة المرور'),
                  ),

                  const SizedBox(height: 12),

                  // ===== CACHE MANAGEMENT BUTTON =====
                  OutlinedButton.icon(
                    onPressed: () => _showCacheDialog(context),
                    icon: Icon(
                      Icons.cleaning_services,
                      color: Colors.orange.shade700,
                    ),
                    label: const Text('إدارة الذاكرة المؤقتة'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange.shade700,
                      side: BorderSide(color: Colors.orange.shade300),
                    ),
                  ),

                  // ===== ADDRESS SECTION (MOHAFFEZ ONLY) =====
                  if (isMohaffez) ...[
                    const SizedBox(height: 24),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'العنوان',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.location_on),
                        title: Text(
                          hasAddress ? addressText : 'لم يتم تحديد العنوان',
                        ),
                        trailing: TextButton.icon(
                          onPressed: pickAndSaveImamAddress,
                          icon: const Icon(Icons.edit_location_alt),
                          label: Text(hasAddress ? 'تعديل' : 'إضافة'),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Build stat column (followers/following)
  Widget _buildStatColumn(String label, int count) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        Text(
          count.toString(),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// Build management card for Mohaffez
  Widget _buildManagementCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show completion details dialog
  void _showCompletionDialog(
    BuildContext context,
    ProfileCompletionData completionData,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('اكتمال الملف الشخصي'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${completionData.percentage.toInt()}% مكتمل',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),
              if (completionData.missingFields.isNotEmpty) ...[
                const Text(
                  'الحقول المفقودة:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...completionData.missingFields.map((field) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.circle, size: 8),
                        const SizedBox(width: 8),
                        Text(field),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('حسناً'),
            ),
          ],
        ),
      ),
    );
  }

  /// Show update basic info dialog
  void _showUpdateBasicInfoDialog(
    BuildContext context,
    String userId,
    Map<String, dynamic> currentData,
  ) {
    final nameController = TextEditingController(
      text: currentData['name'] as String? ?? '',
    );
    final bioController = TextEditingController(
      text: currentData['bio'] as String? ?? '',
    );
    final specializationController = TextEditingController(
      text: currentData['specialization'] as String? ?? '',
    );

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تعديل البيانات'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'الاسم',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bioController,
                  decoration: const InputDecoration(
                    labelText: 'نبذة عنك',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: specializationController,
                  decoration: const InputDecoration(
                    labelText: 'التخصص',
                    hintText: 'مثال: متخصص في التجويد',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .update({
                    'name': nameController.text.trim(),
                    'bio': bioController.text.trim(),
                    'specialization': specializationController.text.trim(),
                  });

                  if (context.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم التحديث بنجاح')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('خطأ: $e')),
                    );
                  }
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}
