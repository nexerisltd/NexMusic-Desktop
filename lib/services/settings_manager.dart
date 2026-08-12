import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../ytmusic/ytmusic.dart';

Box _box = Hive.box('SETTINGS');

class SettingsManager extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  final List<ThemeMode> _themeModes = [
    ThemeMode.system,
    ThemeMode.light,
    ThemeMode.dark
  ];
  late Map<String, String> _location;
  late Map<String, String> _language;
  bool _autofetchSongs = true;
  final List<AudioQuality> _audioQualities = [
    AudioQuality.high,
    AudioQuality.low
  ];

  AudioQuality _streamingQuality = AudioQuality.high;
  AudioQuality _downloadQuality = AudioQuality.high;
  bool _skipSilence = false;
  bool _closeToTray = false;
  bool _minimizeToTray = false;
  bool _persistentShuffle = false;
  bool _rememberShuffleAndRepeat = false;
  bool _preventDuplicateTracks = false;
  int _restoredLoopMode = 0; // 0=off, 1=all, 2=one (LoopMode index)
  bool _restoredShuffle = false;
  double _lyricsTextSize = 24;
  double _lyricsLineSpacing = 1.4;
  bool _autoScrollLyrics = true;
  double _thumbnailCornerRadius = 12;
  bool _hidePlayerThumbnail = false;
  // 0 = Animated Gradient, 1 = Solid Color, 2 = Liquid Glass
  int _playerBackgroundStyle = 0;
  Color? _accentColor;
  bool _amoledBlack = true;
  bool _dynamicColors = false;
  bool _equalizerEnabled = false;
  List<double> _equalizerBandsGain = [];
  bool _loudnessEnabled = false;
  double _loudnessTargetGain = 0.0;

  ThemeMode get themeMode => _themeMode;
  List<ThemeMode> get themeModes => _themeModes;
  Map<String, String> get location => _location;
  List<Map<String, String>> get locations => _countries;
  Map<String, String> get language => _language;
  bool get autofetchSongs => _autofetchSongs;
  List<Map<String, String>> get languages => _languages;
  List<AudioQuality> get audioQualities => _audioQualities;
  AudioQuality get streamingQuality => _streamingQuality;
  AudioQuality get downloadQuality => _downloadQuality;
  bool get skipSilence => _skipSilence;
  bool get closeToTray => _closeToTray;
  bool get minimizeToTray => _minimizeToTray;
  bool get persistentShuffle => _persistentShuffle;
  bool get rememberShuffleAndRepeat => _rememberShuffleAndRepeat;
  bool get preventDuplicateTracks => _preventDuplicateTracks;
  int get restoredLoopMode => _restoredLoopMode;
  bool get restoredShuffle => _restoredShuffle;
  double get lyricsTextSize => _lyricsTextSize;
  double get lyricsLineSpacing => _lyricsLineSpacing;
  bool get autoScrollLyrics => _autoScrollLyrics;
  double get thumbnailCornerRadius => _thumbnailCornerRadius;
  bool get hidePlayerThumbnail => _hidePlayerThumbnail;
  int get playerBackgroundStyle => _playerBackgroundStyle;

  Color? get accentColor => _accentColor;
  bool get amoledBlack => _amoledBlack;
  bool get dynamicColors => _dynamicColors;
  bool get equalizerEnabled => _equalizerEnabled;
  List<double> get equalizerBandsGain => _equalizerBandsGain;
  bool get loudnessEnabled => _loudnessEnabled;
  double get loudnessTargetGain => _loudnessTargetGain;

  Map get settings => _box.toMap();
  SettingsManager() {
    _init();
  }
  _init() {
    _themeMode = _themeModes[_box.get('THEME_MODE', defaultValue: 0)];
    _language = _languages.firstWhere((language) =>
        language['value'] == _box.get('LANGUAGE', defaultValue: 'en-IN'));
    _autofetchSongs = _box.get('AUTOFETCH_SONGS', defaultValue: true);
    _accentColor = _box.get('ACCENT_COLOR') != null
        ? Color(_box.get('ACCENT_COLOR'))
        : null;
    _amoledBlack = _box.get('AMOLED_BLACK', defaultValue: true);
    _dynamicColors = _box.get('DYNAMIC_COLORS', defaultValue: false);

    _location = _countries.firstWhere((country) =>
        country['value'] == _box.get('LOCATION', defaultValue: 'IN'));

    _streamingQuality =
        _audioQualities[_box.get('STREAMING_QUALITY', defaultValue: 0)];
    _downloadQuality =
        _audioQualities[_box.get('DOWNLOAD_QUALITY', defaultValue: 0)];
    _skipSilence = _box.get('SKIP_SILENCE', defaultValue: false);
    _closeToTray = _box.get('CLOSE_TO_TRAY', defaultValue: false);
    _minimizeToTray = _box.get('MINIMIZE_TO_TRAY', defaultValue: false);
    _persistentShuffle = _box.get('PERSISTENT_SHUFFLE', defaultValue: false);
    _rememberShuffleAndRepeat =
        _box.get('REMEMBER_SHUFFLE_REPEAT', defaultValue: false);
    _preventDuplicateTracks =
        _box.get('PREVENT_DUPLICATE_TRACKS', defaultValue: false);
    _restoredLoopMode = _box.get('RESTORED_LOOP_MODE', defaultValue: 0);
    _restoredShuffle = _box.get('RESTORED_SHUFFLE', defaultValue: false);
    _lyricsTextSize = _box.get('LYRICS_TEXT_SIZE', defaultValue: 24.0);
    _lyricsLineSpacing = _box.get('LYRICS_LINE_SPACING', defaultValue: 1.4);
    _autoScrollLyrics = _box.get('AUTO_SCROLL_LYRICS', defaultValue: true);
    _thumbnailCornerRadius =
        _box.get('THUMBNAIL_CORNER_RADIUS', defaultValue: 12.0);
    _hidePlayerThumbnail =
        _box.get('HIDE_PLAYER_THUMBNAIL', defaultValue: false);
    _playerBackgroundStyle =
        _box.get('PLAYER_BACKGROUND_STYLE', defaultValue: 0);
    _equalizerEnabled = _box.get('EQUALIZER_ENABLED', defaultValue: false);
    _loudnessEnabled = _box.get('LOUDNESS_ENABLED', defaultValue: false);
    _loudnessTargetGain = _box.get('LOUDNESS_TARGET_GAIN', defaultValue: 0.0);
    _equalizerBandsGain =
        _box.get('EQUALIZER_BANDS_GAIN', defaultValue: []).cast<double>();
  }

  setThemeMode(ThemeMode mode) async {
    _box.put('THEME_MODE', _themeModes.indexOf(mode));
    _themeMode = mode;

    notifyListeners();
  }

  set location(Map<String, String> value) {
    _box.put('LOCATION', value['value']);
    _location = value;
    GetIt.I<YTMusic>().refreshContext();
    notifyListeners();
  }

  set language(Map<String, String> value) {
    _box.put('LANGUAGE', value['value']);
    _language = value;
    GetIt.I<YTMusic>().refreshContext();
    notifyListeners();
  }

  set autofetchSongs(bool value) {
    _box.put('AUTOFETCH_SONGS', value);
    _autofetchSongs = value;
    notifyListeners();
  }

  set streamingQuality(AudioQuality value) {
    _box.put('STREAMING_QUALITY', _audioQualities.indexOf(value));
    _streamingQuality = value;
    notifyListeners();
  }

  set downloadQuality(AudioQuality value) {
    _box.put('DOWNLOAD_QUALITY', _audioQualities.indexOf(value));
    _downloadQuality = value;
    notifyListeners();
  }

  set skipSilence(bool value) {
    _box.put('SKIP_SILENCE', value);
    _skipSilence = value;
    notifyListeners();
  }

  set closeToTray(bool value) {
    _box.put('CLOSE_TO_TRAY', value);
    _closeToTray = value;
    notifyListeners();
  }

  set minimizeToTray(bool value) {
    _box.put('MINIMIZE_TO_TRAY', value);
    _minimizeToTray = value;
    notifyListeners();
  }

  set persistentShuffle(bool value) {
    _box.put('PERSISTENT_SHUFFLE', value);
    _persistentShuffle = value;
    notifyListeners();
  }

  set rememberShuffleAndRepeat(bool value) {
    _box.put('REMEMBER_SHUFFLE_REPEAT', value);
    _rememberShuffleAndRepeat = value;
    notifyListeners();
  }

  set preventDuplicateTracks(bool value) {
    _box.put('PREVENT_DUPLICATE_TRACKS', value);
    _preventDuplicateTracks = value;
    notifyListeners();
  }

  // Used internally by MediaPlayer to persist current shuffle/loop mode
  // when "Remember shuffle and repeat" is enabled. Not exposed as a
  // user-facing toggle.
  set restoredLoopMode(int value) {
    _box.put('RESTORED_LOOP_MODE', value);
    _restoredLoopMode = value;
  }

  set restoredShuffle(bool value) {
    _box.put('RESTORED_SHUFFLE', value);
    _restoredShuffle = value;
  }

  set lyricsTextSize(double value) {
    _box.put('LYRICS_TEXT_SIZE', value);
    _lyricsTextSize = value;
    notifyListeners();
  }

  set lyricsLineSpacing(double value) {
    _box.put('LYRICS_LINE_SPACING', value);
    _lyricsLineSpacing = value;
    notifyListeners();
  }

  set autoScrollLyrics(bool value) {
    _box.put('AUTO_SCROLL_LYRICS', value);
    _autoScrollLyrics = value;
    notifyListeners();
  }

  set thumbnailCornerRadius(double value) {
    _box.put('THUMBNAIL_CORNER_RADIUS', value);
    _thumbnailCornerRadius = value;
    notifyListeners();
  }

  set hidePlayerThumbnail(bool value) {
    _box.put('HIDE_PLAYER_THUMBNAIL', value);
    _hidePlayerThumbnail = value;
    notifyListeners();
  }

  set playerBackgroundStyle(int value) {
    _box.put('PLAYER_BACKGROUND_STYLE', value);
    _playerBackgroundStyle = value;
    notifyListeners();
  }

  set accentColor(Color? color) {
    int? c = color?.value;
    _box.put('ACCENT_COLOR', c);
    _accentColor = color;
    notifyListeners();
  }

  set amoledBlack(bool val) {
    _box.put('AMOLED_BLACK', val);
    _amoledBlack = val;
    notifyListeners();
  }

  set dynamicColors(bool isMaterial) {
    _box.put('DYNAMIC_COLORS', isMaterial);
    _dynamicColors = isMaterial;
    notifyListeners();
  }

  set equalizerEnabled(bool enabled) {
    _box.put('EQUALIZER_ENABLED', enabled);
    _equalizerEnabled = enabled;
    notifyListeners();
  }

  set equalizerBandsGain(List<double>? value) {
    if (value != null) {
      _box.put('EQUALIZER_BANDS_GAIN', value);
      _equalizerBandsGain = value;
      notifyListeners();
    }
  }

  Future<void> setEqualizerBandsGain(int index, double value) async {
    _equalizerBandsGain[index] = value;
    await _box.put('EQUALIZER_BANDS_GAIN', equalizerBandsGain);
    notifyListeners();
  }

  set loudnessEnabled(enabled) {
    _box.put('LOUDNESS_ENABLED', enabled);
    _loudnessEnabled = enabled;
    notifyListeners();
  }

  set loudnessTargetGain(double value) {
    _box.put('LOUDNESS_TARGET_GAIN', value);
    _loudnessTargetGain = value;
    notifyListeners();
  }

  Future<void> setSettings(Map value) async {
    await Future.forEach(value.entries, (entry) async {
      await _box.put(entry.key, entry.value);
    });
    notifyListeners();
    _init();
  }
}

