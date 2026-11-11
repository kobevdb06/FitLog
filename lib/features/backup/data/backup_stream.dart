/// Format 3 of the `.fitlog` file: the backup in pieces (DECISIONS 304).
///
/// Formats 1 and 2 sealed one zip in one go, so the whole archive - the
/// database and every photo - was in memory at once, and twice while it
/// was sealed or opened. With many photos that is more than Android lets an
/// app have. Format 3 is written and read a piece at a time.
///
/// After the header come pieces of `chunkSize` bytes, each sealed on its
/// own with AES-GCM under the key from the recovery phrase. A piece's nonce
/// is a random prefix, its number and whether it is the last one, and the
/// header goes along as associated data: a piece that is changed, moved,
/// left out or cut off does not open, and neither does one under a changed
/// header. A full piece is never the last; the last one is shorter, and may
/// be empty.
///
/// Inside, one record after another: a kind, a name, a length and that many
/// bytes. The key, the manifest, the database, the photos, and an end.
/// Nothing of it touches the disk unsealed, except the files a restore
/// stages.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../../core/security/key_material.dart';

/// Thrown when a `.fitlog` file cannot be read with the supplied phrase.
class BackupUnreadableException implements Exception {
  const BackupUnreadableException(this.message);

  final String message;

  @override
  String toString() => 'BackupUnreadableException: $message';
}

/// Whether [name] is a file name that stays in the photo folder.
bool isSafePhotoName(String name) =>
    RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$').hasMatch(name) &&
    !name.contains('..');

/// "FITL": a wrong file is turned away before Argon2id makes anyone wait.
const List<int> kBackupMagic = [0x46, 0x49, 0x54, 0x4C];

/// The format in pieces.
const int kStreamFormat = 3;

/// How much goes into one piece: small next to a phone's memory, large
/// enough that the tags add next to nothing.
const int kBackupChunkSize = 1 << 20;

/// A file that asks for larger pieces than this is not one FitLog wrote.
const int _maxChunkSize = 16 << 20;

const int _saltLength = 16;
const int _prefixLength = 7;
const int _macLength = 16;

/// magic | format | memory (4) | iterations | parallelism | salt length |
/// prefix length | piece size (4) | salt | prefix
const int _headerLength = 4 + 1 + 4 + 1 + 1 + 1 + 1 + 4 + 16 + 7;

/// The kinds of record, as their first byte.
const int _key = 0x4B; // K
const int _manifest = 0x4D; // M
const int _database = 0x44; // D
const int _photo = 0x50; // P
const int _end = 0x45; // E

/// Larger than any key or manifest FitLog writes.
const int _maxKeyLength = 1024;
const int _maxManifestLength = 64 * 1024;

const _broken = BackupUnreadableException(
  'Dit back-upbestand is beschadigd of onvolledig.',
);
const _wrongPhrase = BackupUnreadableException(
  'De herstelzin hoort niet bij dit back-upbestand.',
);
const _missing = BackupUnreadableException(
  'De back-up is onvolledig: de database of de sleutel ontbreekt.',
);
const _badKey = BackupUnreadableException(
  'De sleutel in de back-up is ongeldig.',
);

final _aes = AesGcm.with256bits();

List<int> _nonce(List<int> prefix, int count, {required bool last}) {
  if (count > 0xFFFFFFFF) throw StateError('Te veel stukken');
  return [
    ...prefix,
    ...(ByteData(4)..setUint32(0, count)).buffer.asUint8List(),
    if (last) 1 else 0,
  ];
}

