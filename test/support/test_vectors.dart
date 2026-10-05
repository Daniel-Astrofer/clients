import 'dart:convert';
import 'dart:io';

File resolveTestVectorFile(String filename) {
  final candidates = [
    'test/fixtures/$filename',
    '../contracts/test-vectors/$filename',
    'fixtures/$filename',
  ];
  for (final path in candidates) {
    final file = File(path);
    if (file.existsSync()) return file;
  }
  return File('test/fixtures/$filename');
}

Map<String, dynamic> loadPaymentApprovalVector() {
  final file = resolveTestVectorFile('financial-payment-approval-v1.json');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}
