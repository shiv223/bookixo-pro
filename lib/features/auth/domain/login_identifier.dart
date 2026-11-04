/// Matches staff signin normalization without changing the submitted identifier.
abstract final class LoginIdentifier {
  static bool isValid(String value) {
    final input = value.trim();
    if (RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(input)) return true;
    var phone = input.replaceAll(RegExp(r'[ ()-]'), '');
    if (RegExp(r'^[6-9][0-9]{9}$').hasMatch(phone)) {
      phone = '+91$phone';
    } else if (RegExp(r'^91[6-9][0-9]{9}$').hasMatch(phone)) {
      phone = '+$phone';
    }
    return RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(phone) &&
        (!phone.startsWith('+91') ||
            RegExp(r'^\+91[6-9][0-9]{9}$').hasMatch(phone));
  }
}
