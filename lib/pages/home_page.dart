import 'package:expensetracker/bargraph/bargraph.dart';
import 'package:expensetracker/components/my_list_tile.dart';
import 'package:expensetracker/database/expensedatabase.dart';
import 'package:expensetracker/helper/helper_functions.dart';
import 'package:expensetracker/models/expense.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  //text controllers
  TextEditingController nameController = TextEditingController();
  TextEditingController amountController = TextEditingController();
  //futures to load graph data & monthly total
  Future<Map<String, double>>? _monthlyTotalsFuture;
  Future<double>? _calculateCurrentMonthTotal;
  @override
  void initState() {
    //read db on initial startup
    Provider.of<ExpenseDatabase>(context, listen: false).readExpenses();
    //load futures
    refreshData();

    super.initState();
  }

  //refresh graph data
  void refreshData() {
    _monthlyTotalsFuture = Provider.of<ExpenseDatabase>(context, listen: false)
        .clculateMonthlyTotals();
    _calculateCurrentMonthTotal =
        Provider.of<ExpenseDatabase>(context, listen: false)
            .calculateCurrentMonthTotal();
  }

  //open new expense box
  void openNewExpenseBox() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("New expense"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            //userinput -> expense name
            TextField(
              controller: nameController,
              decoration: const InputDecoration(hintText: "name"),
            ),
            //userinput -> expense amount
            TextField(
              controller: amountController,
              decoration: const InputDecoration(hintText: "Amount"),
            ),
          ],
        ),
        actions: [
          //cancel button
          _cancelButton(),

          //save button
          _createNewExpenseButton()
        ],
      ),
    );
  }

//open edit box
  void openEditBox(Expense expense) {
    //pre-fill existing value into textfield
    String existingName = expense.name;
    String existingAmount = expense.amount.toString();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit expense"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            //userinput -> expense name
            TextField(
              controller: nameController,
              decoration: InputDecoration(hintText: existingName),
            ),
            //userinput -> expense amount
            TextField(
              controller: amountController,
              decoration: InputDecoration(hintText: existingAmount),
            ),
          ],
        ),
        actions: [
          //cancel button
          _cancelButton(),

          //save button
          _editExpenseButton(expense),
        ],
      ),
    );
  }

