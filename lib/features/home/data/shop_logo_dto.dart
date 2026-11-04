import '../../../core/errors/app_failure.dart';
import '../domain/shop_logo.dart';

/// Strict status/body contract; file extensions are not an image decoder.
class ShopLogoDto {
  const ShopLogoDto(this.logo);
  final ShopLogo? logo;
  static ShopLogoDto parse(int? status, Object? body) {
    if (status == 204) return const ShopLogoDto(null);
    if (status != 200 || body is! Map<String, Object?>) {
      throw const ContractFailure();
    }
    final value = body['logoUrl'];
    if (value is! String ||
        value.isEmpty ||
        value.contains(RegExp(r'\s')) ||
        RegExp(r'%(?![0-9a-fA-F]{2})').hasMatch(value)) {
      throw const ContractFailure();
    }
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        !_validHost(uri.host) ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      throw const ContractFailure();
    }
    return ShopLogoDto(ShopLogo(uri, expiresAt: _expiry(uri)));
  }

  static bool _validHost(String host) =>
      host.length <= 253 &&
      host
          .split('.')
          .every(
            (label) =>
                label.length <= 63 &&
                RegExp(r'^[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?$')
                    .hasMatch(label),
          );

  static DateTime? _expiry(Uri uri) {
    final date = uri.queryParameters['X-Amz-Date'];
    final seconds = int.tryParse(uri.queryParameters['X-Amz-Expires'] ?? '');
    if (date == null ||
        seconds == null ||
        seconds <= 0 ||
        seconds > 604800 ||
        !RegExp(r'^\d{8}T\d{6}Z$').hasMatch(date)) {
      return null;
    }
    final start = DateTime.tryParse(
      '${date.substring(0, 4)}-${date.substring(4, 6)}-${date.substring(6, 8)}'
      'T${date.substring(9, 11)}:${date.substring(11, 13)}:${date.substring(13, 15)}Z',
    );
    return start?.add(Duration(seconds: seconds));
  }
}
