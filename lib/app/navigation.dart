import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Index of the selected tab in the root shell (Home, Music, Playlists, Settings).
final rootTabProvider = NotifierProvider<RootTabController, int>(
  RootTabController.new,
  isAutoDispose: false,
);

class RootTabController extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) {
    if (index >= 0 && index < 4) state = index;
  }
}
