import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/network/file_transfer.dart';

void main() {
  test('splitIntoChunks produces correct number of chunks', () {
    final data = Uint8List(200 * 1024); // 200KB
    final chunks = FileTransfer.splitIntoChunks(data, chunkSize: 64 * 1024);
    expect(chunks.length, equals(4)); // ceil(200/64) = 4
  });

  test('reassembleChunks reconstructs original bytes', () {
    final original = Uint8List.fromList(List.generate(100, (i) => i % 256));
    final chunks = FileTransfer.splitIntoChunks(original, chunkSize: 30);
    final reassembled = FileTransfer.reassembleChunks(chunks);
    expect(reassembled, equals(original));
  });
}
