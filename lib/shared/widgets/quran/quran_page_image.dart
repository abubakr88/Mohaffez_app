import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../models/quran_mistake_model.dart';
import '../../../services/quran_service.dart';
import 'quran_mistake_painter.dart';

class QuranPageImage extends StatelessWidget {
  final GlobalKey imageKey;
  final int currentPage;
  final Map<String, dynamic>? pageInfo;
  final List<QuranMistake> mistakes;
  final GestureTapDownCallback? onTapDown;

  const QuranPageImage({
    super.key,
    required this.imageKey,
    required this.currentPage,
    required this.pageInfo,
    required this.mistakes,
    required this.onTapDown,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: onTapDown,
      child: Stack(
        children: [
          Container(
            key: imageKey,
            color: const Color(0xFFF5F3E8),
            child: Center(
              child: CachedNetworkImage(
                imageUrl: QuranService().getPageImageUrl(currentPage),
                fit: BoxFit.contain,
                placeholder: (context, url) => Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text('تحميل صفحة $currentPage...'),
                  ],
                ),
                errorWidget: (context, url, error) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.menu_book, color: Colors.grey, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        'صفحة $currentPage',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'الجزء ${pageInfo?['juz'] ?? ''}',
                        style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'تأكد من الاتصال بالإنترنت',
                        style: TextStyle(color: Colors.red),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: QuranMistakePainter(mistakes: mistakes),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
