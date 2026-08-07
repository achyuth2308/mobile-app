import 'package:equatable/equatable.dart';

import 'json_utils.dart';

class AppUser extends Equatable {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.role = 'customer',
    this.orgId = '',
    this.orgName = '',
    this.avatarUrl,
    this.timezone,
    this.createdAt,
  });

  final String id;
  final String name;
  final String email;
  final String? phone;
  final String role;
  final String orgId;
  final String orgName;
  final String? avatarUrl;
  final String? timezone;
  final DateTime? createdAt;

  String get initials {
    final List<String> parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return email.isNotEmpty ? email[0].toUpperCase() : 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> src =
        json['user'] is Map<String, dynamic> ? json['user'] as Map<String, dynamic> : json;
    final Map<String, dynamic> org = asMap(src, <String>[
      'org', 'organization', 'organisation', 'tenant', 'company',
    ]);

    return AppUser(
      id: asString(src, <String>['_id', 'id', 'userId']),
      name: asString(src, <String>['name', 'fullName', 'username', 'displayName'],
          fallback: 'Customer'),
      email: asString(src, <String>['email', 'emailAddress']),
      phone: asStringOrNull(src, <String>['phone', 'mobile', 'phoneNumber', 'contact']),
      role: asString(src, <String>['role', 'userRole', 'type'], fallback: 'customer')
          .toLowerCase(),
      orgId: asString(src, <String>['orgId', 'organizationId', 'organisationId', 'tenantId'])
              .isNotEmpty
          ? asString(src, <String>['orgId', 'organizationId', 'organisationId', 'tenantId'])
          : asString(org, <String>['_id', 'id']),
      orgName: asString(org, <String>['name', 'orgName', 'companyName']).isNotEmpty
          ? asString(org, <String>['name', 'orgName', 'companyName'])
          : asString(src, <String>['orgName', 'companyName']),
      avatarUrl: asStringOrNull(src, <String>['avatar', 'avatarUrl', 'photo', 'profileImage']),
      timezone: asStringOrNull(src, <String>['timezone', 'timeZone', 'tz']),
      createdAt: asDate(src, <String>['createdAt', 'created_at', 'joinedAt']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        '_id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'role': role,
        'orgId': orgId,
        'orgName': orgName,
        'avatar': avatarUrl,
        'timezone': timezone,
        'createdAt': createdAt?.toIso8601String(),
      };

  AppUser copyWith({
    String? name,
    String? email,
    String? phone,
    String? avatarUrl,
    String? timezone,
  }) =>
      AppUser(
        id: id,
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        role: role,
        orgId: orgId,
        orgName: orgName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        timezone: timezone ?? this.timezone,
        createdAt: createdAt,
      );

  @override
  List<Object?> get props =>
      <Object?>[id, name, email, phone, role, orgId, orgName, avatarUrl];
}
