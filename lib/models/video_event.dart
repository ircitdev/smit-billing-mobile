/// Событие камеры (детектор самой камеры: человек, движение, саботаж…).
/// Источник: GET /mobile-api/v1/video/objects/<id>/events — та же лента, что в ЛК.
class VideoEventModel {
  final int id;
  final int cameraId;
  final String cameraLabel;
  final String label;      // person / motion / intrusion / line / tamper / sound
  final String labelRu;
  final String when;       // «сегодня 03:14»
  final String time;       // «03:14:05»
  final int ts;            // время события, unix — для архива
  final String day;        // 2026-10-28 — группировка
  final String dayLabel;   // «Сегодня» / «27 октября, понедельник»
  final int? duration;     // null — событие ещё идёт
  final String thumb;      // относительная ссылка на кадр (с JWT)
  final String downloadUrl; // временная ссылка на скачивание кадра (без JWT)
  final bool hasArchive;
  final bool alarm;
  String feedback;         // '' / 'false' («Это не тревога»)

  VideoEventModel({
    required this.id,
    required this.cameraId,
    required this.cameraLabel,
    required this.label,
    required this.labelRu,
    required this.when,
    required this.time,
    required this.ts,
    required this.day,
    required this.dayLabel,
    required this.duration,
    required this.thumb,
    required this.downloadUrl,
    required this.hasArchive,
    required this.alarm,
    required this.feedback,
  });

  bool get isFalse => feedback == 'false';
  DateTime get startedAt => DateTime.fromMillisecondsSinceEpoch(ts * 1000);

  String get durationText {
    if (duration == null) return 'идёт';
    if (duration == 0) return '';
    return '$duration с';
  }

  factory VideoEventModel.fromJson(Map<String, dynamic> j) => VideoEventModel(
        id: j['id'] ?? 0,
        cameraId: j['camera'] ?? 0,
        cameraLabel: j['camera_label'] ?? '',
        label: j['label'] ?? '',
        labelRu: j['label_ru'] ?? '',
        when: j['when'] ?? '',
        time: j['time'] ?? '',
        ts: j['ts'] ?? 0,
        day: j['day'] ?? '',
        dayLabel: j['day_label'] ?? '',
        duration: j['duration'],
        thumb: j['thumb'] ?? '',
        downloadUrl: j['download_url'] ?? '',
        hasArchive: (j['archive_url'] ?? '').toString().isNotEmpty,
        alarm: j['alarm'] ?? false,
        feedback: j['feedback'] ?? '',
      );
}

/// Типы событий камеры: код, подпись, иконка — одинаково в ленте и настройках.
class EventLabels {
  static const codes = ['person', 'motion', 'intrusion', 'line', 'tamper', 'sound'];
  static const names = {
    'person': 'Человек',
    'motion': 'Движение',
    'intrusion': 'Вторжение',
    'line': 'Линия',
    'tamper': 'Закрытие объектива',
    'sound': 'Звук',
  };
}
