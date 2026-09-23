import 'package:json_annotation/json_annotation.dart';

import '../domain/user.dart';

part 'login_response.g.dart';

/// `/auth/login` 的原始响应：DummyJSON 把"用户信息"和"token"拍平在同一个 JSON 里。
/// 单独建这个 DTO（而不是直接复用 [User]），是因为 token 只在登录这一次响应里出现，
/// 之后到处传的都应该是"干净的" User——这是 M2 讲过的 DTO/Entity 分离在这里的体现。
@JsonSerializable()
class LoginResponse {
  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String image;
  final String accessToken;
  final String refreshToken;

  const LoginResponse({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.image,
    required this.accessToken,
    required this.refreshToken,
  });

  /// 剥掉 token，拿到纯粹的展示用 User。
  User toUser() => User(
    id: id,
    username: username,
    email: email,
    firstName: firstName,
    lastName: lastName,
    image: image,
  );

  factory LoginResponse.fromJson(Map<String, dynamic> json) =>
      _$LoginResponseFromJson(json);
  Map<String, dynamic> toJson() => _$LoginResponseToJson(this);
}
