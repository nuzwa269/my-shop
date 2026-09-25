/// Groups an exact decimal string without converting financial values to double.
String groupedDecimal(String value) {
  final parts = value.split('.');
  final whole = parts.first.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );
  return parts.length == 1 ? whole : '$whole.${parts[1]}';
}

String friendlyDate(int milliseconds) {
  final date = DateTime.fromMillisecondsSinceEpoch(milliseconds).toLocal();
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
