/// Ephemeral HTTPS artwork. Never serialize or log this presigned URI.
class ShopLogo {
  const ShopLogo(this.url, {this.expiresAt});
  final Uri url;
  final DateTime? expiresAt;
}
