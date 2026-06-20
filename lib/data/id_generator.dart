String newLocalId([String prefix = 'local']) {
  final now = DateTime.now().toUtc();
  return '$prefix-${now.microsecondsSinceEpoch}';
}

