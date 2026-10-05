import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kerosene/app/debug/device_gallery_frozen_scope.dart';
import 'package:kerosene/app/debug/device_ui_snapshot.dart';
import 'package:kerosene/core/providers/shared_preferences_provider.dart';
import 'package:kerosene/core/utils/snackbar_helper.dart';
import 'package:kerosene/design_system/foundation/theme/app_colors.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_screen.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_screens/wallet_setup_hub_screen.dart';
import 'package:kerosene/features/home/presentation/screens/home_screen.dart';
import 'package:kerosene/features/movement/presentation/hub/movement_hub_screen.dart';
import 'package:kerosene/features/notifications/presentation/screens/notification_center_screen.dart';
import 'package:kerosene/features/security/presentation/providers/security_provider.dart';
import 'package:kerosene/features/security/presentation/screens/notification_settings_screen.dart';
import 'package:kerosene/features/security/presentation/screens/security_totp_screen.dart';
import 'package:kerosene/features/security/presentation/screens/settings_backup_codes_screen.dart';
import 'package:kerosene/features/security/presentation/screens/settings_devices_screen.dart';
import 'package:kerosene/features/security/presentation/screens/settings_recovery_hub_screen.dart';
import 'package:kerosene/features/security/presentation/screens/settings_screen.dart';
import 'package:kerosene/features/security/presentation/screens/sovereignty_status_screen.dart';

/// One-tap: freeze session → paint full scrollable screens → PNG.
///
/// The capture canvas is **taller than the window** so CustomScrollView treats
/// the full document as the viewport (top of scroll → bottom of content).
class DeviceScreenGalleryExport {
  DeviceScreenGalleryExport._();

  static const double pixelRatio = 2.0;

  /// Logical height of the capture surface (full page, not just window).
  static const double fullPageHeight = 3600;

  static Future<DeviceGalleryExportResult> run({
    required BuildContext context,
    required WidgetRef ref,
    void Function(String status)? onStatus,
  }) async {
    void status(String m) {
      debugPrint('[device-gallery] $m');
      onStatus?.call(m);
    }

    final nav = SnackbarHelper.navigatorKey.currentState;
    if (nav == null) {
      throw StateError('Navigator indisponível — espere a Home e toque DADOS.');
    }

    status('Lendo sessão…');
    AppEntryPinSession.markUnlocked();
    final snapshot = DeviceUiSnapshot.captureFromRef(ref);
    status(
      '${snapshot.user.username}: '
      '${snapshot.wallets.length} wallets / '
      '${snapshot.transactions.length} txs',
    );

    final jsonFiles = await DeviceUiSnapshot.writeEverywhere(snapshot);
    final prefs = ref.read(sharedPreferencesProvider);

    final outDir = await _outputDir();
    await outDir.create(recursive: true);
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final runDir = Directory(p.join(outDir.path, 'screens_$stamp'));
    await runDir.create(recursive: true);
    final jsonBeside = File(p.join(runDir.path, kDeviceUiSnapshotFileName));
    await jsonBeside.writeAsString(
      await jsonFiles.first.readAsString(),
      flush: true,
    );

    final screens = <_GalleryScreen>[
      _GalleryScreen('01_home', const HomeScreen()),
      _GalleryScreen(
        '02_settings',
        const SettingsScreen(showPrimaryNavigation: true),
      ),
      _GalleryScreen('03_activity', const TransactionStatementScreen()),
      _GalleryScreen('04_receive', const MovementHubScreen()),
      _GalleryScreen('05_accounts', const BitcoinAccountsScreen()),
      _GalleryScreen('06_notifications', const NotificationCenterScreen()),
      _GalleryScreen('07_wallet_setup', const WalletSetupHubScreen()),
      _GalleryScreen('08_security_totp', const SecurityTotpScreen()),
      _GalleryScreen('09_recovery_hub', const SettingsRecoveryHubScreen()),
      _GalleryScreen('10_devices', const SettingsDevicesScreen()),
      _GalleryScreen('11_backup_codes', const SettingsBackupCodesScreen()),
      _GalleryScreen('12_sovereignty', const SovereigntyStatusScreen()),
      _GalleryScreen(
        '13_notification_settings',
        const NotificationSettingsScreen(),
      ),
    ];

    final controller = _GalleryCaptureController(
      screens: screens,
      snapshot: snapshot,
      prefs: prefs,
      runDir: runDir,
      onStatus: status,
    );

    status('Captura full-page (scroll inteiro)…');
    await nav.push<void>(
      PageRouteBuilder<void>(
        opaque: true,
        barrierDismissible: false,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) =>
            _GalleryCapturePage(controller: controller),
      ),
    );

