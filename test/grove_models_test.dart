import 'package:flutter_test/flutter_test.dart';
import 'package:hobbyquest/app/models/tree_model.dart';
import 'package:hobbyquest/app/models/user_model.dart';

void main() {
  test('legacy trees default to Grove 1', () {
    final tree = TreeModel.fromJson({'treeName': 'Legacy Oak', 'treeIndex': 4});

    expect(tree.groveIndex, 1);
    expect(tree.toJson()['groveIndex'], 1);
  });

  test('user grove slots preserve legacy data and serialize new groves', () {
    final legacyUser = UserModel.fromJson({
      'totalXP': 0,
      'occupiedTreeSlots': [0, 2, 4],
    }, 'user-1');

    expect(legacyUser.currentGroveIndex, 1);
    expect(legacyUser.occupiedTreeSlotsByGrove[1], [0, 2, 4]);

    final updated = legacyUser.copyWith(
      currentGroveIndex: 2,
      completedGroveIndexes: const [1],
      occupiedTreeSlotsByGrove: const {
        1: [0, 1, 2, 3, 4, 5, 6, 7, 8],
        2: [0],
      },
    );

    expect(updated.toJson()['currentGroveIndex'], 2);
    expect(updated.toJson()['completedGroveIndexes'], [1]);
    expect(updated.toJson()['occupiedTreeSlotsByGrove'], {
      '1': [0, 1, 2, 3, 4, 5, 6, 7, 8],
      '2': [0],
    });
  });
}
