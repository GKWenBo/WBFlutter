## RowWidget

```dart
Row(
          children: [
            RaisedButton(
                onPressed: () {},
                color: Colors.redAccent,
                child: new Text('红色按钮')),
            Expanded(
                child: RaisedButton(
                    onPressed: () {},
                    color: Colors.cyan,
                    child: new Text('天蓝色按钮'))),
            RaisedButton(
                onPressed: () {}, color: Colors.orange, child: new Text('橙色按钮'))
          ],
        )
```

### 灵活水平布局

解决上面有空隙的问题，可以使用 `Expanded`来进行解决，也就是我们说的灵活布局