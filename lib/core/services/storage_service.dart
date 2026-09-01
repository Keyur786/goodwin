import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  StorageService({FirebaseStorage? storage}) : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  Future<String> uploadFile({
    required String path,
    required String fileName,
    required String filePath,
  }) async {
    final ref = _storage.ref().child(path).child(fileName);
    final uploadTask = await ref.putString(filePath);
    return uploadTask.ref.fullPath;
  }
}
