import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

/// High-performance JSON decoding pipeline running strictly off the UI thread.
///
/// Uses [Isolate.run] with [TransferableTypedData] to achieve zero-copy transfer
/// of large network payloads (e.g., 2MB ledger statements or block lists),
/// completely eliminating frame drops and Young Space GC spikes on the main thread.
class IsolateDataDecoder {
  const IsolateDataDecoder._();

  /// Decodes a raw UTF-8 byte buffer into a dynamic JSON object in a background Isolate.
  static Future<dynamic> decodeBytes(Uint8List rawBytes) async {
    if (rawBytes.isEmpty) return null;

    // Zero-copy transfer of ownership to the worker isolate
    final transferable = TransferableTypedData.fromList([rawBytes]);

    return await Isolate.run(() {
      final materialized = transferable.materialize().asUint8List();
      final decodedString = utf8.decode(materialized, allowMalformed: true);
      return jsonDecode(decodedString);
    });
  }

  /// Decodes a raw JSON string in a background Isolate.
  /// Used when the HTTP client already converted bytes to string.
  static Future<dynamic> decodeString(String rawJson) async {
    if (rawJson.trim().isEmpty) return null;
    return await Isolate.run(() {
      return jsonDecode(rawJson);
    });
  }

  /// Parses a complex payload into a typed List via [mapper] inside the worker isolate.
  static Future<List<T>> parseList<T>(
    Uint8List rawBytes,
    T Function(Map<String, dynamic> item) mapper,
  ) async {
    if (rawBytes.isEmpty) return const [];

    final transferable = TransferableTypedData.fromList([rawBytes]);

    return await Isolate.run(() {
      final materialized = transferable.materialize().asUint8List();
      final decodedString = utf8.decode(materialized, allowMalformed: true);
      final raw = jsonDecode(decodedString);

      if (raw is! List) return <T>[];

      final result = <T>[];
      for (final element in raw) {
        if (element is Map<String, dynamic>) {
          result.add(mapper(element));
        } else if (element is Map) {
          result.add(mapper(Map<String, dynamic>.from(element)));
        }
      }
      return result;
    });
  }
}
