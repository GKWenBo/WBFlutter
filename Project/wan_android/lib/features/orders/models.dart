// 跨模块模型入口：仅导出业务类型，不暴露状态或装配。
export 'domain/order.dart' show Order, OrderItem, OrderStatus, ShippingAddress;
