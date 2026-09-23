import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers/auth_providers.dart';

/// 登录页。≈ 你 iOS 里的 LoginViewController：一个 Form + 两个输入框 + 一个提交按钮。
///
/// 用 ConsumerStatefulWidget 而不是 ConsumerWidget：TextEditingController 是"要手动 dispose
/// 的可变资源"，这类状态必须放在 State 里管理（呼应 M5 详情页轮播图 _DetailGallery 的取舍）。
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  // GlobalKey<FormState> ≈ 你给 UIView 挂的一个"校验器句柄"：
  // 通过它可以在提交时统一触发所有 TextFormField 的 validator。
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController(text: 'emilys');
  final _passwordController = TextEditingController(text: 'emilyspass');

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // validate() 会跑一遍所有 TextFormField 的 validator，全部通过才返回 true。
    if (!_formKey.currentState!.validate()) return;

    await ref
        .read(authProvider.notifier)
        .login(_usernameController.text.trim(), _passwordController.text);

    if (!mounted) return;
    final state = ref.read(authProvider);
    if (state.hasError) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('登录失败：${state.error}')));
    } else if (state.asData?.value != null) {
      // 登录成功：主动去"我的"。go_router 的 redirect 会再检查一遍，
      // 这时 isLoggedIn 已经是 true，不会被再次拦回登录页。
      context.go('/profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    // watch 而不是 read：登录请求进行中 authProvider 会先变成 AsyncLoading，
    // 按钮需要跟着这个状态显示"转圈"、禁止重复点击。
    final isSubmitting = ref.watch(authProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('登录')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                Text(
                  'WanShop',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '测试账号：emilys / emilyspass',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: '用户名',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  // validator 返回非 null 就是"校验失败的提示文案"，返回 null 代表通过。
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? '请输入用户名' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true, // ≈ UITextField.isSecureTextEntry
                  decoration: const InputDecoration(
                    labelText: '密码',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (value) =>
                      (value == null || value.isEmpty) ? '请输入密码' : null,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: isSubmitting ? null : _submit,
                  child: isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('登录'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
