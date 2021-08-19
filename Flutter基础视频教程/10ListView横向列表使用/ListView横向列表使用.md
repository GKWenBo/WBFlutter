### 横向列表

```dart
class HorizontalList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      scrollDirection: Axis.horizontal,
      children: [
        Container(
          width: 220,
          color: Colors.orange,
        ),
        Container(
          width: 220,
          color: Colors.cyan,
        ),
        Container(
          width: 220,
          color: Colors.purple,
        )
      ],
    );
  }
}
```

### scrollDirection属性

ListView组件的`scrollDirection`属性只有两个值，一个是横向滚动，一个是纵向滚动。默认的就是垂直滚动，所以如果是垂直滚动，我们一般都不进行设置。

- Axis.horizontal:横向滚动或者叫水平方向滚动。
- Axis.vertical:纵向滚动或者叫垂直方向滚动。