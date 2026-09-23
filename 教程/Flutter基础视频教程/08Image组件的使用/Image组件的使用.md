## Image

### 加载图片资源方式

- **Image.asset**:加载资源图片，就是加载项目资源目录中的图片,加入图片后会增大打包的包体体积，用的是相对路径。
- **Image.network**:网络资源图片，意思就是你需要加入一段[http://xxxx.xxx的这样的网络路径地址。](http://xxxx.xn--xxx-lq6eyc874dnzo140aba474s0eb988h4gf./)
- **Image.file**:加载本地图片，就是加载本地文件中的图片，这个是一个绝对路径，跟包体无关。
- **Image.memory**: 加载Uint8List资源图片,这个我目前用的不是很多，所以没什么发言权。

### fit属性设置

fit属性可以控制图片的拉伸和挤压，这些都是根据图片的父级容器来的，我们先来看看这些属性（建议此部分组好看视频理解）。

- **BoxFit.fill**:全图显示，图片会被拉伸，并充满父容器。
- **BoxFit.contain**:全图显示，显示原比例，可能会有空隙。
- **BoxFit.cover**：显示可能拉伸，可能裁切，充满（图片要充满整个容器，还不变形）。
- **BoxFit.fitWidth**：宽度充满（横向充满），显示可能拉伸，可能裁切。
- **BoxFit.fitHeight** ：高度充满（竖向充满）,显示可能拉伸，可能裁切。
- **BoxFit.scaleDown**：效果和contain差不多，但是此属性不允许显示超过源图片大小，可小不可大。

### 图片混合模式

图片混合模式（colorBlendMode）和color属性配合使用，能让图片改变颜色，里边的模式非常的多，产生的效果也是非常丰富的。

```dart
Image.network(
            'https://book.flutterchina.club/assets/img/book.17ed07e5.png',
            scale: 1.0,
            fit: BoxFit.contain,
            colorBlendMode: BlendMode.darken,
          ),
```

### repeat图片重复

- ImageRepeat.repeat : 横向和纵向都进行重复，直到铺满整个画布。
- ImageRepeat.repeatX: 横向重复，纵向不重复。
- ImageRepeat.repeatY：纵向重复，横向不重复。

```dart
Image.network(
            'https://book.flutterchina.club/assets/img/book.17ed07e5.png',
            scale: 1.0,
            fit: BoxFit.contain,
            colorBlendMode: BlendMode.darken,
            repeat: ImageRepeat.repeat,
          ),
```

