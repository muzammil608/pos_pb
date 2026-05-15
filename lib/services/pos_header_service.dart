import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';

import '../core/services/pocketbase_service.dart';
import '../models/pos_header_slide_model.dart';

class PosHeaderService {
  static const String collectionName = 'pos_header_slides';
  static const String userFieldName = 'posHeaderSlides';

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
      final collectionSlides = await _getSlidesFromCollection();
      if (collectionSlides.isNotEmpty) return collectionSlides;
    } catch (_) {}

    try {
      final storedSlides = await _getSlidesFromUserField();
      if (storedSlides != null && storedSlides.isNotEmpty) return storedSlides;
    } catch (_) {}

    return PosHeaderSlide.defaults(ownerId);
  }

  Future<List<PosHeaderSlide>> getAllSlidesForEditing() async {
    try {
      final pb = await _client;
      final records = await pb.collection(collectionName).getFullList(
            filter: 'ownerId = "$ownerId"',
            sort: 'sortOrder',
          );
      if (records.isNotEmpty) {
        return records.map(PosHeaderSlide.fromRecord).toList();
      }
    } catch (_) {}

    try {
      final storedSlides = await _getSlidesFromUserField();
      if (storedSlides != null && storedSlides.isNotEmpty) return storedSlides;
    } catch (_) {}

    return PosHeaderSlide.defaults(ownerId);
  }

  Future<void> saveSlides(List<PosHeaderSlide> slides) async {
    final normalized = [
      for (var i = 0; i < slides.length; i++)
        slides[i].copyWith(ownerId: ownerId, sortOrder: i),
    ];

    final savedToCollection = await _saveSlidesToCollection(normalized);
    if (!savedToCollection) {
      throw StateError(
        'Unable to save POS header slides to the collection. '
        'Check your PocketBase connection and collection permissions.',
      );
    }

    await _saveSlidesToUserField(normalized);

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

      _unsubscribe = await pb.collection(collectionName).subscribe('*', (e) {
        final recordOwnerId = e.record?.getStringValue('ownerId') ?? '';
        if (recordOwnerId.isEmpty || recordOwnerId == ownerId) {
          refresh();
        }
      });
    } catch (_) {
      try {
        final pb = await _client;
        _unsubscribe = await pb.collection('users').subscribe(ownerId, (_) {
          refresh();
        });
      } catch (_) {
        if (!(_controller?.isClosed ?? true)) {
          _controller!.add(PosHeaderSlide.defaults(ownerId));
        }
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

  Future<List<PosHeaderSlide>> _getSlidesFromCollection() async {
    final pb = await _client;
    final records = await pb.collection(collectionName).getFullList(
          filter: 'ownerId = "$ownerId" && isActive = true',
          sort: 'sortOrder',
        );
    return records.map(PosHeaderSlide.fromRecord).toList();
  }

  Future<List<PosHeaderSlide>?> _getSlidesFromUserField() async {
    try {
      final pb = await _client;
      final user = await pb.collection('users').getOne(ownerId);
      final rawSlides = user.data[userFieldName];
      if (rawSlides == null) return null;
      if (rawSlides is! List) return const [];

      final slides = rawSlides
          .map((item) => item is Map<String, dynamic>
              ? PosHeaderSlide.fromMap(item)
              : PosHeaderSlide.fromMap(
                  Map<String, dynamic>.from(item as Map),
                ))
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      return slides;
    } catch (_) {
      return null;
    }
  }

  Future<bool> _saveSlidesToUserField(List<PosHeaderSlide> slides) async {
    try {
      final pb = await _client;
      await pb.collection('users').update(ownerId, body: {
        userFieldName: slides.map((slide) => slide.toBody()).toList(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _saveSlidesToCollection(List<PosHeaderSlide> slides) async {
    try {
      final pb = await _client;

      final existingRecords = await pb.collection(collectionName).getFullList(
            filter: 'ownerId = "$ownerId"',
            sort: 'sortOrder',
          );

      final List<String> savedIds = [];
      for (var i = 0; i < slides.length; i++) {
        final collectionSortOrder = i + 1;
        final slide = slides[i].copyWith(sortOrder: collectionSortOrder);
        final body = {
          ...slide.toBody(),
          'sortOrder': collectionSortOrder,
        };

        if (slide.id.isEmpty) {
          debugPrint('📦 Creating slide with body: $body');
          final created =
              await pb.collection(collectionName).create(body: body);
          savedIds.add(created.id);
        } else {
          await pb.collection(collectionName).update(slide.id, body: body);
          savedIds.add(slide.id);
        }
      }

      final retainedIds = savedIds.toSet();
      for (final record in existingRecords) {
        if (!retainedIds.contains(record.id)) {
          await pb.collection(collectionName).delete(record.id);
        }
      }

      return true;
    } catch (e) {
      debugPrint('❌ _saveSlidesToCollection failed: $e');
      return false;
    }
  }
}
