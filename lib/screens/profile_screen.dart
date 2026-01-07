import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'pick_location_screen.dart';

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
              return const Center(child: CircularProgressIndicator());
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
                  Text(
                    name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(email),
                  Text(
                    isMohaffez ? 'محفظ' : 'طالب',
                  ),
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 24),
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
}
