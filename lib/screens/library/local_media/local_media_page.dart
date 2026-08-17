import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../generated/l10n.dart';
import '../../../utils/adaptive_widgets/adaptive_widgets.dart';
import 'cubit/local_media_cubit.dart';
import 'widgets/local_song_tile.dart';

class LocalMediaPage extends StatelessWidget {
  const LocalMediaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LocalMediaCubit(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Local Files'),
          centerTitle: true,
        ),
        body: BlocBuilder<LocalMediaCubit, LocalMediaState>(
          builder: (context, state) {
            return switch (state) {
              LocalMediaLoading() =>
                const Center(child: AdaptiveProgressRing()),
              LocalMediaLoaded() => _LocalMediaBody(state: state),
            };
          },
        ),
      ),
    );
  }
}

class _LocalMediaBody extends StatelessWidget {
  const _LocalMediaBody({required this.state});

  final LocalMediaLoaded state;

  Future<void> _addFolder(BuildContext context) async {
    final path = await FilePicker.platform.getDirectoryPath();

    if (path != null && context.mounted) {
      context.read<LocalMediaCubit>().addFolder(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1000),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Watched folders',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (state.isScanning)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else
                      IconButton(
                        tooltip: 'Rescan',
                        icon: const Icon(Icons.refresh_rounded),
                        onPressed: state.folders.isEmpty
                            ? null
                            : () => context.read<LocalMediaCubit>().rescan(),
                      ),
                    IconButton(
                      tooltip: 'Add folder',
                      icon: const Icon(Icons.create_new_folder_outlined),
                      onPressed: () => _addFolder(context),
                    ),
                  ],
                ),
              ),

              if (state.scanError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    state.scanError!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),

              if (state.folders.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'Add a folder to scan for local audio files.',
                      style: TextStyle(color: Colors.grey.withAlpha(220)),
                    ),
                  ),
                )
              else
                ...state.folders.map(
                  (folder) => AdaptiveListTile(
                    dense: true,
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(folder, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () =>
                          context.read<LocalMediaCubit>().removeFolder(folder),
                    ),
                  ),
                ),

              const SizedBox(height: 12),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  S.of(context).nSongs(state.songs.length),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),

              const SizedBox(height: 4),

              if (state.songs.isEmpty && state.folders.isNotEmpty && !state.isScanning)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No supported audio files found in the watched folders.',
                      style: TextStyle(color: Colors.grey.withAlpha(220)),
                    ),
                  ),
                )
              else
                Column(
                  children: List.generate(
                    state.songs.length,
                    (index) => LocalSongTile(
                      songs: state.songs,
                      index: index,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
