import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:mohaffez_core/mohaffez_core.dart';
import 'quran_mistake_painter.dart';

class QuranPageImage extends StatefulWidget {
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
  State<QuranPageImage> createState() => _QuranPageImageState();
}

class _QuranPageImageState extends State<QuranPageImage> {
  int _retryToken = 0;

  @override
  void didUpdateWidget(covariant QuranPageImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPage != widget.currentPage) {
      _retryToken = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      hitTestBehavior: HitTestBehavior.translucent,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapDown: widget.onTapDown,
        child: Stack(
          children: [
            Container(
              key: widget.imageKey,
              color: const Color(0xFFF5F3E8),
              child: Center(child: _buildPageImage()),
            ),
            Positioned.fill(
              child: AbsorbPointer(
                absorbing: true,
                child: CustomPaint(
                  painter: QuranMistakePainter(mistakes: widget.mistakes),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageImage() {
    final imageUrl = QuranService().getPageImageUrl(widget.currentPage);

    if (kIsWeb) {
      return Image.network(
        imageUrl,
        key: ValueKey('quran-web-${widget.currentPage}-$_retryToken'),
        fit: BoxFit.contain,
        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _loadingWidget();
        },
        errorBuilder: (context, error, stackTrace) => _errorWidget(imageUrl),
      );
    }

    return CachedNetworkImage(
      key: ValueKey('quran-native-${widget.currentPage}-$_retryToken'),
      imageUrl: imageUrl,
      fit: BoxFit.contain,
      placeholder: (context, url) => _loadingWidget(),
      errorWidget: (context, url, error) => _errorWidget(imageUrl),
    );
  }

  Widget _loadingWidget() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text('تحميل صفحة ${widget.currentPage}...'),
      ],
    );
  }

  Future<void> _retry(String imageUrl) async {
    if (kIsWeb) {
      await NetworkImage(imageUrl).evict();
    } else {
      await CachedNetworkImage.evictFromCache(imageUrl);
    }
    if (!mounted) return;
    setState(() => _retryToken++);
  }

  Widget _errorWidget(String imageUrl) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.menu_book,
          color: AppThemeConstants.grey500,
          size: 64,
        ),
        const SizedBox(height: 16),
        Text(
          'صفحة ${widget.currentPage}',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'الجزء ${widget.pageInfo?['juz'] ?? ''}',
          style: const TextStyle(
            fontSize: 16,
            color: AppThemeConstants.grey600,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'تأكد من الاتصال بالإنترنت',
          style: TextStyle(color: AppThemeConstants.error),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _retry(imageUrl),
          icon: const Icon(Icons.refresh),
          label: const Text('إعادة المحاولة'),
        ),
      ],
    );
  }
}
