import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/network/api_transport.dart';
import 'package:kerosene/features/web/data/admin_data_service.dart';

class FakeTransport implements ApiTransport {
  final paths = <String>[];
  Object? submitted;
  @override
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    Options? options,
  }) async {
    paths.add(path);
    return Response(
        requestOptions: RequestOptions(path: path), data: {'ready': false});
  }

  @override
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    Options? options,
  }) async {
    paths.add(path);
    submitted = data;
    return Response(
        requestOptions: RequestOptions(path: path),
        data: {'status': 'BLOCKED', 'deploymentExecuted': false});
  }
}

void main() {
  test('Cell requests use only Core APIs and target-bound plan body', () async {
    final transport = FakeTransport();
    final service = AdminDataService(transport);
    await service.fetchCellOperations();
    await service.fetchCellUpdates();
    final plan = await service.createCellPlan({
      'releaseId': 'release-new',
      'sequence': 2,
      'digest': 'sha256:lock',
      'deploymentManifestDigest': 'sha256:config',
      'packageManifestDigest': 'sha256:package',
      'unrelated': 'must not be forwarded',
    });
    expect(transport.paths, [
      '/api/admin/operations/cell',
      '/api/admin/operations/cell/updates',
      '/api/admin/operations/cell/updates/plans',
    ]);
    expect(transport.submitted, {
      'targetReleaseId': 'release-new',
      'targetSequence': 2,
      'targetDigest': 'sha256:lock',
      'deploymentManifestDigest': 'sha256:config',
      'packageManifestDigest': 'sha256:package',
    });
    expect(plan['deploymentExecuted'], false);
  });
}
