import 'dart:io';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get_it/get_it.dart';
import 'package:nexmusic/themes/theme.dart';
import 'package:nexmusic/ytmusic/modals/yt_config.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'generated/l10n.dart';
import 'services/download_manager.dart';
import 'services/file_storage.dart';
import 'services/library.dart';
import 'services/lyrics.dart';
import 'services/media_player.dart';
import 'services/settings_manager.dart';
import 'services/tray_service.dart';
import 'services/ytmusic_auth.dart';
import 'package:window_manager/window_manager.dart';
import 'utils/router.dart';
import 'ytmusic/ytmusic.dart';
import 'services/yt_audio_stream.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // NOTE: intentionally NOT checking WebViewEnvironment here anymore.
  // That check itself was quietly touching WebView2 on every single app
  // launch (even for users who never use YouTube Music sign-in), which
  // is what was making the whole app heavy and causing close-time lag.
  // WebView2 is now only ever touched when the user explicitly opens the
  // "Connect YouTube Music" page.

  await initialiseHive();

  // Initialize JustAudioBackground for notifications and background playback
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.nexapp.nexmusic.audio',
    androidNotificationChannelName: 'NexMusic',
    androidNotificationOngoing: true,
    androidShowNotificationBadge: true,
  );

  // Initialize JustAudioMediaKit for Windows, Linux, and macOS
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    JustAudioMediaKit.ensureInitialized();
    JustAudioMediaKit.bufferSize = 8 * 1024 * 1024;
    JustAudioMediaKit.title = 'NexMusic';
    JustAudioMediaKit.prefetchPlaylist = true;
    JustAudioMediaKit.pitch = true;
  }

  String? visitorId = await Hive.box('SETTINGS').get('VISITOR_ID');

  YTMusic ytMusic = YTMusic(
    config:
        YTConfig(visitorData: visitorId ?? '', language: 'en', location: 'IN'),
    onIdUpdate: (visitorId) async {
      await Hive.box('SETTINGS').put('VISITOR_ID', visitorId);
    },
  );

  final GlobalKey<NavigatorState> panelKey = GlobalKey<NavigatorState>();

  await FileStorage.initialise();
  FileStorage fileStorage = FileStorage();
  SettingsManager settingsManager = SettingsManager();

  GetIt.I.registerSingleton<SettingsManager>(settingsManager);

  final YTMusicAuthService ytMusicAuthService = YTMusicAuthService();
  await ytMusicAuthService.init();
  GetIt.I.registerSingleton<YTMusicAuthService>(ytMusicAuthService);

  // Set up system tray + close-to-tray window behavior (Windows/Linux only)
  final TrayService trayService = TrayService();
  await trayService.init();
  GetIt.I.registerSingleton<TrayService>(trayService);

  // Start Local Audio Server
  final String audioStreamUrl = await createAudioStreamServer();
  GetIt.I.registerSingleton<String>(audioStreamUrl,
      instanceName: 'audioStreamUrl');

  MediaPlayer mediaPlayer = MediaPlayer();
  GetIt.I.registerSingleton<MediaPlayer>(mediaPlayer);
  LibraryService libraryService = LibraryService();
  GetIt.I.registerSingleton<DownloadManager>(DownloadManager());
  GetIt.I.registerSingleton(panelKey);
  GetIt.I.registerSingleton<YTMusic>(ytMusic);

  GetIt.I.registerSingleton<FileStorage>(fileStorage);

  GetIt.I.registerSingleton<LibraryService>(libraryService);
  GetIt.I.registerSingleton<LyricsService>(LyricsService());

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => settingsManager),
        ChangeNotifierProvider(create: (_) => mediaPlayer),
        ChangeNotifierProvider(create: (_) => libraryService),
      ],
      child: const NexMusic(),
    ),
  );
}

class NexMusic extends StatelessWidget {
  const NexMusic({super.key});
  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        // Space: play/pause
        const SingleActivator(LogicalKeyboardKey.space): () {
          final player = GetIt.I<MediaPlayer>().player;
          player.playing ? player.pause() : player.play();
        },
        // Ctrl+F: next song
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
          GetIt.I<MediaPlayer>().player.seekToNext();
        },
        // Ctrl+D: previous song
        const SingleActivator(LogicalKeyboardKey.keyD, control: true): () {
          GetIt.I<MediaPlayer>().player.seekToPrevious();
        },
        // F11: toggle fullscreen (Windows/Linux/macOS only)
        const SingleActivator(LogicalKeyboardKey.f11): () {
          if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
            windowManager.isFullScreen().then((isFullScreen) {
              windowManager.setFullScreen(!isFullScreen);
            });
          }
        },
        // Esc: exit fullscreen if currently in fullscreen
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
            windowManager.isFullScreen().then((isFullScreen) {
              if (isFullScreen) windowManager.setFullScreen(false);
            });
          }
        },
      },
      child: Shortcuts(
        shortcuts: <LogicalKeySet, Intent>{
          LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
        },
        child: MaterialApp.router(
          title: 'NexMusic',
          routerConfig: router,
          locale: Locale(context.watch<SettingsManager>().language['value']!),
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
          debugShowCheckedModeBanner: false,
          themeMode: context.watch<SettingsManager>().themeMode,
          theme: AppTheme.light(
            primary: context.watch<SettingsManager>().accentColor,
          ),
          darkTheme: AppTheme.dark(
            primary: context.watch<SettingsManager>().accentColor,
            amoledBlack: context.watch<SettingsManager>().amoledBlack,
          ),
        ),
      ),
    );
  }
}

Future<void> initialiseHive() async {
  String? applicationDataDirectoryPath;
  if (Platform.isWindows || Platform.isLinux) {
    applicationDataDirectoryPath =
        "${(await getApplicationSupportDirectory()).path}/database";
  }
  await Hive.initFlutter(applicationDataDirectoryPath);
  await Hive.openBox('SETTINGS');
  await Hive.openBox('LIBRARY');
  await Hive.openBox('SEARCH_HISTORY');
  await Hive.openBox('SONG_HISTORY');
  await Hive.openBox('FAVOURITES');
  await Hive.openBox('DOWNLOADS');
}
