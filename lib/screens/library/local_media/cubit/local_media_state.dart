part of 'local_media_cubit.dart';

@immutable
sealed class LocalMediaState {
  const LocalMediaState();
}

class LocalMediaLoading extends LocalMediaState {
  const LocalMediaLoading();
}

class LocalMediaLoaded extends LocalMediaState {
  final List<String> folders;
  final List<Map> songs;
  final bool isScanning;
  final String? scanError;

  const LocalMediaLoaded({
    required this.folders,
    required this.songs,
    required this.isScanning,
    required this.scanError,
  });
}
