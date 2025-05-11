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

  // In your FeedExpenseProvider class
  Future<void> deductFeedQuantity(String feedId, double amount) async {
    final feedBox = await Hive.openBox<Feed>('feedsBox');
    final feed = feedBox.get(feedId);

    if (feed != null) {
      feed.deductFeed(amount);
      await feedBox.put(feed.id, feed);
      notifyListeners(); // This triggers UI updates
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
      feedId: feed.id, // Link expense to feed using feed's ID
    );

    // Save expense first
    await _expensesBox.put(expense.id, expense);

    // Update feed with expense ID and save
    final updatedFeed = feed.copyWith(expenseId: expense.id);
    await _feedsBox.put(updatedFeed.id, updatedFeed);

    notifyListeners();
  }

  // Update a feed and its corresponding expense using feed ID
  Future<void> updateFeedWithExpense(Feed updatedFeed) async {
    // Get the existing feed to check for changes
    final oldFeed = _feedsBox.get(updatedFeed.id);
    if (oldFeed == null) return;

    // Update the feed
    await _feedsBox.put(updatedFeed.id, updatedFeed);

    // Update the corresponding expense if it exists
    if (oldFeed.expenseId != null) {
      final expense = _expensesBox.get(oldFeed.expenseId!);
      if (expense != null) {
        final updatedExpense = expense.copyWith(
          name: "Feed Purchase: ${updatedFeed.name}",
          amount: updatedFeed.price,
          date: updatedFeed.purchaseDate,
          description:
              "Purchased ${updatedFeed.quantity}kg of ${updatedFeed.name} from ${updatedFeed.supplier}",
        );
        await _expensesBox.put(updatedExpense.id, updatedExpense);
      }
    }
    notifyListeners();
  }

  // Delete a feed using its ID
  Future<void> deleteFeed(Feed feedToDelete) async {
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
    }

    // Now delete the feed
    await _feedsBox.delete(feedToDelete.id);

    notifyListeners();
  }

  // Update an expense and its corresponding feed (if it's a feed expense)
  Future<void> updateExpense(Expense expense) async {
    await _expensesBox.put(expense.id, expense);

    // If this is a feed expense, update the corresponding feed
    if (expense.category == 'Feed' && expense.feedId != null) {
      final feed = _feedsBox.get(expense.feedId!);
      if (feed != null) {
        final updatedFeed = feed.copyWith(
          name: expense.name.replaceFirst('Feed Purchase: ', ''),
          price: expense.amount,
          purchaseDate: expense.date,
          supplier: extractSupplierFromDescription(expense.description ?? ''),
        );
        await _feedsBox.put(updatedFeed.id, updatedFeed);
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
      if (feed != null && feed.expenseId == expenseId) {
        await _feedsBox.put(feed.id, feed.copyWith(expenseId: null));
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

  // Helper method to get feed by ID
  Feed? getFeedById(String id) {
    return _feedsBox.get(id);
  }

  // Getters for the boxes
  Box<Feed> get feedsBox => _feedsBox;
  Box<Expense> get expensesBox => _expensesBox;
}
