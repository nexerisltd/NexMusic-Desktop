part of 'library_cubit.dart';

@immutable
sealed class LibraryState {
  const LibraryState();
}

class LibraryLoading extends LibraryState {
  const LibraryLoading();
}

class LibraryLoaded extends LibraryState {
  final Map playlists;
  final int favouritesCount;
  final int downloadsCount;
  final int historyCount;
  final int localFilesCount;
  final List<Map<String, dynamic>> ytMusicPlaylists;

  const LibraryLoaded({
    required this.playlists,
    required this.favouritesCount,
    required this.downloadsCount,
    required this.historyCount,
    this.localFilesCount = 0,
    this.ytMusicPlaylists = const [],
  });
}

class LibraryError extends LibraryState {
  final String message;
  const LibraryError(this.message);
}
