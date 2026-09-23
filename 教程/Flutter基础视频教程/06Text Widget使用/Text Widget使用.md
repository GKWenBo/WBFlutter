### textAlign属性

- center: 文本以居中形式对齐,这个也算比较常用的了。
- left:左对齐，经常使用，让文本居左进行对齐，效果和start一样。
- right :右对齐，使用频率也不算高。
- start:以开始位置进行对齐，类似于左对齐。
- end: 以为本结尾处进行对齐，不常用。有点类似右对齐.

```dart
child: Text(
            'Hello 文波 Hello 文波 Hello 文波 Hello 文波 Hello 文波 Hello 文波 Hello 文波 Hello 文波',
            textAlign: TextAlign.center,
            maxLines: 1,
          )
```

### maxLines

设置最多显示的行数，比如我们现在只显示1行，类似一个新闻列表的题目。代码如下：

```dart
Text(
            'Hello 文波 Hello 文波 Hello 文波 Hello 文波 Hello 文波 Hello 文波 Hello 文波 Hello 文波',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          )
```

### Overflow属性

overflow属性是用来设置文本溢出时，如何处理,它有下面几个常用的值供我们选择。

- clip：直接切断，剩下的文字就没有了，感觉不太友好，体验性不好。
- ellipsis:在后边显示省略号，体验性较好，这个在工作中经常使用。
- fade: 溢出的部分会进行一个渐变消失的效果，当然是上线的渐变，不是左右的哦。

```dart
Text(
            'Hello 文波 Hello 文波 Hello 文波 Hello 文波 Hello 文波 Hello 文波 Hello 文波 Hello 文波',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          )
```

### style属性

```dart
Text(
            'Hello 文波 Hello 文波 Hello 文波 Hello 文波 Hello 文波 Hello 文波 Hello 文波 Hello 文波',
            textAlign: TextAlign.center,
            // maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 36,
              color: Color.fromARGB(255, 255, 150, 150),
              backgroundColor: Colors.blue,
              decorationColor: Colors.cyan,
              decoration: TextDecoration.underline,
              decorationStyle: TextDecorationStyle.solid
            )
```

