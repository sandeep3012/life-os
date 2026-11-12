import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/router/app_router.dart';
import 'package:life_manager/app/router/route_paths.dart';

void main() {
  test('the sign-in return link and a bare "/" never reach "Page Not Found"', () {
    expect(
      offRouteRedirect(Uri.parse('lifeos://auth-callback/?code=edb2d57a')),
      RoutePaths.sync,
    );
    expect(offRouteRedirect(Uri.parse('/auth-callback?code=x')), RoutePaths.sync);
    expect(offRouteRedirect(Uri.parse('/')), RoutePaths.home);
    expect(offRouteRedirect(Uri.parse('')), RoutePaths.home);
    // Real screens are left alone.
    expect(offRouteRedirect(Uri.parse(RoutePaths.home)), isNull);
    expect(offRouteRedirect(Uri.parse(RoutePaths.sync)), isNull);
    expect(offRouteRedirect(Uri.parse(RoutePaths.settings)), isNull);
  });
}
