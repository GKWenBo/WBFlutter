## GridView

- padding:表示内边距，这个小伙伴们应该很熟悉。
- crossAxisSpacing:网格间的空当，相当于每个网格之间的间距。
- crossAxisCount:网格的列数，相当于一行放置的网格数量。

```dart
class MyGridView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      padding: const EdgeInsets.all(20.0),
      crossAxisSpacing: 10.0,
      children: [
        Text('文波'),
        Text('文波'),
        Text('文波'),
        Text('文波'),
        Text('文波')
      ],
    );
  }
}
```

### 图片网格列表

- childAspectRatio:宽高比，这个值的意思是宽是高的多少倍，如果宽是高的2倍，那我们就写2.0，如果高是宽的2倍，我们就写0.5。

```dart
class MyImageGridView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 2.0,
          crossAxisSpacing: 2.0,
          childAspectRatio: 0.7),
      children: [
        Image.network(
            'http://img5.mtime.cn/mt/2018/10/22/104316.77318635_180X260X4.jpg',
            fit: BoxFit.cover),
        Image.network(
            'http://img5.mtime.cn/mt/2018/10/22/104316.77318635_180X260X4.jpg',
            fit: BoxFit.cover),
        Image.network(
            'http://img5.mtime.cn/mt/2018/10/22/104316.77318635_180X260X4.jpg',
            fit: BoxFit.cover),
        Image.network(
            'http://img5.mtime.cn/mt/2018/10/22/104316.77318635_180X260X4.jpg',
            fit: BoxFit.cover),
        Image.network(
            'http://img5.mtime.cn/mt/2018/10/22/104316.77318635_180X260X4.jpg',
            fit: BoxFit.cover)
      ],
    );
  }
}
```