bool getDarkness(int themeMode) {
  if (themeMode == 0) {
    return MediaQueryData.fromView(
                    WidgetsBinding.instance.platformDispatcher.views.first)
                .platformBrightness ==
            Brightness.dark
        ? true
        : false;
  } else if (themeMode == 2) {
    return true;
  }
  return false;
}

enum AudioQuality { high, low }

List<Map<String, String>> _countries = [
  {"name": "Algeria", "value": "DZ"},
  {"name": "Argentina", "value": "AR"},
  {"name": "Australia", "value": "AU"},
  {"name": "Austria", "value": "AT"},
  {"name": "Azerbaijan", "value": "AZ"},
  {"name": "Bahrain", "value": "BH"},
  {"name": "Bangladesh", "value": "BD"},
  {"name": "Belarus", "value": "BY"},
  {"name": "Belgium", "value": "BE"},
  {"name": "Bolivia", "value": "BO"},
  {"name": "Bosnia and Herzegovina", "value": "BA"},
  {"name": "Brazil", "value": "BR"},
  {"name": "Bulgaria", "value": "BG"},
  {"name": "Cambodia", "value": "KH"},
  {"name": "Canada", "value": "CA"},
  {"name": "Chile", "value": "CL"},
  {"name": "Colombia", "value": "CO"},
  {"name": "Costa Rica", "value": "CR"},
  {"name": "Croatia", "value": "HR"},
  {"name": "Cyprus", "value": "CY"},
  {"name": "Czechia", "value": "CZ"},
  {"name": "Denmark", "value": "DK"},
  {"name": "Dominican Republic", "value": "DO"},
  {"name": "Ecuador", "value": "EC"},
  {"name": "Egypt", "value": "EG"},
  {"name": "El Salvador", "value": "SV"},
  {"name": "Estonia", "value": "EE"},
  {"name": "Finland", "value": "FI"},
  {"name": "France", "value": "FR"},
  {"name": "Georgia", "value": "GE"},
  {"name": "Germany", "value": "DE"},
  {"name": "Ghana", "value": "GH"},
  {"name": "Greece", "value": "GR"},
  {"name": "Guatemala", "value": "GT"},
  {"name": "Honduras", "value": "HN"},
  {"name": "Hong Kong", "value": "HK"},
  {"name": "Hungary", "value": "HU"},
  {"name": "Iceland", "value": "IS"},
  {"name": "India", "value": "IN"},
  {"name": "Indonesia", "value": "ID"},
  {"name": "Iraq", "value": "IQ"},
  {"name": "Ireland", "value": "IE"},
  {"name": "Israel", "value": "IL"},
  {"name": "Italy", "value": "IT"},
  {"name": "Jamaica", "value": "JM"},
  {"name": "Japan", "value": "JP"},
  {"name": "Jordan", "value": "JO"},
  {"name": "Kazakhstan", "value": "KZ"},
  {"name": "Kenya", "value": "KE"},
  {"name": "Kuwait", "value": "KW"},
  {"name": "Laos", "value": "LA"},
  {"name": "Latvia", "value": "LV"},
  {"name": "Lebanon", "value": "LB"},
  {"name": "Libya", "value": "LY"},
  {"name": "Liechtenstein", "value": "LI"},
  {"name": "Lithuania", "value": "LT"},
  {"name": "Luxembourg", "value": "LU"},
  {"name": "Malaysia", "value": "MY"},
  {"name": "Malta", "value": "MT"},
  {"name": "Mexico", "value": "MX"},
  {"name": "Moldova", "value": "MD"},
  {"name": "Montenegro", "value": "ME"},
  {"name": "Morocco", "value": "MA"},
  {"name": "Nepal", "value": "NP"},
  {"name": "Netherlands", "value": "NL"},
  {"name": "New Zealand", "value": "NZ"},
  {"name": "Nicaragua", "value": "NI"},
  {"name": "Nigeria", "value": "NG"},
  {"name": "North Macedonia", "value": "MK"},
  {"name": "Norway", "value": "NO"},
  {"name": "Oman", "value": "OM"},
  {"name": "Pakistan", "value": "PK"},
  {"name": "Panama", "value": "PA"},
  {"name": "Papua New Guinea", "value": "PG"},
  {"name": "Paraguay", "value": "PY"},
  {"name": "Peru", "value": "PE"},
  {"name": "Philippines", "value": "PH"},
  {"name": "Poland", "value": "PL"},
  {"name": "Portugal", "value": "PT"},
  {"name": "Puerto Rico", "value": "PR"},
  {"name": "Qatar", "value": "QA"},
  {"name": "Romania", "value": "RO"},
  {"name": "Russia", "value": "RU"},
  {"name": "Saudi Arabia", "value": "SA"},
  {"name": "Senegal", "value": "SN"},
  {"name": "Serbia", "value": "RS"},
  {"name": "Singapore", "value": "SG"},
  {"name": "Slovakia", "value": "SK"},
  {"name": "Slovenia", "value": "SI"},
  {"name": "South Africa", "value": "ZA"},
  {"name": "South Korea", "value": "KR"},
  {"name": "Spain", "value": "ES"},
  {"name": "Sri Lanka", "value": "LK"},
  {"name": "Sweden", "value": "SE"},
  {"name": "Switzerland", "value": "CH"},
  {"name": "Taiwan", "value": "TW"},
  {"name": "Tanzania", "value": "TZ"},
  {"name": "Thailand", "value": "TH"},
  {"name": "Tunisia", "value": "TN"},
  {"name": "Turkey", "value": "TR"},
  {"name": "Uganda", "value": "UG"},
  {"name": "Ukraine", "value": "UA"},
  {"name": "United Arab Emirates", "value": "AE"},
  {"name": "United Kingdom", "value": "GB"},
  {"name": "United States", "value": "US"},
  {"name": "Uruguay", "value": "UY"},
  {"name": "Venezuela", "value": "VE"},
  {"name": "Vietnam", "value": "VN"},
  {"name": "Yemen", "value": "YE"},
  {"name": "Zimbabwe", "value": "ZW"}
];

