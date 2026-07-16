import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:kerosene/features/home/domain/entities/home_stage.dart';

/// Same algorithm as backend [HomeStageFingerprint] (SHA-256, first 32 hex).
String homeStageContentFingerprint(HomeStage stage) {
  return homeStageContentFingerprintParts(
    stageId: stage.id,
    kind: stage.kind.name,
    title: stage.content.title,
    body: stage.content.body ?? '',
  );
}

String homeStageContentFingerprintParts({
  required String stageId,
  required String kind,
  required String title,
  String body = '',
}) {
  final raw = [
    stageId.trim(),
    kind.trim().toUpperCase(),
    title.trim(),
    body.trim(),
  ].join('\n');
  final dig = sha256.convert(utf8.encode(raw));
  final hex = dig.toString(); // already hex
  return hex.length >= 32 ? hex.substring(0, 32) : hex;
}
