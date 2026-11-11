import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:fitlog/core/db/connection.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/db/restore_files.dart';
import 'package:fitlog/core/security/key_material.dart';
import 'package:fitlog/core/security/recovery_phrase.dart';
import 'package:fitlog/core/util/paths.dart';
import 'package:fitlog/features/backup/data/backup_service.dart';
import 'package:fitlog/features/backup/data/backup_stream.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// Argon2id runs for every file sealed and opened here.
const _timeout = Timeout(Duration(minutes: 10));

/// A pieces size small enough that the database and the photos run over
/// many of them.
const _piece = 64;

List<int> _u16(int n) => [n >> 8, n & 0xFF];

List<int> _u32(int n) => (ByteData(4)..setUint32(0, n)).buffer.asUint8List();

List<int> _u64(int n) => (ByteData(8)..setUint64(0, n)).buffer.asUint8List();

/// One record of format 3: its kind, its name, its length and its bytes.
List<int> _record(String kind, String name, List<int> content) => [
  kind.codeUnitAt(0),
  ..._u16(utf8.encode(name).length),
  ...utf8.encode(name),
  ..._u64(content.length),
  ...content,
];

/// [plain] sealed the way format 3 says, written down here on its own and
/// not taken from the app: the header, then pieces of [_piece] bytes, each
/// with a nonce of the prefix, its number and whether it is the last one,
/// and the header as associated data. A full piece is never the last one;
/// the last one is shorter, and can be empty.
Future<File> _sealed(File file, String phrase, List<int> plain) async {
  final salt = randomBytes(16);
  final prefix = randomBytes(7);
  final header = [
    0x46, 0x49, 0x54, 0x4C, 3, //
    ..._u32(kArgonMemoryKib),
    kArgonIterations,
    kArgonParallelism,
    16,
    7,
    ..._u32(_piece),
    ...salt,
    ...prefix,
  ];
  final key = SecretKey(await deriveKek(secret: phrase, salt: salt));
  final out = BytesBuilder()..add(header);
  var count = 0;
  var at = 0;
  while (true) {
    final last = plain.length - at < _piece;
    final end = last ? plain.length : at + _piece;
    final box = await AesGcm.with256bits().encrypt(
      plain.sublist(at, end),
      secretKey: key,
      nonce: [...prefix, ..._u32(count), if (last) 1 else 0],
      aad: header,
    );
    out
      ..add(box.cipherText)
      ..add(box.mac.bytes);
    if (last) break;
    at = end;
    count++;
  }
  return file..writeAsBytesSync(out.takeBytes());
}

/// The header of format 3 is 40 bytes; a sealed piece is its bytes and a
/// 16-byte tag.
const _header = 40;
const _sealedPiece = _piece + 16;