/// Seals the backup into [out]: [keyHex], [manifest], the database at
/// [database] and the files [photos], a piece at a time.
Future<void> writeStreamBackup({
  required File out,
  required String recoveryPhrase,
  required String keyHex,
  required String manifest,
  required File database,
  required List<File> photos,
  int chunkSize = kBackupChunkSize,
}) async {
  // No bytes to a piece would never fill one; more than a reader takes
  // would leave a file nobody opens.
  if (chunkSize < 1 || chunkSize > _maxChunkSize) {
    throw ArgumentError.value(chunkSize, 'chunkSize');
  }
  final salt = randomBytes(_saltLength);
  final prefix = randomBytes(_prefixLength);
  final header =
      (BytesBuilder()
            ..add(kBackupMagic)
            ..addByte(kStreamFormat)
            ..add(_u32(kArgonMemoryKib))
            ..addByte(kArgonIterations)
            ..addByte(kArgonParallelism)
            ..addByte(_saltLength)
            ..addByte(_prefixLength)
            ..add(_u32(chunkSize))
            ..add(salt)
            ..add(prefix))
          .takeBytes();
  final key = SecretKey(await deriveKek(secret: recoveryPhrase, salt: salt));

  final raf = await out.open(mode: FileMode.write);
  try {
    await raf.writeFrom(header);
    final pieces = _Sealer(raf, key, prefix, header, chunkSize);

    Future<void> bytes(int kind, List<int> content) async {
      await pieces.add(_recordHead(kind, '', content.length));
      await pieces.add(content);
    }

    Future<void> file(int kind, String name, File source) async {
      final length = await source.length();
      await pieces.add(_recordHead(kind, name, length));
      var copied = 0;
      await for (final piece in source.openRead()) {
        copied += piece.length;
        await pieces.add(piece);
      }
      if (copied != length) {
        throw FileSystemException('Veranderd tijdens de back-up', source.path);
      }
    }

    await bytes(_key, utf8.encode(keyHex));
    await bytes(_manifest, utf8.encode(manifest));
    await file(_database, '', database);
    for (final photo in photos) {
      await file(_photo, photo.uri.pathSegments.last, photo);
    }
    await bytes(_end, const []);
    await pieces.close();
    await raf.flush();
  } finally {
    await raf.close();
  }
}

/// Opens the format 3 backup in [file]: the database goes to [database],
/// each photo into [photos]. Returns the key, as hex.
///
/// What it wrote is the caller's to remove when this throws.
Future<String> readStreamBackup({
  required File file,
  required String recoveryPhrase,
  required File database,
  required Directory photos,
}) async {
  final raf = await file.open();
  try {
    final length = await raf.length();
    final header = await raf.read(_headerLength);
    if (header.length < _headerLength) throw _broken;
    final data = ByteData.sublistView(header);
    for (var i = 0; i < kBackupMagic.length; i++) {
      if (header[i] != kBackupMagic[i]) {
        throw const BackupUnreadableException(
          'Dit is geen FitLog-back-upbestand.',
        );
      }
    }
    if (header[4] != kStreamFormat) throw _broken;
    final memoryKib = data.getUint32(5);
    final iterations = header[9];
    final parallelism = header[10];
    final chunkSize = data.getUint32(13);
    // A file that asks for a gigabyte or a thousand rounds is not one this
    // app wrote: it would only make the phone wait, or run out of memory.
    if (memoryKib < 8 * 1024 ||
        memoryKib > 1024 * 1024 ||
        iterations < 1 ||
        iterations > 16 ||
        parallelism < 1 ||
        parallelism > 16 ||
        header[11] != _saltLength ||
        header[12] != _prefixLength ||
        chunkSize < 1 ||
        chunkSize > _maxChunkSize) {
      throw _broken;
    }
    final salt = header.sublist(17, 17 + _saltLength);
    final prefix = header.sublist(17 + _saltLength, _headerLength);
    final key = SecretKey(
      await deriveKek(
        secret: recoveryPhrase,
        salt: salt,
        memoryKib: memoryKib,
        iterations: iterations,
        parallelism: parallelism,
      ),
    );

    final records = _Records(database, photos);
    try {
      var position = _headerLength;
      var count = 0;
      while (true) {
        final take = math.min(length - position, chunkSize + _macLength);
        if (take < _macLength) throw _broken;
        final sealed = await raf.read(take);
        if (sealed.length != take) throw _broken;
        position += take;
        final last = position == length;
        final List<int> plain;
        try {
          plain = await _aes.decrypt(
            SecretBox(
              Uint8List.sublistView(sealed, 0, take - _macLength),
              nonce: _nonce(prefix, count, last: last),
              mac: Mac(Uint8List.sublistView(sealed, take - _macLength)),
            ),
            secretKey: key,
            aad: header,
          );
        } on SecretBoxAuthenticationError {
          // The first piece is the one a wrong phrase stops at.
          throw count == 0 ? _wrongPhrase : _broken;
        }
        await records.add(plain);
        count++;
        if (last) break;
      }
      return records.finish();
    } finally {
      await records.close();
    }
  } finally {
    await raf.close();
  }
}

List<int> _u32(int n) => (ByteData(4)..setUint32(0, n)).buffer.asUint8List();

List<int> _recordHead(int kind, String name, int length) {
  final encoded = utf8.encode(name);
  return [
    kind,
    encoded.length >> 8,
    encoded.length & 0xFF,
    ...encoded,
    ...(ByteData(8)..setUint64(0, length)).buffer.asUint8List(),
  ];
}

/// Seals what it is given in pieces of the same size, and writes them.
class _Sealer {
  _Sealer(this._out, this._key, this._prefix, this._header, int chunkSize)
    : _buffer = Uint8List(chunkSize);

