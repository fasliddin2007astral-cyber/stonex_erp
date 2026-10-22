import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/api_client.dart';

void showMessage(BuildContext context, String text, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: error ? AppColors.danger : AppColors.darkCard,
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: error ? Colors.white : AppColors.neonLime,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.darkCard,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Qayta urinish'),
              ),
            ],
          ),
        ),
      );
}

/// Mahsulot rasmi yoki rasmi yo'q bo'lsa zamonaviy default mahsulot belgisi
class ProductThumbnail extends StatelessWidget {
  const ProductThumbnail({
    super.key,
    this.imageUrl,
    required this.name,
    this.size = 42,
    this.width,
    this.height,
    this.borderRadius = 12,
    this.borderRadiusGeometry,
    this.fit = BoxFit.cover,
  });

  final String? imageUrl;
  final String name;
  final double size;
  final double? width;
  final double? height;
  final double borderRadius;
  final BorderRadiusGeometry? borderRadiusGeometry;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final w = width ?? size;
    final h = height ?? size;
    final r = borderRadiusGeometry ?? BorderRadius.circular(borderRadius);

    Widget fallbackAvatar() => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: context.isDark ? const Color(0xFF1E2822) : AppColors.neonLimeSoft,
            borderRadius: r,
            border: Border.all(
              color: context.borderColor,
              width: 0.8,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.inventory_2_outlined,
            color: context.isDark ? AppColors.neonLime : AppColors.ink,
            size: (w < h ? w : h) * 0.45,
          ),
        );

    final raw = imageUrl?.trim() ?? '';
    if (raw.isEmpty) {
      return fallbackAvatar();
    }

    Widget imageWidget;
    try {
      if (raw.startsWith('data:image/') || raw.contains(';base64,')) {
        // Base64 Data URI
        final comma = raw.indexOf(',');
        final b64 = comma != -1 ? raw.substring(comma + 1).trim() : raw;
        final bytes = base64Decode(b64);
        imageWidget = Image.memory(
          Uint8List.fromList(bytes),
          width: w,
          height: h,
          fit: fit,
          errorBuilder: (_, __, ___) => fallbackAvatar(),
        );
      } else if (!raw.startsWith('http://') &&
          !raw.startsWith('https://') &&
          !raw.startsWith('/') &&
          File(raw).existsSync()) {
        // Mahalliy kompyuter / telefon fayl yo'li
        imageWidget = Image.file(
          File(raw),
          width: w,
          height: h,
          fit: fit,
          errorBuilder: (_, __, ___) => fallbackAvatar(),
        );
      } else {
        // Server URL
        final resolvedUrl = ApiClient.resolveUrl(raw);
        imageWidget = Image.network(
          resolvedUrl,
          width: w,
          height: h,
          fit: fit,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
          errorBuilder: (_, __, ___) => fallbackAvatar(),
        );
      }
    } catch (_) {
      return fallbackAvatar();
    }

    return ClipRRect(
      borderRadius: r,
      child: Container(
        width: w,
        height: h,
        color: context.isDark ? const Color(0xFF1E2822) : const Color(0xFFF1F5F9),
        child: imageWidget,
      ),
    );
  }
}

/// Mahsulot rasmini to'liq va katta hajmda ko'rish oynasi
void showProductImagePreview(
  BuildContext context, {
  required String? imageUrl,
  required String name,
  String? subtitle,
}) {
  if (imageUrl == null || imageUrl.trim().isEmpty) return;
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        decoration: BoxDecoration(
          color: ctx.cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(color: Color(0x55000000), blurRadius: 28, offset: Offset(0, 10)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                ProductThumbnail(
                  imageUrl: imageUrl,
                  name: name,
                  width: double.infinity,
                  height: 320,
                  fit: BoxFit.contain,
                  borderRadiusGeometry: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: const CircleBorder(),
                    child: IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                      tooltip: 'Yopish',
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: ctx.inkColor,
                    ),
                  ),
                  if (subtitle != null && subtitle.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 13, color: AppColors.muted, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class NotImplementedView extends StatelessWidget {
  const NotImplementedView({super.key, required this.title, required this.note});
  final String title;
  final String note;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: context.isDark ? AppColors.neonLime.withValues(alpha: 0.15) : AppColors.darkCard.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.videocam_outlined, size: 36, color: context.isDark ? AppColors.neonLime : AppColors.ink),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: context.inkColor),
              ),
              const SizedBox(height: 8),
              Text(
                'Bu modul keyingi bosqichda ulanadi.\n$note',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
      );
}
