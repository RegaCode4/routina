import 'dart:typed_data';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:routina/data/backup_cipher.dart';
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
    final result = await FilePicker.pickFiles(
      type: FileType.any,
      withReadStream: true,
    );
    if (result == null) return null;
    final file = result.files.single;
    if (file.size > BackupCipher.maxBytes) throw BackupIssue.tooLarge;
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in file.readStream ?? file.xFile.openRead()) {
      if (bytes.length + chunk.length > BackupCipher.maxBytes) {
        throw BackupIssue.tooLarge;
      }
      bytes.add(chunk);
    }
    return (name: file.name, bytes: bytes.takeBytes());
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