//open delete box
  void openDeleteBox(Expense expense) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete expense"),
        actions: [
          //cancel button
          _cancelButton(),

          //delete button
          _deleteExpenseButton(expense.id),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseDatabase>(
      builder: (context, value, child) {
        //get dates
        int startMonth = value.getStartMonth();
        int startYear = value.getStartYear();
        int currentMonth = DateTime.now().month;
        int currentYear = DateTime.now().year;
        //calculate the number of month since the first month
        int monthCount = calculateMonthCount(
            startYear, startMonth, currentYear, currentMonth);
        //only display the expenses for the current map
        List<Expense> currentMonthExpenses = value.allExpense.where((expense) {
          return expense.date.year == currentYear &&
              expense.date.month == currentMonth;
        }).toList();
        //Return UI
        return Scaffold(
          backgroundColor: Colors.grey.shade300,
          floatingActionButton: FloatingActionButton(
            onPressed: openNewExpenseBox,
            child: const Icon(Icons.add),
          ),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: FutureBuilder<double>(
              future: _calculateCurrentMonthTotal,
              builder: (context, snapshot) {
                //loaded
                if (snapshot.connectionState == ConnectionState.done) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                          //amount total
                          '\$' + snapshot.data!.toStringAsFixed(2)),
                      //month
                      Text(getCurrentMonthName()),
                    ],
                  );
                }
                //loading
                else {
                  return const Text("loading...");
                }
              },
            ),
          ),
          body: SafeArea(
            child: Column(
              children: [
                //GRAPH UI
                SizedBox(
                  height: 250,
                  child: FutureBuilder(
                    future: _monthlyTotalsFuture,
                    builder: (context, snapshot) {
                      //data is loaded
                      if (snapshot.connectionState == ConnectionState.done) {
                        Map<String, double> monthlyTotals = snapshot.data ?? {};
                        //create the list of monthly summary
                        List<double> monthlySummary =
                            List.generate(monthCount, (index) {
                          //calculate year month considering startMonth & index
                          int year = startYear + (startMonth + index - 1) ~/ 12;
                          int month = (startMonth + index - 1) % 12 + 1;

                          // create the key in the format 'year-month'
                          String yearMonthKey = '$year-$month';
                          //return the total for year-month or 0.0 if non existent
                          return monthlyTotals[yearMonthKey] ?? 0.0;
                        });
                        return MyBarGraph(
                            monthlySummary: monthlySummary,
                            startMonth: startMonth);
                      }
                      //loading......
                      else {
                        return const Center(
                          child: Text("Loading.."),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(height: 25,),
                //EXPENSE LIST UI
                Expanded(
                  child: ListView.builder(
                    itemCount: currentMonthExpenses.length,
                    itemBuilder: (context, index) {
                      //reverse the index to show latest item first
                      int reversedIndex =
                          currentMonthExpenses.length - 1 - index;
                      //get individual expenses
                      Expense individualExpenses =
                          currentMonthExpenses[reversedIndex];
                      //return list tile UI
                      return MyListTile(
                        title: individualExpenses.name,
                        trailing: formatAmount(individualExpenses.amount),
                        onEditpressed: (context) =>
                            openEditBox(individualExpenses),
                        onDeletepressed: (context) =>
                            openDeleteBox(individualExpenses),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  //CANCEL BUTTON
  Widget _cancelButton() {
    return MaterialButton(
      onPressed: () {
        //pop box
        Navigator.pop(context);

        //clear control
        nameController.clear();
        amountController.clear();
      },
      child: const Text('Cancel'),
    );
  }

  //SAVE BUTTON -> Create new expense
  Widget _createNewExpenseButton() {
    return MaterialButton(
      onPressed: () async {
        //only save if there is something in the text field
        if (nameController.text.isNotEmpty &&
            amountController.text.isNotEmpty) {
          //pop box
          Navigator.pop(context);
          //create new expense
          Expense newExpense = Expense(
            name: nameController.text,
            amount: convertStringToDouble(amountController.text),
            date: DateTime.now(),
          );
          //save to db
          await context.read<ExpenseDatabase>().createNewExpense(newExpense);
          //refresh graph
          refreshData();
          ();

          // clear controllers
          nameController.clear();
          amountController.clear();
        }
      },
      child: const Text('Save'),
    );
  }

  //SAVE BUTTON ->Edit existing expense
  Widget _editExpenseButton(Expense expense) {
    return MaterialButton(
      onPressed: () async {
        //save as long as at least one textfield has been changed
        if (nameController.text.isNotEmpty ||
            amountController.text.isNotEmpty) {
          //pop  box
          Navigator.pop(context);
          //create a new updated expense
          Expense updatedExpense = Expense(
            name: nameController.text.isNotEmpty
                ? nameController.text
                : expense.name,
            amount: amountController.text.isNotEmpty
                ? convertStringToDouble(amountController.text)
                : expense.amount,
            date: DateTime.now(),
          );
          //old expense id
          int existingId = expense.id;
          //save to db
          await context
              .read<ExpenseDatabase>()
              .updateExpense(existingId, updatedExpense);
          //refresh graph
          refreshData();
          ();
        }
      },
      child: Text("Save"),
    );
  }

  //DELETE Button
  Widget _deleteExpenseButton(int id) {
    return MaterialButton(
      onPressed: () async {
        //pop box
        Navigator.pop(context);
        //delete expense from db
        await context.read<ExpenseDatabase>().deleteExpense(id);

        //refresh graph
        refreshData();
        ();
      },
      child: const Text("Delete"),
    );
  }
}
