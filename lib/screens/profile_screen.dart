import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import 'pick_location_screen.dart';
import '../shared/widgets/profile_completion_indicator.dart';
import '../services/profile_completion_service.dart';
import '../shared/widgets/verification_badge.dart';
import 'mohaffez_credentials_screen.dart';
import 'availability_management_screen.dart';
import '../shared/widgets/shimmer_widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  bool uploading = false;

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
        const SnackBar(content: Text('تم تحديث الصورة الشخصية بنجاح')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء رفع الصورة: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          uploading = false;
        });
      }
    }
  }

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
        const SnackBar(content: Text('يجب اختيار عنوان صالح')),
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
      const SnackBar(content: Text('تم حفظ عنوان المحفظ بنجاح')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Center(child: Text('الرجاء تسجيل الدخول أولاً')),
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
            if (!snapshot.hasData) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ShimmerWidgets.base(
                  child: ShimmerWidgets.profile(),
                ),
              );
            }

            final data = snapshot.data!.data() ?? {};
            final name = data['name'] as String? ?? '';
            final email = data['email'] as String? ?? '';
            final role = data['role'] as String? ?? '';
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
                  // Profile photo section
                  GestureDetector(
                    onTap: uploading ? null : pickAndUploadPhoto,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 45,
                          backgroundImage:
                              photoUrl != null ? NetworkImage(photoUrl) : null,
                          child: photoUrl == null
                              ? const Icon(Icons.person, size: 40)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.black54,
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

                  // Name and role
                  Text(
                    name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(email),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isMohaffez ? 'محفظ' : 'طالب',
                      ),
                      // NEW: Show badges for Mohaffez
                      if (isMohaffez && data['badges'] != null) ...[
                        const SizedBox(width: 8),
                        VerificationBadgesRow(
                          badges: Map<String, bool>.from(data['badges'] as Map),
                          size: 18,
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Followers/Following
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Column(
                        children: [
                          const Text('المتابِعون'),
                          Text(followers.toString()),
                        ],
                      ),
                      const SizedBox(width: 32),
                      Column(
                        children: [
                          const Text('المتابَعون'),
                          Text(following.toString()),
                        ],
                      ),
                    ],
                  ),

                  // NEW: Profile completion indicator for Mohaffez
                  if (isMohaffez) ...[
                    const SizedBox(height: 24),
                    FutureBuilder<ProfileCompletionData>(
                      future:
                          ProfileCompletionService.calculateCompletion(user.uid),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const SizedBox.shrink();
                        }

                        final completionData = snapshot.data!;
                        return ProfileCompletionIndicator(
                          percentage: completionData.percentage,
                          missingFields: completionData.missingFields,
                          onTap: () {
                            // Show dialog with missing fields
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
                                        'نسبة الاكتمال: ${completionData.percentage.toInt()}%',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 12),
                                      if (completionData
                                          .missingFields.isNotEmpty) ...[
                                        const Text(
                                          'العناصر المفقودة:',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 8),
                                        ...completionData.missingFields
                                            .map((field) {
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 4),
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
                          },
                        );
                      },
                    ),
                  ],

                  const SizedBox(height: 24),

                  // NEW: Mohaffez management buttons
                  if (isMohaffez) ...[
                    _buildManagementCard(
                      icon: Icons.workspace_premium,
                      title: 'الشهادات والمؤهلات',
                      subtitle: 'إدارة شهاداتك ومؤهلاتك',
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
                      title: 'إدارة المواعيد',
                      subtitle: 'تحديد الأوقات المتاحة للحجز',
                      color: Colors.green,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AvailabilityManagementScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildManagementCard(
                      icon: Icons.edit,
                      title: 'تحديث البيانات الأساسية',
                      subtitle: 'تحديث الاسم، النبذة، والتخصص',
                      color: Colors.orange,
                      onTap: () {
                        _showUpdateBasicInfoDialog(context, user.uid, data);
                      },
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Password reset button
                  ElevatedButton.icon(
                    onPressed: () async {
                      if (email.isEmpty) return;
                      await FirebaseAuth.instance
                          .sendPasswordResetEmail(email: email);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'تم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك الإلكتروني',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.lock_reset),
                    label: const Text('إعادة تعيين كلمة المرور'),
                  ),

                  const SizedBox(height: 24),

                  // Address section for Mohaffez
                  if (isMohaffez) ...[
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'عنوان المحفظ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.location_on),
                        title: Text(
                          hasAddress ? addressText : 'لم يتم تسجيل العنوان بعد',
                        ),
                        trailing: TextButton.icon(
                          onPressed: pickAndSaveImamAddress,
                          icon: const Icon(Icons.edit_location_alt),
                          label: Text(
                            hasAddress ? 'تعديل العنوان' : 'تسجيل العنوان',
                          ),
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
          title: const Text('تحديث البيانات الأساسية'),
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
                    labelText: 'نبذة تعريفية',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: specializationController,
                  decoration: const InputDecoration(
                    labelText: 'التخصص',
                    hintText: 'مثال: تحفيظ القرآن الكريم',
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
                      SnackBar(content: Text('حدث خطأ: $e')),
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
