import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../../services/media_player.dart';
import '../../../../utils/adaptive_widgets/listtile.dart';

/// A song row for locally-scanned files. Deliberately separate from the
/// shared `LibraryTile`: that widget picks a thumbnail via
/// `thumbnails.where((el) => el['width'] >= 50)`, which assumes every
/// thumbnail entry has a `width` key. Local files have no embedded artwork
/// (see `LocalMediaService` for why), so their thumbnail entry is just
/// `{'url': ''}` — reusing `LibraryTile` as-is would throw on the missing
/// `width` key. A plain music-note icon is the honest representation here
/// instead of a network image call that would just fail anyway.
class LocalSongTile extends StatelessWidget {
  const LocalSongTile({required this.songs, required this.index, super.key});

  final List<Map> songs;
  final int index;

  String _buildSubtitle(Map song) {
    final parts = <String>[];
    final artists = song['artists'];
    if (artists is List && artists.isNotEmpty) {
      parts.add(artists.map((a) => a['name']).join(', '));
    }
    final albumName = song['album']?['name'];
    if (albumName != null && albumName.toString().isNotEmpty) {
      parts.add(albumName.toString());
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final song = songs[index];
    final scheme = Theme.of(context).colorScheme;

    return AdaptiveListTile(
      onTap: () async {
        await GetIt.I<MediaPlayer>().playAll(List<Map>.from(songs), index: index);
      },
      title: Text(
        song['title']?.toString() ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        _buildSubtitle(song),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Colors.grey.withAlpha(250)),
      ),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(Icons.music_note_rounded, color: scheme.onSurfaceVariant),
      ),
    );
  }
}
