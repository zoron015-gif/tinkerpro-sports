import 'package:flutter/material.dart';
import 'app_preferences.dart';

Future<void> showProfileImagePreview(
  BuildContext context,
  ImageProvider<Object> image,
) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: true,
  barrierLabel: appLanguageText(
    'Close profile photo',
    'Isara ang larawan sa profile',
  ),
  barrierColor: Colors.black87,
  transitionDuration: const Duration(milliseconds: 180),
  pageBuilder: (dialogContext, animation, secondaryAnimation) => SafeArea(
    child: Stack(
      children: [
        Positioned.fill(
          child: Center(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Image(
                image: image,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: IconButton(
            tooltip: appLanguageText(
              'Close profile photo',
              'Isara ang larawan sa profile',
            ),
            onPressed: () => Navigator.of(dialogContext).pop(),
            icon: const Icon(Icons.close_rounded),
            color: Colors.white,
          ),
        ),
      ],
    ),
  ),
  transitionBuilder: (context, animation, secondaryAnimation, child) =>
      FadeTransition(opacity: animation, child: child),
);

class TappableProfileAvatar extends StatelessWidget {
  const TappableProfileAvatar({
    super.key,
    required this.radius,
    required this.backgroundColor,
    required this.image,
    required this.fallback,
  });

  final double radius;
  final Color backgroundColor;
  final ImageProvider<Object>? image;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final profileImage = image;
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      backgroundImage: profileImage,
      child: profileImage == null ? fallback : null,
    );
    if (profileImage == null) return avatar;

    return Semantics(
      button: true,
      label: appLanguageText(
        'View profile photo',
        'Tingnan ang larawan sa profile',
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => showProfileImagePreview(context, profileImage),
        child: avatar,
      ),
    );
  }
}
