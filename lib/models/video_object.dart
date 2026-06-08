/// Модель объекта видеонаблюдения (Фаза 6, mobile).
/// Источник: GET /mobile-api/v1/video/objects
class VideoCameraModel {
  final int id;
  final String label;
  final String model;
  final String resolution;
  final bool active;
  final bool isOutdoor;
  final bool isPtz;
  final bool canView;
  final String streamUrl;

  VideoCameraModel({
    required this.id,
    required this.label,
    required this.model,
    required this.resolution,
    required this.active,
    required this.isOutdoor,
    required this.isPtz,
    required this.canView,
    required this.streamUrl,
  });

  factory VideoCameraModel.fromJson(Map<String, dynamic> j) => VideoCameraModel(
        id: j['id'] ?? 0,
        label: j['label'] ?? '',
        model: j['model'] ?? '',
        resolution: j['resolution'] ?? '',
        active: j['active'] ?? true,
        isOutdoor: j['is_outdoor'] ?? false,
        isPtz: j['is_ptz'] ?? false,
        canView: j['can_view'] ?? false,
        streamUrl: j['stream_url'] ?? '',
      );
}

class VideoSubscriptionModel {
  final String type;
  final double price;
  final int? cameras;
  final bool active;

  VideoSubscriptionModel({
    required this.type,
    required this.price,
    required this.cameras,
    required this.active,
  });

  factory VideoSubscriptionModel.fromJson(Map<String, dynamic> j) =>
      VideoSubscriptionModel(
        type: j['type'] ?? '',
        price: (j['price'] ?? 0).toDouble(),
        cameras: j['cameras'],
        active: j['active'] ?? false,
      );
}

class VideoObjectModel {
  final int id;
  final String name;
  final String type;
  final String address;
  final bool camerasBlocked;
  final int camerasCount;
  final double monthly;
  final double? accountBalance;
  final String? projectTitle;
  final String? projectStatus;
  final List<VideoCameraModel> cameras;
  final List<VideoSubscriptionModel> subscriptions;

  VideoObjectModel({
    required this.id,
    required this.name,
    required this.type,
    required this.address,
    required this.camerasBlocked,
    required this.camerasCount,
    required this.monthly,
    required this.accountBalance,
    required this.projectTitle,
    required this.projectStatus,
    required this.cameras,
    required this.subscriptions,
  });

  factory VideoObjectModel.fromJson(Map<String, dynamic> j) {
    final proj = j['active_project'];
    return VideoObjectModel(
      id: j['id'] ?? 0,
      name: j['name'] ?? '',
      type: j['type'] ?? '',
      address: j['address'] ?? '',
      camerasBlocked: j['cameras_blocked'] ?? false,
      camerasCount: j['cameras_count'] ?? 0,
      monthly: (j['monthly'] ?? 0).toDouble(),
      accountBalance:
          j['account_balance'] == null ? null : (j['account_balance']).toDouble(),
      projectTitle: proj != null ? proj['title'] : null,
      projectStatus: proj != null ? proj['status'] : null,
      cameras: ((j['cameras'] ?? []) as List)
          .map((e) => VideoCameraModel.fromJson(e))
          .toList(),
      subscriptions: ((j['subscriptions'] ?? []) as List)
          .map((e) => VideoSubscriptionModel.fromJson(e))
          .toList(),
    );
  }
}
