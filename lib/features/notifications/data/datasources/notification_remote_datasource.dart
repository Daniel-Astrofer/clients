import 'package:kerosene/core/config/app_config.dart';
import 'package:kerosene/core/errors/exceptions.dart';
import 'package:kerosene/core/network/api_client.dart';
import 'package:kerosene/features/notifications/domain/entities/session_notification_item.dart';
import 'package:kerosene/features/notifications/domain/entities/device_token.dart';

abstract class NotificationRemoteDataSource {
  Future<List<SessionNotificationItem>> getNotifications();
  Future<void> markAsRead(String notificationId);
  Future<void> registerDeviceToken({
    required String platform,
    required String token,
    String? deviceId,
    String? appVersion,
  });
  Future<List<DeviceToken>> activeDeviceTokens();
  Future<void> revokeDeviceToken(String tokenId);
}

class NotificationRemoteDataSourceImpl implements NotificationRemoteDataSource {
  final ApiClient apiClient;

  NotificationRemoteDataSourceImpl(this.apiClient);

  @override
  Future<List<SessionNotificationItem>> getNotifications() async {
    try {
      final response = await apiClient.get(AppConfig.notificationsList);
      final body = response.data;

      if (response.statusCode != 200 ||
          body is! List ||
          body.any((item) =>
              item is! Map ||
              (item['id'] is! String && item['id'] is! int) ||
              item['id'].toString().trim().isEmpty)) {
        throw ServerException(
          message: 'Resposta inesperada ao carregar notificações.',
          errorCode: 'ERR_NOTIFICATIONS_INVALID_RESPONSE',
          data: body,
        );
      }

      return body
          .map((item) => SessionNotificationItem.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList();
    } catch (error) {
      if (error is AppException) {
        rethrow;
      }
      throw ServerException(message: 'Erro ao carregar notificações: $error');
    }
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    try {
      await apiClient.put(
        AppConfig.notificationsRead.replaceFirst('{id}', notificationId),
      );
    } catch (error) {
      if (error is AppException) {
        rethrow;
      }
      throw ServerException(
          message: 'Erro ao marcar notificação como lida: $error');
    }
  }

  @override
  Future<void> registerDeviceToken({
    required String platform,
    required String token,
    String? deviceId,
    String? appVersion,
  }) async {
    try {
      await apiClient.post(
        AppConfig.notificationRegisterToken,
        data: {
          'platform': platform,
          'token': token,
          if (deviceId != null) 'deviceId': deviceId,
          if (appVersion != null) 'appVersion': appVersion,
        },
      );
    } catch (error) {
      if (error is AppException) {
        rethrow;
      }
      throw ServerException(
          message: 'Erro ao registrar token de notificação: $error');
    }
  }

  @override
  Future<List<DeviceToken>> activeDeviceTokens() async {
    try {
      final response = await apiClient.get(AppConfig.notificationDeviceTokens);
      final body = response.data;
      if (response.statusCode != 200 || body is! List) {
        throw ServerException(
          message:
              'Resposta inesperada ao carregar dispositivos de notificação.',
          errorCode: 'ERR_NOTIFICATION_DEVICES_INVALID_RESPONSE',
          data: body,
        );
      }
      final devices = <DeviceToken>[];
      for (final item in body) {
        if (item is! Map ||
            item['active'] is! bool ||
            (item['id'] is! String && item['id'] is! int) ||
            item['id'].toString().trim().isEmpty) {
          throw const ServerException(
              message: 'Invalid notification registration response.',
              errorCode: 'ERR_NOTIFICATION_DEVICES_INVALID_RESPONSE');
        }
        devices.add(DeviceToken.fromJson(Map<String, dynamic>.from(item)));
      }
      return devices;
    } catch (error) {
      if (error is AppException) rethrow;
      throw ServerException(
        message: 'Erro ao carregar dispositivos de notificação: $error',
      );
    }
  }

  @override
  Future<void> revokeDeviceToken(String tokenId) async {
    try {
      if (tokenId.trim().isEmpty) {
        throw const ServerException(
            message: 'Notification registration ID required.',
            errorCode: 'ERR_NOTIFICATION_DEVICE_ID_REQUIRED');
      }
      final response = await apiClient.delete(
          AppConfig.notificationDeviceToken(Uri.encodeComponent(tokenId)));
      // The current Core contract acknowledges a completed revocation with 204.
      // A queued response cannot be presented as an already disabled device.
      if (response.statusCode != 204) {
        throw ServerException(
            message: 'Notification registration change was not confirmed.',
            statusCode: response.statusCode,
            errorCode: 'ERR_NOTIFICATION_REVOKE_UNCONFIRMED');
      }
    } catch (error) {
      if (error is AppException) {
        rethrow;
      }
      throw ServerException(
          message: 'Erro ao revogar token de notificação: $error');
    }
  }
}
