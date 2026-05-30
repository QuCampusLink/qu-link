/// Convex deployment configuration for the driver app.
///
/// After running `npx convex dev` at the repo root, paste your deployment
/// URL here (e.g. https://happy-animal-123.convex.cloud).
class QuConvexConfig {
  static const String deploymentUrl =
      String.fromEnvironment('CONVEX_URL', defaultValue: 'https://perfect-curlew-934.convex.cloud');

  static const String clientId = 'qu-bus-driver';
}
