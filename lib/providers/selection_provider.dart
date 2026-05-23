import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Multi-select state shared by Home / Grid screens. The screen that owns
/// the active selection sets [scope] so the other screen knows to ignore
/// the selection.
@immutable
class SelectionState {
  const SelectionState({this.active = false, this.ids = const <String>{}});

  final bool active;
  final Set<String> ids;

  int get count => ids.length;

  SelectionState copyWith({bool? active, Set<String>? ids}) =>
      SelectionState(
        active: active ?? this.active,
        ids: ids ?? this.ids,
      );

  static const SelectionState empty = SelectionState();
}

class SelectionNotifier extends Notifier<SelectionState> {
  @override
  SelectionState build() => SelectionState.empty;

  void enter([String? firstId]) {
    state = SelectionState(
      active: true,
      ids: firstId == null ? const {} : {firstId},
    );
  }

  void exit() => state = SelectionState.empty;

  void toggle(String id) {
    final next = {...state.ids};
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    state = state.copyWith(active: true, ids: next);
  }

  void selectAll(Iterable<String> ids) {
    state = SelectionState(active: true, ids: ids.toSet());
  }

  void clear() => state = state.copyWith(ids: const {});
}

final selectionProvider =
    NotifierProvider<SelectionNotifier, SelectionState>(SelectionNotifier.new);