List<Map<String, String>> _languages = [
  {"name": "Afrikaans", "value": "af"},
  {"name": "Azərbaycan", "value": "az"},
  {"name": "Bahasa Indonesia", "value": "id"},
  {"name": "Bahasa Malaysia", "value": "ms"},
  {"name": "Bosanski", "value": "bs"},
  {"name": "Català", "value": "ca"},
  {"name": "Čeština", "value": "cs"},
  {"name": "Dansk", "value": "da"},
  {"name": "Deutsch", "value": "de"},
  {"name": "Eesti", "value": "et"},
  {"name": "English (India)", "value": "en-IN"},
  {"name": "English (UK)", "value": "en-GB"},
  {"name": "English (US)", "value": "en"},
  {"name": "Español (España)", "value": "es"},
  {"name": "Español (Latinoamérica)", "value": "es-419"},
  {"name": "Español (US)", "value": "es-US"},
  {"name": "Euskara", "value": "eu"},
  {"name": "Filipino", "value": "fil"},
  {"name": "Français", "value": "fr"},
  {"name": "Français (Canada)", "value": "fr-CA"},
  {"name": "Galego", "value": "gl"},
  {"name": "Hrvatski", "value": "hr"},
  {"name": "IsiZulu", "value": "zu"},
  {"name": "Íslenska", "value": "is"},
  {"name": "Italiano", "value": "it"},
  {"name": "Kiswahili", "value": "sw"},
  {"name": "Latviešu valoda", "value": "lv"},
  {"name": "Lietuvių", "value": "lt"},
  {"name": "Magyar", "value": "hu"},
  {"name": "Nederlands", "value": "nl"},
  {"name": "Norsk", "value": "no"},
  {"name": "O‘zbek", "value": "uz"},
  {"name": "Polski", "value": "pl"},
  {"name": "Português", "value": "pt-PT"},
  {"name": "Português (Brasil)", "value": "pt"},
  {"name": "Română", "value": "ro"},
  {"name": "Shqip", "value": "sq"},
  {"name": "Slovenčina", "value": "sk"},
  {"name": "Slovenščina", "value": "sl"},
  {"name": "Srpski", "value": "sr-Latn"},
  {"name": "Suomi", "value": "fi"},
  {"name": "Svenska", "value": "sv"},
  {"name": "Tiếng Việt", "value": "vi"},
  {"name": "Türkçe", "value": "tr"},
  {"name": "Беларуская", "value": "be"},
  {"name": "Български", "value": "bg"},
  {"name": "Кыргызча", "value": "ky"},
  {"name": "Қазақ Тілі", "value": "kk"},
  {"name": "Македонски", "value": "mk"},
  {"name": "Монгол", "value": "mn"},
  {"name": "Русский", "value": "ru"},
  {"name": "Српски", "value": "sr"},
  {"name": "Українська", "value": "uk"},
  {"name": "Ελληνικά", "value": "el"},
  {"name": "Հայերեն", "value": "hy"},
  {"name": "עברית", "value": "iw"},
  {"name": "اردو", "value": "ur"},
  {"name": "العربية", "value": "ar"},
  {"name": "فارسی", "value": "fa"},
  {"name": "नेपाली", "value": "ne"},
  {"name": "मराठी", "value": "mr"},
  {"name": "हिन्दी", "value": "hi"},
  {"name": "অসমীয়া", "value": "as"},
  {"name": "বাংলা", "value": "bn"},
  {"name": "ਪੰਜਾਬੀ", "value": "pa"},
  {"name": "ગુજરાતી", "value": "gu"},
  {"name": "ଓଡ଼ିଆ", "value": "or"},
  {"name": "தமிழ்", "value": "ta"},
  {"name": "తెలుగు", "value": "te"},
  {"name": "ಕನ್ನಡ", "value": "kn"},
  {"name": "മലയാളം", "value": "ml"},
  {"name": "සිංහල", "value": "si"},
  {"name": "ภาษาไทย", "value": "th"},
  {"name": "ລາວ", "value": "lo"},
  {"name": "ဗမာ", "value": "my"},
  {"name": "ქართული", "value": "ka"},
  {"name": "አማርኛ", "value": "am"},
  {"name": "ខ្មែរ", "value": "km"},
  {"name": "中文 (简体)", "value": "zh-CN"},
  {"name": "中文 (繁體)", "value": "zh-TW"},
  {"name": "中文 (香港)", "value": "zh-HK"},
  {"name": "日本語", "value": "ja"},
  {"name": "한국어", "value": "ko"}
];
