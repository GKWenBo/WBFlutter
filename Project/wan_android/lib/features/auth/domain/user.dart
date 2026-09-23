import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

/// 登录用户信息 ≈ 你 iOS 里的 User/Profile model（Codable struct）。
/// 只放"展示用"的字段，token 不放这里——token 是"鉴权凭证"，属于 [LoginResponse]/安全存储的职责，
/// 混进 User 会导致"打印用户信息"这种无害操作也可能意外带出敏感数据。
@JsonSerializable()
class User {
  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String image;

  const User({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.image,
  });

  String get fullName => '$firstName $lastName';

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);
}
