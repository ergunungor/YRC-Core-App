// Sadece temel Dart mantığı kullanılacağı için ekstra kütüphaneye gerek yok.

/// YRC Core Event Types.
/// Supabase veritabanındaki CHECK constraint ile birebir eşleşmelidir.
enum EventType { longRun, socialRun, interval, tempo, recovery, race }

/// Enum'ı veritabanı formatına ve UI formatına çevirmek için extension yazıyoruz.
/// Bu sayede 'EventType.longRun.dbValue' şeklinde temiz bir kullanım elde edeceğiz.
extension EventTypeExtension on EventType {
  /// Supabase veritabanına kaydedilecek değer (CHECK constraint formatı)
  String get dbValue {
    switch (this) {
      case EventType.longRun:
        return 'LONG_RUN';
      case EventType.socialRun:
        return 'SOCIAL_RUN';
      case EventType.interval:
        return 'INTERVAL';
      case EventType.tempo:
        return 'TEMPO';
      case EventType.recovery:
        return 'RECOVERY';
      case EventType.race:
        return 'RACE';
    }
  }

  /// Kullanıcıya arayüzde (Dropdown, Event Card Badge) gösterilecek değer
  String get uiLabel {
    switch (this) {
      case EventType.longRun:
        return 'Long Run';
      case EventType.socialRun:
        return 'Social Run';
      case EventType.interval:
        return 'Interval';
      case EventType.tempo:
        return 'Tempo';
      case EventType.recovery:
        return 'Recovery';
      case EventType.race:
        return 'Race';
    }
  }
}

/// Veritabanından gelen string değeri tekrar EventType enum'ına çevirmek için yardımcı sınıf.
/// Listeleme ekranında (Event List Screen) verileri çekerken çok işimize yarayacak.
class EventTypeHelper {
  /// DB'den gelen değeri Enum'a çevirir.
  /// Eğer tanımlanamayan bir değer gelirse, fallback olarak 'socialRun' döndürür
  /// (Uygulamanın çökmesini / null reference hatasını önler).
  static EventType fromDbValue(String dbValue) {
    switch (dbValue) {
      case 'LONG_RUN':
        return EventType.longRun;
      case 'SOCIAL_RUN':
        return EventType.socialRun;
      case 'INTERVAL':
        return EventType.interval;
      case 'TEMPO':
        return EventType.tempo;
      case 'RECOVERY':
        return EventType.recovery;
      case 'RACE':
        return EventType.race;
      default:
        // Hatalı/Bozuk data durumunda uygulamayı crash etmek yerine default değer veriyoruz.
        return EventType.socialRun;
    }
  }

  /// UI formlarında dropdown vb. yerlerde kolay kullanım için tüm tiplerin listesini verir.
  static List<EventType> get allTypes => EventType.values;
}
