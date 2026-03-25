import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/restaurant_provider.dart';
import 'socket_service.dart';

class RealtimeBinder extends StatefulWidget {
  final Widget child;
  const RealtimeBinder({super.key, required this.child});

  @override
  State<RealtimeBinder> createState() => _RealtimeBinderState();
}

class _RealtimeBinderState extends State<RealtimeBinder> {
  AuthProvider? _auth;
  void Function()? _listener;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthProvider>();
    if (_auth != auth) {
      _detach();
      _auth = auth;
      _listener = () {
        final socket = context.read<SocketService>();
        final restaurant = context.read<RestaurantProvider>();
        if (auth.isAuthenticated && auth.token != null) {
          if (!socket.isConnected) {
            socket.connect(token: auth.token!);
            restaurant.attachRealtime();
          }
        } else {
          if (socket.isConnected) {
            socket.disconnect();
          }
        }
      };
      auth.addListener(_listener!);
      _listener!.call();
    }
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  void _detach() {
    if (_auth != null && _listener != null) {
      _auth!.removeListener(_listener!);
    }
    _auth = null;
    _listener = null;
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

