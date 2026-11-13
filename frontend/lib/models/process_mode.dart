/// Where a photo should be processed. Only the server model exists today;
/// `auto` and `device` both run on the server until an on-device model ships.
enum ProcessMode {
  auto('Auto'),
  server('Server'),
  device('On-device');

  final String label;

  const ProcessMode(this.label);

  static ProcessMode fromName(String? name) =>
      ProcessMode.values.firstWhere((m) => m.name == name, orElse: () => ProcessMode.auto);

  /// The mode that actually runs, given what's available.
  String get resolved => 'server';

  static const bool onDeviceAvailable = false;
}
