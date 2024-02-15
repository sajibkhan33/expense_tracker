import 'package:expensetracker/models/expense.dart';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

class ExpenseDatabase extends ChangeNotifier {
  static late Isar isar;
  List<Expense> _allExpenses = [];

  /*
  S E T U P
  */

//initialize database(in short form db)
  static Future<void> initialize() async {
    final dir = await getApplicationDocumentsDirectory();
    isar = await Isar.open([ExpenseSchema], directory: dir.path);
  }

  /*
  G E T T E R S
  */
  List<Expense> get allExpense => _allExpenses;
  /*
  O P E R A T I O N S
  */

//create - add a new espense
  Future<void> createNewExpense(Expense newExpense) async {
    //add to db
    await isar.writeTxn(() => isar.expenses.put(newExpense));
    //re-read from db
    await readExpenses();
  }

//Read -expense from db
  Future<void> readExpenses() async {
    //fetch allexisting expenses from db
    List<Expense> fetchedExpenses = await isar.expenses.where().findAll();
    //give to local expense list
    _allExpenses.clear();
    _allExpenses.addAll(fetchedExpenses);
    //update UI
    notifyListeners();
  }

//update - edit anexpense in db
  Future<void> updateExpense(int id, Expense updateExpense) async {
    //make sure new expense has same id as esisting one
    updateExpense.id = id;

    //update in db
    await isar.writeTxn(() => isar.expenses.put(updateExpense));

    //re-read from db
    await readExpenses();
  }

//delete -an expense
  Future<void> deleteExpense(int id) async {
    //delete from db
    await isar.writeTxn(() => isar.expenses.delete(id));
    //re-read from db
    await readExpenses();
  }
/*
  H E L P E R
  */

  //calculate total expenses for each month
  /*
  year - month
  {
   2024-0:$250, jan
    2024-1:$200, feb
    2024-2:$175, mar
    ....
    2024-11:$240 dec
    2025-0:$300 jan
  }
  */
  Future<Map<String, double>> clculateMonthlyTotals() async {
    //ensure the expenses are read from db
    await readExpenses();
    //create a map to keep of total expenses per month,year
    Map<String, double> monthlyTotals = {};

    //iterate overall expenses
    for (var expense in _allExpenses) {
      //extract the year & month from the date of expense
      String yearMonth = '${expense.date.year}-${expense.date.month}';

      //if the year-month is not yet in the map,initialize to 0
      if (!monthlyTotals.containsKey(yearMonth)) {
        monthlyTotals[yearMonth] = 0;
      }
      //add the expense amount to the total for the month
      monthlyTotals[yearMonth] = monthlyTotals[yearMonth]! + expense.amount;
    }
    return monthlyTotals;
  }

//calculate current month total
  Future<double> calculateCurrentMonthTotal() async {
    //current expenses are read from db
    await readExpenses();
    //get current month,year
    int currentMonth = DateTime.now().month;
    int currentYear = DateTime.now().year;
    //filter the expenses to include only those for this month this year
    List<Expense> currentMonthExpenses = _allExpenses.where((expense) {
      return expense.date.month == currentMonth &&
          expense.date.year == currentYear;
    }).toList();
    //calculate  total amount for the current month
    double total =
        currentMonthExpenses.fold(0, (sum, expense) => sum + expense.amount);
    return total;
  }

  //get start month
  int getStartMonth() {
    if (_allExpenses.isEmpty) {
      return DateTime.now()
          .month; //default to current month is no expenses are recorded
    }
    //sort expensesby date to find the earliest
    _allExpenses.sort(
      (a, b) => a.date.compareTo(b.date),
    );
    return _allExpenses.first.date.month;
  }

  //get start year
  int getStartYear() {
    if (_allExpenses.isEmpty) {
      return DateTime.now()
          .year; //default to current month is no expenses are recorded
    }
    //sort expensesby date to find the earliest
    _allExpenses.sort(
      (a, b) => a.date.compareTo(b.date),
    );
    return _allExpenses.first.date.year;
  }
}