  final RandomAccessFile _out;
  final SecretKey _key;
  final List<int> _prefix;
  final List<int> _header;
  final Uint8List _buffer;
  int _filled = 0;
  int _count = 0;

  Future<void> add(List<int> bytes) async {
    var from = 0;
    while (from < bytes.length) {
      final take = math.min(bytes.length - from, _buffer.length - _filled);
      _buffer.setRange(_filled, _filled + take, bytes, from);
      _filled += take;
      from += take;
      if (_filled == _buffer.length) await _seal(last: false);
    }
  }

  /// The last piece: what is left, which is less than a whole one.
  Future<void> close() => _seal(last: true);

  Future<void> _seal({required bool last}) async {
    final box = await _aes.encrypt(
      Uint8List.sublistView(_buffer, 0, _filled),
      secretKey: _key,
      nonce: _nonce(_prefix, _count, last: last),
      aad: _header,
    );
    await _out.writeFrom(box.cipherText);
    await _out.writeFrom(box.mac.bytes);
    _filled = 0;
    _count++;
  }
}

/// Takes the opened pieces apart into records, and writes the database and
/// the photos as they come.
class _Records {
  _Records(this._databaseFile, this._photos);

  final File _databaseFile;
  final Directory _photos;

  /// The head of the record being read: kind, name length, name, length.
  final _head = <int>[];

  /// What is still to come of the record being read.
  int _left = 0;
  int _kind = 0;

  /// Where the record being read goes: a file, or memory for the small ones.
  RandomAccessFile? _file;
  BytesBuilder? _small;

  String? _keyHex;
  bool _sawDatabase = false;
  bool _ended = false;
  final _photoNames = <String>{};

  Future<void> add(List<int> bytes) async {
    var at = 0;
    while (at < bytes.length) {
      if (_ended) throw _broken;
      if (_left > 0) {
        final take = math.min(_left, bytes.length - at);
        final piece = bytes is Uint8List
            ? Uint8List.sublistView(bytes, at, at + take)
            : bytes.sublist(at, at + take);
        if (_file case final file?) {
          await file.writeFrom(piece);
        } else {
          _small!.add(piece);
        }
        at += take;
        _left -= take;
        if (_left == 0) await _done();
        continue;
      }
      _head.add(bytes[at++]);
      if (_head.length >= 3) {
        final nameLength = (_head[1] << 8) | _head[2];
        if (_head.length == 3 + nameLength + 8) await _start(nameLength);
      }
    }
  }

  Future<void> _start(int nameLength) async {
    _kind = _head[0];
    final String name;
    try {
      name = utf8.decode(_head.sublist(3, 3 + nameLength));
    } on FormatException {
      throw _broken;
    }
    final length = ByteData.sublistView(
      Uint8List.fromList(_head.sublist(3 + nameLength)),
    ).getUint64(0);
    _head.clear();
    if (length < 0) throw _broken;

    switch (_kind) {
      case _key:
        if (_keyHex != null) throw _broken;
        if (length > _maxKeyLength) throw _badKey;
        _small = BytesBuilder();
      case _manifest:
        if (length > _maxManifestLength) throw _broken;
        _small = BytesBuilder();
      case _database:
        if (_sawDatabase) throw _broken;
        _sawDatabase = true;
        _file = await _databaseFile.open(mode: FileMode.write);
      case _photo:
        // A bare file name and nothing else: "../x" or an absolute path
        // would be written outside the photo folder.
        if (!isSafePhotoName(name)) {
          throw const BackupUnreadableException(
            'De back-up bevat een foto met een ongeldige naam.',
          );
        }
        if (!_photoNames.add(name)) throw _broken;
        _file = await File('${_photos.path}/$name').open(mode: FileMode.write);
      case _end:
        if (length != 0) throw _broken;
        _ended = true;
        return;
      default:
        throw _broken;
    }
    _left = length;
    if (_left == 0) await _done();
  }

  Future<void> _done() async {
    if (_file case final file?) {
      await file.flush();
      await file.close();
      _file = null;
    }
    if (_small case final small?) {
      if (_kind == _key) {
        _keyHex = utf8.decode(small.takeBytes(), allowMalformed: true).trim();
      }
      _small = null;
    }
  }

  /// The key, once everything came: the database, the key and the end.
  String finish() {
    if (!_ended) throw _broken;
    final keyHex = _keyHex;
    if (!_sawDatabase || keyHex == null) throw _missing;
    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(keyHex)) throw _badKey;
    return keyHex;
  }

  /// Lets go of a file still open when reading stopped halfway.
  Future<void> close() async {
    await _file?.close();
    _file = null;
  }
}
