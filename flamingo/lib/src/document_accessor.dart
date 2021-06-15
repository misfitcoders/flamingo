import 'dart:async';

import '../flamingo.dart';

abstract class DocumentAccessorRepository {
  Future save(Document document);
  Future<Increment<T>> increment<T extends num>(
    Increment<T> entity,
    DocumentReference reference, {
    num value,
    required String fieldName,
  });
  Future update(Document document);
  Future delete(Document document);
  Future<T?> load<T extends Document<T>>(
    Document document, {
    Source source = Source.serverAndCache,
    Function(T?)? fromCache,
  });
  Future<T?> loadCache<T extends Document<T>>(Document document);
  Future<T?> loadCacheOnly<T extends Document<T>>(Document document);
  Future saveRaw(
    Map<String, dynamic> values,
    DocumentReference reference, {
    bool isTimestamp = false,
    String createdFieldValueKey = documentCreatedAtKey,
    String updatedFieldValueKey = documentUpdatedAtKey,
  });
  Future updateRaw(
    Map<String, dynamic> values,
    DocumentReference reference, {
    bool isTimestamp = false,
    String updatedFieldValueKey = documentUpdatedAtKey,
  });
  Future deleteWithReference(DocumentReference reference);
}

class DocumentAccessor implements DocumentAccessorRepository {
  @override
  Future save(Document document) async {
    final batch = Batch()..save(document);
    await batch.commit();
  }

  @override
  Future<Increment<T>> increment<T extends num>(
    Increment<T> entity,
    DocumentReference reference, {
    num value = 1,
    required String fieldName,
    bool? isClear,
  }) async {
    var updateValue = value;
    if (isClear != null && isClear) {
      updateValue = (T.toString() == 'double') ? 0.0 as T : 0 as T;
    }
    final batch = Batch()
      ..updateRaw(
        entity.toData(updateValue, fieldName: fieldName, isClear: isClear),
        reference,
        isTimestamp: true,
      );
    await batch.commit();
    return Increment(value: updateValue as T, incrementValue: null);
  }

  @override
  Future update(Document document) async {
    final batch = Batch()..update(document);
    await batch.commit();
  }

  @override
  Future delete(Document document) async {
    final batch = Batch()..delete(document);
    await batch.commit();
  }

  @override
  Future<T?> load<T extends Document<T>>(
    Document document, {
    Source source = Source.serverAndCache,
    Function(T?)? fromCache,
  }) async {
    if (fromCache != null) {
      try {
        final cache = await _load(document, Source.cache);
        fromCache(cache != null ? cache as T : null);
      } on Exception catch (_) {
        fromCache(null);
      }
    }
    final _document = await _load(document, source);
    return _document != null ? _document as T : null;
  }

  @override
  Future<T?> loadCache<T extends Document<T>>(Document document) async {
    try {
      final cache = await _load(document, Source.cache);
      if (cache != null) {
        return cache as T;
      }
    } on Exception catch (_) {
      // nothing
    }
    final _document = await _load(document, Source.serverAndCache);
    return _document != null ? _document as T : null;
  }

  @override
  Future<T?> loadCacheOnly<T extends Document<T>>(Document document) async {
    try {
      final cache = await _load(document, Source.cache);
      if (cache != null) {
        return cache as T;
      }
    } on Exception catch (_) {
      // nothing
    }
    return null;
  }

  Future<Document?> _load(Document document, Source source) async {
    final documentSnapshot =
        await document.reference.get(GetOptions(source: source));
    if (documentSnapshot.exists) {
      document.setSnapshot(documentSnapshot);
      return document;
    }
    return null;
  }

  @override
  Future saveRaw(
    Map<String, dynamic> values,
    DocumentReference reference, {
    bool isTimestamp = false,
    String createdFieldValueKey = documentCreatedAtKey,
    String updatedFieldValueKey = documentUpdatedAtKey,
  }) async {
    final data = values;
    final nowAt = Timestamp.now();
    if (isTimestamp) {
      data[createdFieldValueKey] = nowAt;
      data[updatedFieldValueKey] = nowAt;
    }
    final batch = Batch()..saveRaw(values, reference);
    await batch.commit();
  }

  @override
  Future updateRaw(
    Map<String, dynamic> values,
    DocumentReference reference, {
    bool isTimestamp = false,
    String updatedFieldValueKey = documentUpdatedAtKey,
  }) async {
    final data = values;
    final nowAt = Timestamp.now();
    if (isTimestamp) {
      data[updatedFieldValueKey] = nowAt;
    }
    final batch = Batch()..updateRaw(values, reference);
    await batch.commit();
  }

  @override
  Future deleteWithReference(DocumentReference reference) async {
    final batch = Batch()..deleteWithReference(reference);
    await batch.commit();
  }
}
