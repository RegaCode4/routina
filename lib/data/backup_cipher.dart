import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:routina/domain/backup.dart';

class BackupCipher {
  const BackupCipher();

  static const extension = 'routina';
  static const maxBytes = 32 * 1024 * 1024;
  static const _magic = [82, 79, 85, 84, 66, 75, 85, 80]; // ROUTBKUP
  static const _format = 1;
  static const _suite = 1;
  static const _iterations = 600000;
  static const _saltOffset = 14;
  static const _nonceOffset = 30;
  static const _headerLength = 42;
  static const _tagLength = 16;
  static const _maximumPayload = maxBytes - _headerLength - _tagLength;

  Future<Uint8List> seal(BackupArchive archive, String password) =>
      Isolate.run(() => _seal(archive, password));

  Future<BackupArchive> open(
    Uint8List bytes,
    String password, {
    required int expectedSchema,
  }) {
    if (bytes.length > maxBytes) return Future.error(BackupIssue.tooLarge);
    return Isolate.run(() => _open(bytes, password, expectedSchema));
  }

  static Future<Uint8List> _seal(BackupArchive archive, String password) async {
    if (password.isEmpty) throw BackupIssue.passwordRequired;
    final output = _BackupByteSink(_maximumPayload);
    JsonUtf8Encoder(
      null,
      null,
      64 * 1024,
    ).startChunkedConversion(output).add(archive.toJson());
    final plaintext = output.takeBytes();
    try {
      final header = Uint8List(_headerLength)..setAll(0, _magic);
      header[8] = _format;
      header[9] = _suite;
      ByteData.sublistView(header).setUint32(10, _iterations);
      final random = Random.secure();
      for (var index = _saltOffset; index < _headerLength; index++) {
        header[index] = random.nextInt(256);
      }
      final key = await _derive(password, header);
      try {
        final box = await AesGcm.with256bits().encrypt(
          plaintext,
          secretKey: key,
          nonce: Uint8List.sublistView(header, _nonceOffset),
          aad: header,
        );
        return (BytesBuilder(copy: false)
              ..add(header)
              ..add(box.cipherText)
              ..add(box.mac.bytes))
            .takeBytes();
      } finally {
        key.destroy();
      }
    } finally {
      plaintext.fillRange(0, plaintext.length, 0);
    }
  }

  static Future<BackupArchive> _open(
    Uint8List bytes,
    String password,
    int expectedSchema,
  ) async {
    if (password.isEmpty) throw BackupIssue.passwordRequired;
    if (bytes.length <= _headerLength + _tagLength ||
        !_magic.indexed.every((byte) => bytes[byte.$1] == byte.$2)) {
      throw BackupIssue.invalidFile;
    }
    if (bytes[8] != _format || bytes[9] != _suite) {
      throw BackupIssue.unsupportedFormat;
    }
    if (ByteData.sublistView(bytes).getUint32(10) != _iterations) {
      throw BackupIssue.invalidFile;
    }
    final header = Uint8List.sublistView(bytes, 0, _headerLength);
    final tagOffset = bytes.length - _tagLength;
    final key = await _derive(password, header);
    try {
      final clear = await AesGcm.with256bits().decrypt(
        SecretBox(
          Uint8List.sublistView(bytes, _headerLength, tagOffset),
          nonce: Uint8List.sublistView(header, _nonceOffset),
          mac: Mac(Uint8List.sublistView(bytes, tagOffset)),
        ),
        secretKey: key,
        aad: header,
      );
      try {
        return BackupArchive.decode(
          utf8.decode(clear),
          expectedSchema: expectedSchema,
        );
      } on FormatException {
        throw BackupIssue.invalidData;
      } finally {
        clear.fillRange(0, clear.length, 0);
      }
    } on SecretBoxAuthenticationError {
      throw BackupIssue.authentication;
    } finally {
      key.destroy();
    }
  }

  static Future<SecretKey> _derive(String password, Uint8List header) async {
    final bytes = utf8.encode(password);
    final input = SecretKey(bytes);
    try {
      return await Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: _iterations,
        bits: 256,
      ).deriveKey(
        secretKey: input,
        nonce: Uint8List.sublistView(header, _saltOffset, _nonceOffset),
      );
    } finally {
      input.destroy();
      bytes.fillRange(0, bytes.length, 0);
    }
  }
}

class _BackupByteSink implements Sink<List<int>> {
  _BackupByteSink(this.limit);

  final int limit;
  final _bytes = BytesBuilder(copy: false);

  @override
  void add(List<int> data) {
    if (data.length > limit - _bytes.length) throw BackupIssue.tooLarge;
    _bytes.add(data);
  }

  @override
  void close() {}

  Uint8List takeBytes() => _bytes.takeBytes();
}
