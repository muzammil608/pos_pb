import 'dart:async';

import 'package:pocketbase/pocketbase.dart';

import '../core/services/pocketbase_service.dart';
import '../models/pos_header_slide_model.dart';

class PosHeaderService {
  static const String collectionName = 'pos_header_slides';

  final String ownerId;
  PocketBase? _pb;
  StreamController<List<PosHeaderSlide>>? _controller;
  Future<void> Function()? _unsubscribe;

  PosHeaderService(this.ownerId);

  Future<PocketBase> get _client async {
    _pb ??= await PocketBaseService.instance;
    return _pb!;
  }

  Stream<List<PosHeaderSlide>> get slidesStream {
    if (_controller == null || _controller!.isClosed) {
      _controller = StreamController<List<PosHeaderSlide>>.broadcast(
        onListen: _start,
        onCancel: _stop,
      );
    }
    return _controller!.stream;
  }

  Future<List<PosHeaderSlide>> getSlides() async {
    try {
      final pb = await _client;
      final records = await pb.collection(collectionName).getFullList(
            filter: 'ownerId = "$ownerId" && isActive = true',
            sort: 'sortOrder',
          );
      if (records.isEmpty) return PosHeaderSlide.defaults(ownerId);
      return records.map(PosHeaderSlide.fromRecord).toList();
    } catch (_) {
      return PosHeaderSlide.defaults(ownerId);
    }
  }

  Future<void> saveSlides(List<PosHeaderSlide> slides) async {
    final pb = await _client;
    for (var i = 0; i < slides.length; i++) {
      final slide = slides[i].copyWith(ownerId: ownerId, sortOrder: i);
      if (slide.id.isEmpty) {
        await pb.collection(collectionName).create(body: slide.toBody());
      } else {
        await pb.collection(collectionName).update(
              slide.id,
              body: slide.toBody(),
            );
      }
    }
    await refresh();
  }

  Future<void> refresh() async {
    if (_controller == null || _controller!.isClosed) return;
    _controller!.add(await getSlides());
  }

  Future<void> _start() async {
    try {
      final pb = await _client;
      await refresh();
      _unsubscribe = await pb.collection(collectionName).subscribe('*', (_) {
        refresh();
      });
    } catch (_) {
      if (!(_controller?.isClosed ?? true)) {
        _controller!.add(PosHeaderSlide.defaults(ownerId));
      }
    }
  }

  Future<void> _stop() async {
    try {
      await _unsubscribe?.call();
    } catch (_) {}
    _unsubscribe = null;
  }

  Future<void> dispose() async {
    await _stop();
    await _controller?.close();
    _controller = null;
  }
}
