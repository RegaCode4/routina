import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:routina/domain/backup.dart';
import 'package:share_plus/share_plus.dart';

typedef PickedBackup = ({String name, Uint8List bytes});

abstract interface class BackupFiles {
  Future<PickedBackup?> pick();
  Future<bool> save(String name, Uint8List bytes);

  /// True means the share sheet handed the file off or has no result API.
  Future<bool> share(String name, Uint8List bytes, Rect origin);
}

class SystemBackupFiles implements BackupFiles {
  const SystemBackupFiles();

  @override
  Future<PickedBackup?> pick() async {
    try {
      final file = await const MethodChannel(
        'routina/backup_storage',
      ).invokeMapMethod<String, Object?>('pick');
      if (file == null) return null;
      return (name: file['name'] as String, bytes: file['bytes'] as Uint8List);
    } on PlatformException catch (error) {
      if (error.code == 'tooLarge') throw BackupIssue.tooLarge;
      throw BackupIssue.readFailed;
    }
  }

  @override
  Future<bool> save(String name, Uint8List bytes) async =>
      await FilePicker.saveFile(
        dialogTitle: 'Simpan backup Routina',
        fileName: name,
        bytes: bytes,
      ) !=
      null;

  @override
  Future<bool> share(String name, Uint8List bytes, Rect origin) async {
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            bytes,
            name: name,
            mimeType: 'application/octet-stream',
          ),
        ],
        fileNameOverrides: [name],
        sharePositionOrigin: origin,
      ),
    );
    return result.status != ShareResultStatus.dismissed;
  }
}
