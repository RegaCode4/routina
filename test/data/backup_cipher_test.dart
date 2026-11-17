import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:routina/data/backup_cipher.dart';
import 'package:routina/domain/backup.dart';

// Produced independently with Node.js/OpenSSL pbkdf2Sync and createCipheriv.
// The deterministic salt/nonce apply only to this interoperability fixture.
const vector =
    'Uk9VVEJLVVABAQAJJ8AAAQIDBAUGBwgJCgsMDQ4PEBESExQVFhcYGRobyiFBi6rFa8lLUzGcBkZiak4KpYVA0MFSMh4LqNJlw70u+Z+ooTjYYcrVFlbzo6yxRHY0s4+NscAGZUl8HevgzJbh+HEedD5XNmot7xo348aGJd1dTY5qDct/BYMcYb5RDD2eYmFV/TZ8NENq+dOVTiiwtvrlTYbvsLZHc6nAZSkhe1UataphUmdEVzstXyHWvsaYFan3VF8z8B48XFnNANQvJGOitpER5dUYz8ZayDx90o0DOqK0ZYwAHrujyqaRbvAvK8i04PBGcF9oXiNcQfxdL6vGj5j7oftqeFP+C96RCOQlkTYxQ8Eyhe/OWmGenJahsxvGO/1OCd9VNYI2Jknzl4Ak8KrGARlt+TtsCQs3Ai2j+W9hmmTXRrn0Cm4CSf50SnDc4V5nssucR3hVN7CJcrj9P66DhNSg/jiENtBc35DCr3ApvIKi';

void main() {
  const cipher = BackupCipher();
  const password = 'vektor-🔒';

  test(
    'v1 authenticates and reads an independent OpenSSL vector using exact UTF-8',
    () async {
      final archive = await cipher.open(
        base64Decode(vector),
        password,
        expectedSchema: 9,
      );
      expect(archive.createdAt, DateTime.utc(2026, 11, 17));
      expect(archive.snapshot.entities, isEmpty);
      expect(archive.snapshot.schemaVersion, 9);
      await expectLater(
        cipher.open(base64Decode(vector), password, expectedSchema: 8),
        throwsA(BackupIssue.unsupportedSchema),
      );
    },
  );

  test(
    'one authentication error covers incorrect passwords and modified salt, nonce, ciphertext and tag',
    () async {
      final bytes = base64Decode(vector);
      await expectLater(
        cipher.open(bytes, ' $password', expectedSchema: 9),
        throwsA(BackupIssue.authentication),
      );
      for (final offset in [14, 30, 42, bytes.length - 1]) {
        final modified = Uint8List.fromList(bytes)..[offset] ^= 1;
        await expectLater(
          cipher.open(modified, password, expectedSchema: 9),
          throwsA(BackupIssue.authentication),
        );
      }
    },
  );

  test(
    'independent exports use distinct salt and nonce and do not reveal payload fields',
    () async {
      final archive = BackupArchive(
        DateTime.utc(2026, 11, 17),
        BackupSnapshot(9, []),
      );
      final first = await cipher.seal(archive, password);
      final next = await cipher.seal(archive, password);
      expect(first.sublist(14, 30), isNot(equals(next.sublist(14, 30))));
      expect(first.sublist(30, 42), isNot(equals(next.sublist(30, 42))));
      expect(latin1.decode(first), isNot(contains('manifest')));
      expect(latin1.decode(first), isNot(contains('schemaVersion')));
      expect(
        (await cipher.open(next, password, expectedSchema: 9)).createdAt,
        archive.createdAt,
      );
    },
  );

  test(
    'rejects unknown suite, unsafe KDF parameter and truncation before decryption',
    () async {
      final bytes = base64Decode(vector);
      await expectLater(
        cipher.open(
          Uint8List.fromList(bytes)..[9] = 2,
          password,
          expectedSchema: 9,
        ),
        throwsA(BackupIssue.unsupportedFormat),
      );
      await expectLater(
        cipher.open(
          Uint8List.fromList(bytes)..[10] = 255,
          password,
          expectedSchema: 9,
        ),
        throwsA(BackupIssue.invalidFile),
      );
      await expectLater(
        cipher.open(
          Uint8List.sublistView(bytes, 0, 30),
          password,
          expectedSchema: 9,
        ),
        throwsA(BackupIssue.invalidFile),
      );
    },
  );
}
