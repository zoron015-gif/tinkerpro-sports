import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'app_design_system.dart';
import 'app_localization.dart';
import 'app_text.dart';

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage>
    with WidgetsBindingObserver {
  MobileScannerController _scannerController = _createController();
  int _scannerKey = 0;
  bool _didScan = false;

  static MobileScannerController _createController() => MobileScannerController(
    autoStart: false,
    formats: const [BarcodeFormat.qrCode],
    facing: CameraFacing.back,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_startCamera(_scannerController));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_scannerController.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_scannerController.value.isRunning &&
          !_scannerController.value.isStarting &&
          _scannerController.value.error == null) {
        unawaited(_startCamera(_scannerController));
      }
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_scannerController.stop());
    }
  }

  Future<void> _startCamera(MobileScannerController controller) async {
    if (controller.value.isRunning || controller.value.isStarting) return;
    await controller.start(cameraDirection: CameraFacing.back);
  }

  Future<void> _retryCamera() async {
    final oldController = _scannerController;
    final newController = _createController();
    setState(() {
      _scannerController = newController;
      _scannerKey++;
    });
    await oldController.dispose();
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_startCamera(newController));
    });
  }

  void _onDetect(BarcodeCapture capture) {
    if (_didScan) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value == null || value.isEmpty) continue;

      _didScan = true;
      Navigator.of(context).pop(value);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('profile-qr-scanner-page'),
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const AppText(
          'Scan QR code',
          localize: true,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        foregroundColor: Colors.white,
        backgroundColor: const Color(0xFF111318),
        surfaceTintColor: Colors.transparent,
      ),
      body: ValueListenableBuilder<MobileScannerState>(
        valueListenable: _scannerController,
        builder: (context, state, _) => Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              key: ValueKey('qr-scanner-$_scannerKey'),
              controller: _scannerController,
              onDetect: _onDetect,
              placeholderBuilder: (_) => const _CameraStarting(),
              errorBuilder: (_, __) => const ColoredBox(color: Colors.black),
            ),
            if (state.error case final error?)
              _CameraError(error: error, onRetry: _retryCamera)
            else if (state.isRunning)
              const _ScannerGuide()
            else
              const _CameraStarting(),
          ],
        ),
      ),
    );
  }
}

class _CameraStarting extends StatelessWidget {
  const _CameraStarting();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFF101116),
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.orange),
            const SizedBox(height: AppSpacing.large),
            AppText(
              appLanguageText('Starting camera...', 'Starting camera...'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.small),
            AppText(
              appLanguageText(
                'Allow camera access if your phone asks.',
                'Allow camera access if your phone asks.',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.error, required this.onRetry});

  final MobileScannerException error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final permissionDenied =
        error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: const Color(0xFF101116),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.large),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                permissionDenied
                    ? Icons.no_photography_outlined
                    : Icons.camera_alt_outlined,
                color: Colors.white,
                size: 52,
              ),
              const SizedBox(height: AppSpacing.large),
              AppText(
                appLanguageText(
                  permissionDenied
                      ? 'Camera access is off'
                      : 'Camera could not start',
                  permissionDenied
                      ? 'Camera access is off'
                      : 'Camera could not start',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.small),
              AppText(
                appLanguageText(
                  permissionDenied
                      ? 'Allow TinkerPro to use the camera in your phone settings, '
                            'then try again.'
                      : 'Check that your camera is available and not being used '
                            'by another app, then try again.',
                  permissionDenied
                      ? 'Allow TinkerPro to use the camera in your phone settings, '
                            'then try again.'
                      : 'Check that your camera is available and not being used '
                            'by another app, then try again.',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, height: 1.4),
              ),
              const SizedBox(height: AppSpacing.small),
              AppText(
                error.errorCode.name,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: AppSpacing.large),
              FilledButton.icon(
                onPressed: () => unawaited(onRetry()),
                icon: const Icon(Icons.refresh_rounded),
                label: AppText(
                  appLanguageText('Try again', 'Try again'),
                  localize: true,
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: AppColors.onAccent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScannerGuide extends StatelessWidget {
  const _ScannerGuide();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth:
                    MediaQuery.sizeOf(context).width - AppSpacing.large * 2,
                maxHeight: MediaQuery.sizeOf(context).height * .48,
              ),
              child: AspectRatio(
                aspectRatio: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 3),
                    borderRadius: BorderRadius.circular(AppRadii.dialog),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.large),
            const AppText(
              'Place a venue QR code inside the frame',
              localize: true,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
