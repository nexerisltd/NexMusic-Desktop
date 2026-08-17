import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import '../../../../services/local_media_service.dart';

part 'local_media_state.dart';

class LocalMediaCubit extends Cubit<LocalMediaState> {
  final LocalMediaService _service = GetIt.I<LocalMediaService>();
  late final VoidCallback _listener;

  LocalMediaCubit() : super(const LocalMediaLoading()) {
    _listener = () {
      if (!isClosed) _emitState();
    };
    _service.addListener(_listener);
    _emitState();
  }

  void _emitState() {
    emit(
      LocalMediaLoaded(
        folders: _service.folders,
        songs: _service.songs,
        isScanning: _service.isScanning,
        scanError: _service.scanError,
      ),
    );
  }

  Future<void> addFolder(String path) => _service.addFolder(path);

  Future<void> removeFolder(String path) => _service.removeFolder(path);

  Future<void> rescan() => _service.rescan();

  @override
  Future<void> close() {
    _service.removeListener(_listener);
    return super.close();
  }
}