    final pngs = await controller.done.future.timeout(
      const Duration(minutes: 3),
      onTimeout: () => <File>[],
    );

    if (pngs.isEmpty) {
      throw StateError('Nenhum PNG gerado — veja logs [device-gallery]');
    }

    status('OK ${pngs.length} arquivos em ${runDir.path}');
    return DeviceGalleryExportResult(
      directory: runDir,
      pngs: pngs,
      jsonFiles: [...jsonFiles, jsonBeside],
      snapshot: snapshot,
    );
  }

  static Future<Directory> _outputDir() async {
    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) {
        return Directory(p.join(downloads.path, kDeviceUiSnapshotDirName));
      }
    } catch (_) {}
    try {
      final docs = await getApplicationDocumentsDirectory();
      return Directory(p.join(docs.path, kDeviceUiSnapshotDirName));
    } catch (_) {}
    if (!kIsWeb && Platform.isAndroid) {
      for (final root in ['/sdcard/Download', '/storage/emulated/0/Download']) {
        final d = Directory(p.join(root, kDeviceUiSnapshotDirName));
        try {
          await d.create(recursive: true);
          return d;
        } catch (_) {}
      }
    }
    return Directory(
      p.join(Directory.systemTemp.path, kDeviceUiSnapshotDirName),
    );
  }
}

class _GalleryScreen {
  final String name;
  final Widget widget;
  const _GalleryScreen(this.name, this.widget);
}

class _GalleryCaptureController {
  final List<_GalleryScreen> screens;
  final DeviceUiSnapshot snapshot;
  final SharedPreferences prefs;
  final Directory runDir;
  final void Function(String status)? onStatus;
  final Completer<List<File>> done = Completer<List<File>>();

  _GalleryCaptureController({
    required this.screens,
    required this.snapshot,
    required this.prefs,
    required this.runDir,
    this.onStatus,
  });
}

class _GalleryCapturePage extends StatefulWidget {
  final _GalleryCaptureController controller;
  const _GalleryCapturePage({required this.controller});

  @override
  State<_GalleryCapturePage> createState() => _GalleryCapturePageState();
}

class _GalleryCapturePageState extends State<_GalleryCapturePage> {
  final GlobalKey _boundaryKey = GlobalKey(debugLabel: 'gallery_paint');
  int _index = 0;
  String _label = '…';
  bool _running = false;

