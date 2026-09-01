class AppConfig {
  const AppConfig({
    required this.useFirebase,
    required this.useDemoData,
    required this.defaultWarehouseId,
    required this.supportMultipleWarehouses,
  });

  final bool useFirebase;
  final bool useDemoData;
  final String defaultWarehouseId;
  final bool supportMultipleWarehouses;

  static const AppConfig development = AppConfig(
    useFirebase: false,
    useDemoData: true,
    defaultWarehouseId: 'katargam',
    supportMultipleWarehouses: false,
  );

  static const AppConfig production = AppConfig(
    useFirebase: true,
    useDemoData: false,
    defaultWarehouseId: 'katargam',
    supportMultipleWarehouses: true,
  );
}
