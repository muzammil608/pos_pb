import 'package:pocketbase/pocketbase.dart';

class UserModel {
  final String id;
  final String email;
  final String role;
  final String? adminId;
  final bool isActive;
  final String? name;
  final String? photoUrl;

  UserModel({
    required this.id,
    required this.email,
    required this.role,
    this.adminId,
    this.isActive = true,
    this.name,
    this.photoUrl,
  });

  String get effectiveAdminId => role == 'admin' ? id : (adminId ?? id);

  bool get isAdmin => role == 'admin';
  String get uid => id;
  String? get displayName => name;
  String? get photoURL => photoUrl;

  factory UserModel.fromRecord(RecordModel record) {
    return UserModel(
      id: record.id,
      email: record.getStringValue('email'),
      role: record.getStringValue('role').isEmpty
          ? 'cashier'
          : record.getStringValue('role'),
      adminId: record.getStringValue('adminId').isEmpty
          ? null
          : record.getStringValue('adminId'),
      isActive: record.data.containsKey('isActive')
          ? record.getBoolValue('isActive')
          : true,
      name: record.getStringValue('name').isEmpty
          ? null
          : record.getStringValue('name'),
      photoUrl: record.getStringValue('photoUrl').isNotEmpty
          ? record.getStringValue('photoUrl')
          : (record.getStringValue('avatar').isEmpty
              ? null
              : record.getStringValue('avatar')),
    );
  }

  factory UserModel.fromMap(Map<String, dynamic> data, String id) {
    return UserModel(
      id: id,
      email: data['email'] ?? '',
      role: data['role'] ?? 'cashier',
      adminId: data['adminId'],
      isActive: data['isActive'] ?? true,
      name: data['name'],
      photoUrl: data['photoUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'role': role,
      'isActive': isActive,
      if (adminId != null) 'adminId': adminId,
      if (name != null) 'name': name,
      if (photoUrl != null) 'photoUrl': photoUrl,
    };
  }
}