  _GalleryCaptureController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runAll());
  }

  Future<void> _runAll() async {
    if (_running) return;
    _running = true;
    final pngs = <File>[];

    try {
      for (var i = 0; i < c.screens.length; i++) {
        if (!mounted) break;
        final item = c.screens[i];
        setState(() {
          _index = i;
          _label = item.name;
        });
        c.onStatus?.call('Pintando ${item.name} (página inteira)…');

        // Mount + layout tall canvas + first paints.
        await _pump(40);

        try {
          final file = await _shot(item.name);
          pngs.add(file);
          c.onStatus?.call(
            'Salvo ${file.uri.pathSegments.last} (${file.lengthSync()} bytes)',
          );
        } catch (e, st) {
          debugPrint('[device-gallery] ${item.name}: $e\n$st');
          c.onStatus?.call('Erro ${item.name}: $e');
        }
      }
    } finally {
      if (!c.done.isCompleted) c.done.complete(pngs);
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).pop();
        });
      }
    }
  }

  Future<void> _pump(int frames) async {
    for (var i = 0; i < frames; i++) {
      await SchedulerBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
  }

  Future<File> _shot(String name) async {
    final ctx = _boundaryKey.currentContext;
    if (ctx == null) throw StateError('boundary context null');

    final ro = ctx.findRenderObject();
    if (ro is! RenderRepaintBoundary) {
      throw StateError('not a RenderRepaintBoundary: $ro');
    }
    if (!ro.hasSize || ro.size.isEmpty) {
      throw StateError('boundary size empty: ${ro.hasSize ? ro.size : null}');
    }

    // Expect a tall page, not just the window height.
    final expectedMinH = DeviceScreenGalleryExport.fullPageHeight * 0.85;
    if (ro.size.height < expectedMinH) {
      debugPrint(
        '[device-gallery] WARN $name boundary height=${ro.size.height} '
        '(expected >= $expectedMinH) — may be viewport-only',
      );
    }

    for (var i = 0; i < 16 && ro.debugNeedsPaint; i++) {
      await SchedulerBinding.instance.endOfFrame;
    }

    ro.markNeedsPaint();
    await SchedulerBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 80));

    final image = await ro.toImage(
      pixelRatio: DeviceScreenGalleryExport.pixelRatio,
    );
    final w = image.width;
    final h = image.height;
    final bd = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bd == null) throw StateError('png encode null');

    final bytes = bd.buffer.asUint8List();
    final solid = bytes.length < 25000;
    if (solid) {
      debugPrint(
        '[device-gallery] WARN $name looks mostly black '
        '(${bytes.length} bytes, ${w}x$h)',
      );
    }

    final file = File(p.join(c.runDir.path, '$name.png'));
    await file.writeAsBytes(bytes, flush: true);
    debugPrint(
      '[device-gallery] ${file.path} ${bytes.length}b ${w}x$h '
      'logical=${ro.size.width.toStringAsFixed(0)}x'
      '${ro.size.height.toStringAsFixed(0)} solidBlack=$solid',
    );
    return file;
  }

  @override
  Widget build(BuildContext context) {
    final window = MediaQuery.sizeOf(context);
    // Phone-ish width for goldens; full page height for complete scroll content.
    final logicalW = math.min(window.width, 430.0);
    final pageH = DeviceScreenGalleryExport.fullPageHeight;
    final item = c.screens[_index.clamp(0, c.screens.length - 1)];

    // Critical layout rules:
    // 1) RepaintBoundary must wrap a child whose height is the FULL page.
    // 2) Must NOT sit inside Expanded that clips to the window height.
    // 3) SingleChildScrollView lets the tall layer exist on a real surface
    //    without clipping the RenderObject size of the boundary.
    return Material(
      color: AppColors.black,
      child: SingleChildScrollView(
        // Operator can scroll the tall canvas; capture uses full boundary size.
        physics: const ClampingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: double.infinity,
              color: AppColors.captureAction,
              padding: EdgeInsets.only(
                top: MediaQuery.paddingOf(context).top + 8,
                left: 12,
                right: 12,
                bottom: 8,
              ),
              child: Text(
                'DADOS ${_index + 1}/${c.screens.length} · $_label · '
                'full-page ${pageH.toInt()}px · '
                '${c.snapshot.wallets.length} wallets',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
            // Full-page capture surface (top of scroll → bottom of content).
            RepaintBoundary(
              key: _boundaryKey,
              child: ColoredBox(
                color: AppColors.black,
                child: SizedBox(
                  width: logicalW,
                  height: pageH,
                  child: buildFrozenGalleryApp(
                    snapshot: c.snapshot,
                    prefs: c.prefs,
                    width: logicalW,
                    height: pageH,
                    home: KeyedSubtree(
                      key: ValueKey<String>(item.name),
                      child: item.widget,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DeviceGalleryExportResult {
  final Directory directory;
  final List<File> pngs;
  final List<File> jsonFiles;
  final DeviceUiSnapshot snapshot;

  const DeviceGalleryExportResult({
    required this.directory,
    required this.pngs,
    required this.jsonFiles,
    required this.snapshot,
  });
}
