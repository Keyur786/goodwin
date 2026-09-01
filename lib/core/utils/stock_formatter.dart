/// Formats available inventory quantities cleanly for retail customers and admins.
String formatStockCount(int count, {bool isAdmin = false}) {
  if (count <= 0) return '0';
  if (isAdmin) return '$count';
  if (count >= 50) return '50+';
  if (count >= 20) return '20+';
  if (count >= 10) return '10+';
  return '$count';
}