/// Restoring a backup in pieces, never the whole archive in memory at once
/// (DECISIONS 304).
void main() {
  late Directory home;
  late AppPaths from;
  late AppPaths to;
  late String phrase;

  setUp(() async {
    home = await Directory.systemTemp.createTemp('fitlog_stream');
    from = AppPaths(Directory('${home.path}/van')..createSync());
    to = AppPaths(Directory('${home.path}/naar')..createSync());
    phrase = generateRecoveryPhrase();
  });

  tearDown(() async {
    if (await home.exists()) await home.delete(recursive: true);
  });

  /// Nothing of a refused backup stays next to the app's files.
  void nothingStaged() {
    final files = RestoreFiles(to);
    expect(files.stagedDatabase.existsSync(), isFalse);
    expect(files.stagedPhotos.existsSync(), isFalse);
  }

  group('made by the app', () {
    late Uint8List dek;
    late AppDatabase db;
    final photo = List<int>.generate(300, (i) => i % 251);

    setUp(() async {
      dek = generateDek();
      db = AppDatabase(
        openEncryptedExecutor(file: from.databaseFile, keyHex: toHex(dek)),
      );
      await db.settingsDao.ensureInitialized();
      await db.customStatement(
        'INSERT INTO routines (id, name, sort_order, created_at, updated_at) '
        "VALUES ('r-1', 'Bron', 0, 1, 1)",
      );
      await from.ensurePhotosDirectory();
      await from.photoFile('a.jpg').writeAsBytes(photo);
      await from.photoFile('leeg.jpg').writeAsBytes(const []);
    });

    tearDown(() => db.close());

    Future<File> made() => BackupService(
      db: db,
      paths: from,
    ).createBackup(recoveryPhrase: phrase, dek: dek, chunkSize: _piece);

    test('is written in pieces, and comes back whole', () async {
      final file = await made();

      expect(file.readAsBytesSync()[4], 3, reason: 'format 3');
      expect(
        (await from.exportDirectory()).listSync().map((f) => f.path),
        everyElement(isNot(endsWith('.part'))),
        reason: 'only a whole file gets its name',
      );

      final staged = await BackupService.stageFromFile(
        file: file,
        recoveryPhrase: phrase,
        paths: to,
      );
      expect(staged.dek, dek);
      final copy = sqlite3.open(staged.files.stagedDatabase.path);
      applyKeyAndVerify(copy, toHex(dek));
      expect(copy.select('SELECT name FROM routines').first['name'], 'Bron');
      copy.close();
      final photos = staged.files.stagedPhotos;
      expect(File('${photos.path}/a.jpg').readAsBytesSync(), photo);
      expect(File('${photos.path}/leeg.jpg').readAsBytesSync(), isEmpty);
    }, timeout: _timeout);

    test('with another phrase it says so, and leaves nothing', () async {
      final file = await made();

      await expectLater(
        BackupService.stageFromFile(
          file: file,
          recoveryPhrase: generateRecoveryPhrase(),
          paths: to,
        ),
        throwsA(
          isA<BackupUnreadableException>().having(
            (e) => e.message,
            'message',
            contains('herstelzin'),
          ),
        ),
      );
      nothingStaged();
    }, timeout: _timeout);

    test('cut off, changed, moved or left out: refused, and nothing is '
        'left', () async {
      final whole = (await made()).readAsBytesSync();
      final pieces = (whole.length - _header) ~/ _sealedPiece;
      expect(pieces, greaterThan(10), reason: 'many pieces to play with');
      final middle = _header + (pieces ~/ 2) * _sealedPiece;

      Uint8List swapped() {
        final bytes = Uint8List.fromList(whole);
        bytes.setRange(
          middle,
          middle + _sealedPiece,
          whole.sublist(middle + _sealedPiece, middle + 2 * _sealedPiece),
        );
        bytes.setRange(
          middle + _sealedPiece,
          middle + 2 * _sealedPiece,
          whole.sublist(middle, middle + _sealedPiece),
        );
        return bytes;
      }

      final damaged = <String, List<int>>{
        'cut at a piece': whole.sublist(0, middle),
        'cut inside a piece': whole.sublist(0, middle + 5),
        'one byte changed': Uint8List.fromList(whole)..[middle + 3] ^= 1,
        'two pieces swapped': swapped(),
        'a piece left out': [
          ...whole.sublist(0, middle),
          ...whole.sublist(middle + _sealedPiece),
        ],
        'the last piece left out': whole.sublist(
          0,
          whole.length - (whole.length - _header) % _sealedPiece,
        ),
        'the piece size changed': Uint8List.fromList(whole)..[16] ^= 1,
      };
      for (final MapEntry(key: what, value: bytes) in damaged.entries) {
        final file = File('${home.path}/kapot.fitlog')..writeAsBytesSync(bytes);
        await expectLater(
          BackupService.stageFromFile(
            file: file,
            recoveryPhrase: phrase,
            paths: to,
          ),
          throwsA(isA<BackupUnreadableException>()),
          reason: what,
        );
        nothingStaged();
      }
    }, timeout: _timeout);
  });

  test('pieces of no bytes are refused before anything is written', () async {
    final out = File('${home.path}/nul.fitlog');
    final source = File('${home.path}/bron.db')..writeAsBytesSync([1]);

    await expectLater(
      writeStreamBackup(
        out: out,
        recoveryPhrase: phrase,
        keyHex: 'ab' * 32,
        manifest: '{}',
        database: source,
        photos: const [],
        chunkSize: 0,
      ),
      throwsArgumentError,
    );
    expect(out.existsSync(), isFalse);
  });

  group('what is inside is checked', () {
    final key = utf8.encode('ab' * 32);

    Future<void> refused(List<int> plain, String message) async {
      final file = await _sealed(
        File('${home.path}/gemaakt.fitlog'),
        phrase,
        plain,
      );
      await expectLater(
        BackupService.stageFromFile(
          file: file,
          recoveryPhrase: phrase,
          paths: to,
        ),
        throwsA(
          isA<BackupUnreadableException>().having(
            (e) => e.message,
            'message',
            contains(message),
          ),
        ),
      );
      nothingStaged();
    }

    test('a photo whose name leads out of the photo folder', () async {
      await refused([
        ..._record('K', '', key),
        ..._record('D', '', [1]),
        ..._record('P', '../fitlog.db', [2]),
        ..._record('E', '', []),
      ], 'ongeldige naam');
    }, timeout: _timeout);

    test('a key that is no key', () async {
      await refused([
        ..._record('K', '', utf8.encode('abc')),
        ..._record('D', '', [1]),
        ..._record('E', '', []),
      ], 'ongeldig');
    }, timeout: _timeout);

    test('no database', () async {
      await refused([
        ..._record('K', '', key),
        ..._record('E', '', []),
      ], 'onvolledig');
    }, timeout: _timeout);

    test('no end', () async {
      await refused([
        ..._record('K', '', key),
        ..._record('D', '', [1]),
      ], 'onvolledig');
    }, timeout: _timeout);

    test('something after the end', () async {
      await refused([
        ..._record('K', '', key),
        ..._record('D', '', [1]),
        ..._record('E', '', []),
        ..._record('P', 'x.jpg', [2]),
      ], 'beschadigd');
    }, timeout: _timeout);

    test('two databases', () async {
      await refused([
        ..._record('K', '', key),
        ..._record('D', '', [1]),
        ..._record('D', '', [2]),
        ..._record('E', '', []),
      ], 'beschadigd');
    }, timeout: _timeout);

    test('a key far too long to be one', () async {
      await refused([
        ..._record('K', '', List.filled(math.pow(2, 16).toInt(), 0x61)),
        ..._record('D', '', [1]),
        ..._record('E', '', []),
      ], 'ongeldig');
    }, timeout: _timeout);
  });
}
