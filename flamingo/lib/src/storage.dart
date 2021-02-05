import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';

import '../flamingo.dart';

abstract class StorageRepository {
  FirebaseStorage get storage;
  Stream<TaskSnapshot> get uploader;
  Future<StorageFile> save(
    String folderPath,
    File data, {
    String filename,
    String mimeType = mimeTypeApplicationOctetStream,
    Map<String, String> metadata = const <String, String>{},
    Map<String, dynamic> additionalData = const <String, dynamic>{},
  });
  Future<void> delete(String folderPath, StorageFile storageFile);
  Future<String> getDownloadUrl(String folderPath, StorageFile storageFile);
  Future<String> getDownloadUrlWithPath(String filePath);
  Future<StorageFile> saveWithDoc(
    DocumentReference reference,
    String folderName,
    File data, {
    String filename,
    String mimeType = mimeTypeApplicationOctetStream,
    Map<String, String> metadata = const <String, String>{},
    Map<String, dynamic> additionalData = const <String, dynamic>{},
  });
  Future<void> deleteWithDoc(
    DocumentReference reference,
    String folderName,
    StorageFile storageFile, {
    bool isNotNull = true,
  });
  void fetch();
  void dispose();
}

class Storage implements StorageRepository {
  Storage({
    FirebaseStorage storage,
  }) {
    _storage = storage ?? storageInstance;
  }
  static String fileName({int length}) => Helper.randomString(length: length);

  FirebaseStorage _storage;
  PublishSubject<TaskSnapshot> _uploader;

  @override
  FirebaseStorage get storage => _storage;

  @override
  Stream<TaskSnapshot> get uploader => _uploader.stream;

  @override
  Future<StorageFile> save(
    String folderPath,
    File data, {
    String filename,
    String mimeType = mimeTypeApplicationOctetStream,
    Map<String, String> metadata = const <String, String>{},
    Map<String, dynamic> additionalData = const <String, dynamic>{},
  }) async {
    final refFilename = filename ?? Storage.fileName();
    final refMimeType = mimeType ?? '';
    final path = '$folderPath/$refFilename';
    final ref = storage.ref().child(path);
    final settableMetadata =
        SettableMetadata(contentType: refMimeType, customMetadata: metadata);
    UploadTask uploadTask;
    if (kIsWeb) {
      uploadTask = ref.putData(data.readAsBytesSync(), settableMetadata);
    } else {
      uploadTask = ref.putFile(data, settableMetadata);
    }
    if (_uploader != null) {
      uploadTask.snapshotEvents.listen(_uploader.add);
    }
    final snapshot = await uploadTask.whenComplete(() => null);
    final downloadUrl = await snapshot.ref.getDownloadURL();
    return StorageFile(
      name: refFilename,
      url: downloadUrl,
      path: path,
      mimeType: refMimeType,
      metadata: metadata,
      additionalData: additionalData,
    );
  }

  @override
  Future<void> delete(String folderPath, StorageFile storageFile) async {
    final path = '$folderPath/${storageFile.name}';
    final ref = storage.ref().child(path);
    await ref.delete();
    storageFile.isDeleted = true;
  }

  @override
  Future<String> getDownloadUrl(
      String folderPath, StorageFile storageFile) async {
    final path = '$folderPath/${storageFile.name}';
    final ref = storage.ref().child(path);
    return ref.getDownloadURL();
  }

  @override
  Future<String> getDownloadUrlWithPath(String filePath) async {
    final ref = storage.ref().child(filePath);
    return ref.getDownloadURL();
  }

  @override
  Future<StorageFile> saveWithDoc(
    DocumentReference reference,
    String folderName,
    File data, {
    String filename,
    String mimeType = mimeTypeApplicationOctetStream,
    Map<String, String> metadata = const <String, String>{},
    Map<String, dynamic> additionalData = const <String, dynamic>{},
  }) async {
    final folderPath = '${reference.path}/$folderName';
    final storageFile = await save(folderPath, data,
        filename: filename, mimeType: mimeType, metadata: metadata);
    storageFile.additionalData = additionalData;
    final documentAccessor = DocumentAccessor();
    final values = <String, dynamic>{};
    values['$folderName'] = storageFile.toJson();
    await documentAccessor.saveRaw(values, reference);
    return storageFile;
  }

  @override
  Future<void> deleteWithDoc(
    DocumentReference reference,
    String folderName,
    StorageFile storageFile, {
    bool isNotNull = true,
  }) async {
    final folderPath = '${reference.path}/$folderName';
    await delete(folderPath, storageFile);
    if (storageFile.isDeleted) {
      final values = <String, dynamic>{};
      if (isNotNull) {
        values['$folderName'] = FieldValue.delete();
      } else {
        values['$folderName'] = null;
      }
      final documentAccessor = DocumentAccessor();
      await documentAccessor.updateRaw(values, reference);
    }
    return;
  }

  @override
  void fetch() {
    _uploader ??= PublishSubject<TaskSnapshot>();
  }

  @override
  void dispose() {
    _uploader.close();
    _uploader = null;
  }
}
