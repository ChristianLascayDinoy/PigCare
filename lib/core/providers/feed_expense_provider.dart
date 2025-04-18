import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pigcare/core/models/expense_model.dart';
import 'package:pigcare/core/models/feed_model.dart';

class FeedExpenseProvider with ChangeNotifier {
  late Box<Feed> _feedsBox;
  late Box<Expense> _expensesBox;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (!_isInitialized) {
      if (!Hive.isAdapterRegistered(FeedAdapter().typeId)) {
        Hive.registerAdapter(FeedAdapter());
      }
      if (!Hive.isAdapterRegistered(ExpenseAdapter().typeId)) {
        Hive.registerAdapter(ExpenseAdapter());
      }

      _feedsBox = await Hive.openBox<Feed>('feedsBox');
      _expensesBox = await Hive.openBox<Expense>('expenses');
      _isInitialized = true;
    }
  }

  // Add a new feed and its corresponding expense
  Future<void> addFeedWithExpense(Feed feed) async {
    final expense = Expense(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: "Feed Purchase: ${feed.name}",
      amount: feed.price,
      date: feed.purchaseDate,
      category: 'Feed',
      description:
          "Purchased ${feed.quantity}kg of ${feed.name} from ${feed.supplier}",
      pigTags: [],
      feedId: feed.expenseId, // Link expense to feed
    );

    // Save expense first to get its ID
    await _expensesBox.put(expense.id, expense);

    // Update feed with expense ID
    final updatedFeed = feed.copyWith(expenseId: expense.id);
    await _feedsBox.put(updatedFeed.expenseId, updatedFeed);

    notifyListeners();
  }

  // Update a feed and its corresponding expense
  Future<void> updateFeedWithExpense(int feedIndex, Feed updatedFeed) async {
    final oldFeed = _feedsBox.getAt(feedIndex);
    if (oldFeed == null) return;

    await _feedsBox.putAt(feedIndex, updatedFeed);

    // Find and update the corresponding expense
    final expenses = _expensesBox.values.toList();
    for (int i = 0; i < expenses.length; i++) {
      final expense = expenses[i];
      if (expense.name.contains("Feed Purchase: ${oldFeed.name}") &&
          expense.date == oldFeed.purchaseDate) {
        final updatedExpense = expense.copyWith(
          name: "Feed Purchase: ${updatedFeed.name}",
          amount: updatedFeed.price,
          date: updatedFeed.purchaseDate,
          description:
              "Purchased ${updatedFeed.quantity}kg of ${updatedFeed.name} from ${updatedFeed.supplier}",
        );
        await _expensesBox.putAt(i, updatedExpense);
        break;
      }
    }
    notifyListeners();
  }

  Future<void> deleteFeed(int index) async {
    final feedToDelete = _feedsBox.getAt(index);
    if (feedToDelete == null) return;

    // Remove the expense link from the feed (but don't delete the expense)
    if (feedToDelete.expenseId != null) {
      // Get the expense
      final expense = _expensesBox.get(feedToDelete.expenseId!);
      if (expense != null) {
        // Remove the feed reference from the expense
        await _expensesBox.put(
          expense.id,
          expense.copyWith(feedId: null),
        );
      }

      // Update the feed to remove expense reference
      await _feedsBox.putAt(
        index,
        feedToDelete.copyWith(expenseId: null),
      );
    }

    // Now delete the feed
    await _feedsBox.deleteAt(index);

    notifyListeners();
  }

  // Update an expense and its corresponding feed (if it's a feed expense)
  Future<void> updateExpense(Expense expense) async {
    await _expensesBox.put(expense.id, expense);

    // If this is a feed expense, update the corresponding feed
    if (expense.category == 'Feed' &&
        expense.name.startsWith('Feed Purchase:')) {
      final feedName = expense.name.replaceFirst('Feed Purchase: ', '');
      final feeds = _feedsBox.values.toList();

      for (int i = 0; i < feeds.length; i++) {
        final feed = feeds[i];
        if (feed.name == feedName && feed.purchaseDate == expense.date) {
          final updatedFeed = feed.copyWith(
            name: feedName,
            price: expense.amount,
            purchaseDate: expense.date,
            supplier: extractSupplierFromDescription(expense.description ?? ''),
          );
          await _feedsBox.putAt(i, updatedFeed);
          break;
        }
      }
    }
    notifyListeners();
  }

  // Delete an expense and its corresponding feed (if it's a feed expense)
  Future<void> deleteExpense(String expenseId) async {
    final expense = _expensesBox.get(expenseId);
    if (expense == null) return;

    // If this expense is linked to a feed, remove the link
    if (expense.feedId != null) {
      final feed = _feedsBox.get(expense.feedId!);
      if (feed != null) {
        await _feedsBox.put(feed.expenseId, feed.copyWith(expenseId: null));
      }
    }

    // Delete the expense
    await _expensesBox.delete(expenseId);

    notifyListeners();
  }

  // Helper method to extract supplier from description
  String extractSupplierFromDescription(String description) {
    final pattern = RegExp(r'from (.*?)$');
    final match = pattern.firstMatch(description);
    return match?.group(1) ?? 'Unknown Supplier';
  }

  // Getters for the boxes
  Box<Feed> get feedsBox => _feedsBox;
  Box<Expense> get expensesBox => _expensesBox;
}
