import 'package:flutter/material.dart';

import '../transient_snack_bar.dart';

final RouteObserver<ModalRoute<void>> appRouteObserver =
    RouteObserver<ModalRoute<void>>();

mixin HideTransientSnackBarOnRouteChange<T extends StatefulWidget> on State<T>
    implements RouteAware {
  ModalRoute<dynamic>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    if (_route == route) {
      return;
    }
    if (_route is PageRoute<dynamic>) {
      appRouteObserver.unsubscribe(this);
    }
    _route = route;
    if (route is PageRoute<dynamic>) {
      appRouteObserver.subscribe(this, route as PageRoute<void>);
    }
  }

  @override
  void didPushNext() {
    clearTransientSnackBar(context);
  }

  @override
  void didPush() {}

  @override
  void didPop() {}

  @override
  void didPopNext() {}

  @override
  void dispose() {
    if (_route is PageRoute<dynamic>) {
      appRouteObserver.unsubscribe(this);
    }
    super.dispose();
  }
}
