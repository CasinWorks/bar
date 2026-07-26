enum UserRole { member, staff, admin, hr }

class MemberUser {
  const MemberUser({
    required this.id,
    required this.name,
    required this.email,
    required this.birthdate,
    this.role = UserRole.member,
    this.branch,
    this.timeBalanceSeconds = 0,
    this.isBanned = false,
    this.isWhitelisted = false,
    this.activePackageSlug,
    this.includedDrinksRemaining = 0,
    this.includedDrinksTotal = 0,
  });

  final String id;
  final String name;
  final String email;
  final DateTime? birthdate;
  final UserRole role;
  final String? branch;
  final int timeBalanceSeconds;
  final bool isBanned;
  final bool isWhitelisted;
  final String? activePackageSlug;
  final int includedDrinksRemaining;
  final int includedDrinksTotal;

  bool get isStaff => role == UserRole.staff;
  bool get isAdmin => role == UserRole.admin || role == UserRole.hr;
  bool get isMember => role == UserRole.member;

  static UserRole parseRole(String? raw) => switch (raw) {
        'staff' => UserRole.staff,
        'admin' => UserRole.admin,
        'hr' => UserRole.hr,
        _ => UserRole.member,
      };

  bool get isOfAge {
    if (birthdate == null) return isStaff;
    final now = DateTime.now();
    var age = now.year - birthdate!.year;
    if (now.month < birthdate!.month ||
        (now.month == birthdate!.month && now.day < birthdate!.day)) {
      age--;
    }
    return age >= 21;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'birthdate': birthdate?.toIso8601String(),
        'role': role.name,
        'branch': branch,
        'timeBalanceSeconds': timeBalanceSeconds,
        'isBanned': isBanned,
        'isWhitelisted': isWhitelisted,
        'activePackageSlug': activePackageSlug,
        'includedDrinksRemaining': includedDrinksRemaining,
        'includedDrinksTotal': includedDrinksTotal,
      };

  factory MemberUser.fromJson(Map<String, dynamic> json) => MemberUser(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        birthdate: json['birthdate'] != null
            ? DateTime.parse(json['birthdate'] as String)
            : null,
        role: MemberUser.parseRole(json['role'] as String?),
        branch: json['branch'] as String?,
        timeBalanceSeconds: json['timeBalanceSeconds'] as int? ?? 0,
        isBanned: json['isBanned'] as bool? ?? false,
        isWhitelisted: json['isWhitelisted'] as bool? ?? false,
        activePackageSlug: json['activePackageSlug'] as String?,
        includedDrinksRemaining: json['includedDrinksRemaining'] as int? ?? 0,
        includedDrinksTotal: json['includedDrinksTotal'] as int? ?? 0,
      );

  factory MemberUser.fromSupabaseProfile(Map<String, dynamic> json) {
    final birthdateRaw = json['birthdate'] as String?;
    return MemberUser(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      birthdate: birthdateRaw != null ? DateTime.parse(birthdateRaw) : null,
      role: MemberUser.parseRole(json['role'] as String?),
      branch: json['branch'] as String?,
      timeBalanceSeconds: json['time_balance_seconds'] as int? ?? 0,
      isBanned: json['is_banned'] as bool? ?? false,
      isWhitelisted: json['is_whitelisted'] as bool? ?? false,
      activePackageSlug: json['active_package_slug'] as String?,
      includedDrinksRemaining: json['included_drinks_remaining'] as int? ?? 0,
      includedDrinksTotal: json['included_drinks_total'] as int? ?? 0,
    );
  }

  MemberUser copyWith({
    String? name,
    String? branch,
    UserRole? role,
    int? timeBalanceSeconds,
    bool? isBanned,
    bool? isWhitelisted,
    String? activePackageSlug,
    int? includedDrinksRemaining,
    int? includedDrinksTotal,
  }) =>
      MemberUser(
        id: id,
        name: name ?? this.name,
        email: email,
        birthdate: birthdate,
        role: role ?? this.role,
        branch: branch ?? this.branch,
        timeBalanceSeconds: timeBalanceSeconds ?? this.timeBalanceSeconds,
        isBanned: isBanned ?? this.isBanned,
        isWhitelisted: isWhitelisted ?? this.isWhitelisted,
        activePackageSlug: activePackageSlug ?? this.activePackageSlug,
        includedDrinksRemaining:
            includedDrinksRemaining ?? this.includedDrinksRemaining,
        includedDrinksTotal: includedDrinksTotal ?? this.includedDrinksTotal,
      );
}
