# WBFlutter
### 开发文档

[Flutter 开发文档](https://docs.flutter.cn/)

[《Flutter实战·第二版》](https://book.flutterchina.club/)、

### 环境搭建

#### iOS

- 下载Flutter SDK

  https://docs.flutter.dev/release/archive

  将压缩包解压到`~/development`目录下

- 配置环境变量

  ```
  # 复制以下内容并粘贴到 ~/.zshenv 文件内的末尾
  export PATH=$HOME/development/flutter/bin:$PATH
  ```

- Flutter doctor检查环境是否配置成功

  ```
  flutter doctor -v
  ```

- Visual Studio Code配置Flutter插件

  [Flutter](https://marketplace.visualstudio.com/items?itemName=Dart-Code.flutter)

  [Code Runner](https://marketplace.visualstudio.com/items?itemName=formulahendry.code-runner) 
  
  [Flutter Widget Snippets](https://marketplace.cursorapi.com/items?itemName=alexisvt.flutter-snippets)

### 常用命令

- 新建项目

  > flutter create 项目名称

- 运行项目

  > flutter run
  >
  > flutter run 设备id

- 构建APK

  > flutter build apk

- 构建iOS应用

  > flutter build iOS

- 查看flutter版本

  > flutter --version

- 更新flutter

  > flutter upgrade

- 检查flutter环境

  > flutter doctor

- 列出可用设备

  > flutter devices

- 安装依赖

  > flutter pub get

### 组件

- Center
- Container
- Column：垂直线性布局组件
- Row：横向线性布局组件
- Padding：支持设置内边距
- Expanded：Flex弹性布局
- Flex：弹性布局
