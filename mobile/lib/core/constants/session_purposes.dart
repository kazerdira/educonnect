/// Types of tutoring session purposes
class SessionPurposes {
  SessionPurposes._();

  static const List<SessionPurposeItem> all = [
    SessionPurposeItem(
      code: 'regular',
      name: 'Cours régulier',
      description: 'Accompagnement continu tout au long de l\'année',
      icon: 'school',
    ),
    SessionPurposeItem(
      code: 'exam_prep',
      name: 'Préparation aux examens',
      description: 'Préparation intensive pour BEM, BAC ou autres examens',
      icon: 'assignment',
    ),
    SessionPurposeItem(
      code: 'revision',
      name: 'Révision rapide',
      description: 'Révision express avant un contrôle ou devoir',
      icon: 'timer',
    ),
    SessionPurposeItem(
      code: 'homework',
      name: 'Aide aux devoirs',
      description: 'Assistance pour comprendre et faire les devoirs',
      icon: 'edit_note',
    ),
    SessionPurposeItem(
      code: 'catch_up',
      name: 'Rattrapage',
      description: 'Remise à niveau sur des chapitres manqués',
      icon: 'trending_up',
    ),
    SessionPurposeItem(
      code: 'advanced',
      name: 'Approfondissement',
      description: 'Aller au-delà du programme scolaire',
      icon: 'star',
    ),
  ];

  static List<String> get codes => all.map((p) => p.code).toList();

  static Map<String, String> get codeToName =>
      {for (var p in all) p.code: p.name};

  static SessionPurposeItem? byCode(String code) {
    try {
      return all.firstWhere((p) => p.code == code);
    } catch (_) {
      return null;
    }
  }
}

class SessionPurposeItem {
  final String code;
  final String name;
  final String description;
  final String icon;

  const SessionPurposeItem({
    required this.code,
    required this.name,
    required this.description,
    required this.icon,
  });
}
