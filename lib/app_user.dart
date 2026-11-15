class AppUser {
  AppUser({
    required this.uid,
    required this.name,
    required this.role,
    required this.mobile,
    required this.active,
    this.classIds = const <String>[],
  });

  final String uid;
  final String name;
  final String role;
  final String mobile;
  final bool active;
  final List<String> classIds;

  bool get isAdmin => role == 'owner' || role == 'admin';
  bool get isStaff => role == 'owner' || role == 'admin' || role == 'teacher';

  String get roleLabel {
    switch (role) {
      case 'owner':
        return 'Owner';
      case 'admin':
        return 'Admin';
      case 'teacher':
        return 'Teacher';
      default:
        return 'Parent';
    }
  }

  factory AppUser.fromMap(String uid, Map<String, dynamic> d) {
    return AppUser(
      uid: uid,
      name: (d['name'] as String?) ?? '',
      role: (d['role'] as String?) ?? 'parent',
      mobile: (d['mobile'] as String?) ?? '',
      active: d['active'] != false,
      classIds: List<String>.from((d['classIds'] as List?) ?? const <dynamic>[]),
    );
  }
}
