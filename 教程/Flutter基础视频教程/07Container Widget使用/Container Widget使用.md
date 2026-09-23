## Container

### alignment属性

这个属性针对的是Container内child的对齐方式，也就是容器子内容的对齐方式，并不是容器本身的对齐方式。

- `bottomCenter`:下部居中对齐。
- `botomLeft`: 下部左对齐。
- `bottomRight`：下部右对齐。
- `center`：纵横双向居中对齐。
- `centerLeft`：纵向居中横向居左对齐。
- `centerRight`：纵向居中横向居右对齐。
- `topLeft`：顶部左侧对齐。
- `topCenter`：顶部居中对齐。
- `topRight`： 顶部居左对齐。

```dart
Container(
            child: Text(
              'Hello Wen Mo Bo',
              style: TextStyle(
                  fontSize: 40
              ),
            ),
            alignment: Alignment.center,
          ),
```

### 设置宽、高、颜色属性

```dart
Container(
            child: Text(
              'Hello Wen Mo Bo',
              style: TextStyle(
                  fontSize: 40
              ),
            ),
            alignment: Alignment.center,
            width: 500,
            height: 400,
            color: Colors.purple,
          ),
```

### padding属性

> padding的属性就是一个内边距，它和你使用的前端技术CSS里的`padding`表现形式一样，指的是Container边缘和child内容的距离。

```dart
Container(
            child: Text(
              'Hello Wen Mo Bo',
              style: TextStyle(
                  fontSize: 40
              ),
            ),
            alignment: Alignment.center,
            width: 500,
            height: 400,
            color: Colors.purple,
            padding: const EdgeInsets.all(10.0),
          ),
```

### margin属性

> 不过margin是外边距，只的是container和外部元素的距离。

```dart
 Container(
            child: Text(
              'Hello Wen Mo Bo',
              style: TextStyle(
                  fontSize: 40
              ),
            ),
            alignment: Alignment.center,
            width: 500,
            height: 400,
            color: Colors.purple,
            padding: const EdgeInsets.all(10.0),
            margin: const EdgeInsets.all(10.0),
          ),
```

### decoration

> `decoration`是 container 的修饰器，主要的功能是设置背景和边框。

```dart
Container(
            child: Text(
              'Hello Wen Mo Bo',
              style: TextStyle(
                  fontSize: 40
              ),
            ),
            alignment: Alignment.center,
            width: 500,
            height: 400,
            // color: Colors.purple,
            padding: const EdgeInsets.all(10.0),
            margin: const EdgeInsets.all(10.0),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Colors.lightBlue, Colors.greenAccent, Colors.orange]),
              border: Border.all(width: 2.0, color: Colors.red)
            ),
          ),
```

