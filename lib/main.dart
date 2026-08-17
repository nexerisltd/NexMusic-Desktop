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
import 'services/google_auth_service.dart';
import 'services/library.dart';
import 'services/local_media_service.dart';
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

  // Show something on screen immediately instead of leaving the user
  // staring at a blank window while every service below finishes its
  // (sequential, disk/network-bound) setup. Mirrors NexMusic-Android's
  // splash-while-preloading approach: paint fast, load in the background,
  // swap to the real app once ready.
  runApp(const _Bootstrap());
}

/// Shows [_SplashScreen] immediately, runs the exact same startup sequence
/// this app always has (unchanged below, just moved out of `main()`), then
/// swaps to the real [NexMusic] app once every service is ready.
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  SettingsManager? _settingsManager;
  MediaPlayer? _mediaPlayer;
  LibraryService? _libraryService;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
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
      // Bigger read-ahead buffer so brief CPU contention (heavy background
      // tasks, other apps under load) doesn't starve the audio decoder and
      // cause audible stutter — 8MB was cutting it close under load.
      JustAudioMediaKit.bufferSize = 32 * 1024 * 1024;
      JustAudioMediaKit.title = 'NexMusic';
      JustAudioMediaKit.prefetchPlaylist = true;
      JustAudioMediaKit.pitch = true;
    }

    String? visitorId = await Hive.box('SETTINGS').get('VISITOR_ID');

    YTMusic ytMusic = YTMusic(
      config: YTConfig(
          visitorData: visitorId ?? '', language: 'en', location: 'IN'),
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

    final GoogleAuthService googleAuthService = GoogleAuthService();
    await googleAuthService.init();
    GetIt.I.registerSingleton<GoogleAuthService>(googleAuthService);

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
    GetIt.I.registerSingleton<LocalMediaService>(LocalMediaService());

    if (!mounted) return;
    setState(() {
      _settingsManager = settingsManager;
      _mediaPlayer = mediaPlayer;
      _libraryService = libraryService;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_settingsManager == null ||
        _mediaPlayer == null ||
        _libraryService == null) {
      return const _SplashScreen();
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => _settingsManager!),
        ChangeNotifierProvider(create: (_) => _mediaPlayer!),
        ChangeNotifierProvider(create: (_) => _libraryService!),
      ],
      child: const NexMusic(),
    );
  }
}

/// Minimal, dependency-free loading screen shown while [_Bootstrap] runs
/// the app's startup sequence. Deliberately simple — no blur, no custom
/// animation controllers — so it paints on the very first frame with
/// nothing left to wait on.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image(
                image: AssetImage('icons/nexmusic_nobg.png'),
                width: 96,
                height: 96,
              ),
              SizedBox(height: 24),
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NexMusic extends StatefulWidget {
  const NexMusic({super.key});

  @override
  State<NexMusic> createState() => _NexMusicState();
}

class _NexMusicState extends State<NexMusic> {
  // CallbackShortcuts below only fires when some Focus node inside it has
  // primary focus. After certain interactions (a dialog closing, clicking
  // a non-focusable area) nothing ends up focused at all, and the
  // shortcuts silently stop working — this handler is a focus-independent
  // fallback for exactly that case, so Space/Ctrl+F/Ctrl+D always work on
  // the main window. It intentionally does nothing while something IS
  // focused (e.g. a search field), so normal typing isn't affected.
  bool _handleGlobalKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (FocusManager.instance.primaryFocus?.hasFocus == true) return false;

    final player = GetIt.I<MediaPlayer>().player;
    final ctrl = HardwareKeyboard.instance.isControlPressed;

    if (event.logicalKey == LogicalKeyboardKey.space) {
      player.playing ? player.pause() : player.play();
      return true;
    }
    if (ctrl && event.logicalKey == LogicalKeyboardKey.keyF) {
      player.seekToNext();
      return true;
    }
    if (ctrl && event.logicalKey == LogicalKeyboardKey.keyD) {
      player.seekToPrevious();
      return true;
    }
    if (ctrl && event.logicalKey == LogicalKeyboardKey.keyR) {
      GetIt.I<YTMusicAuthService>().silentlyRefreshSession();
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleGlobalKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalKey);
    super.dispose();
  }

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
        // Ctrl+R: renew the YT Music session (cookies) in the background —
        // useful when playback/browsing starts failing with "sign in to
        // confirm you're not a bot"-style errors from a stale session.
        const SingleActivator(LogicalKeyboardKey.keyR, control: true): () {
          GetIt.I<YTMusicAuthService>().silentlyRefreshSession();
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
  await Hive.openBox('LOCAL_MEDIA');
}
