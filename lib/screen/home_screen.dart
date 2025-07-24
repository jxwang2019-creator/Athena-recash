import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../model/face_account.dart';
import '../widget/ai_chatbot_dialog.dart';
import '../widget/deposit_qr_widget.dart';
import 'dart:async'; // Import for Timer
import 'package:http/http.dart' as http; // Import for making HTTP requests
import 'dart:convert'; // Import for JSON decoding

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  FaceAccount? _currentAccount;
  Timer? _balanceCheckTimer; // Declares a Timer to periodically check for external balance updates


  @override
  void initState() {
    super.initState();
    _initializeAccount();
  }

  @override
  void dispose() {
    // Cancel the timer when the widget is disposed to prevent memory leaks
    // and ensure no operations are attempted on a non-existent widget.
    _balanceCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeAccount() async {
    try {
      await AccountManager.init();
      await Future.delayed(Duration(milliseconds: 100)); // Simulate a small delay for initialization

      _currentAccount = AccountManager.currentAccount;

      // If no account is found after initialization, navigate back to the login screen.
      if (_currentAccount == null && mounted) {
        Navigator.pushReplacementNamed(context, '/');
        return;
      }

      if (mounted) {
        setState(() => _isLoading = false);
        // Start the periodic balance check only if an account is loaded and it's not a 'GUEST' account.
        if (_currentAccount != null && _currentAccount!.accountNumber != 'GUEST') {
          _startBalanceCheckTimer();
        }
      }
    } catch (e) {
      // If an error occurs during initialization, navigate back to the login screen.
      if (mounted) Navigator.pushReplacementNamed(context, '/');
    }
  }

  /// Starts a periodic timer to check for external balance updates.
  /// The check occurs every 5 seconds.
  void _startBalanceCheckTimer() {
    // First, cancel any existing timer to avoid multiple timers running simultaneously.
    _balanceCheckTimer?.cancel();
    _balanceCheckTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      _checkExternalBalance();
    });
  }

  /// Makes an API call to check for an external balance using the provided URL structure.
  /// The local balance is synchronized with the external balance if it changes.
  Future<void> _checkExternalBalance() async {
    // Do not proceed if there's no current account or if it's a guest account.
    // Also, cancel the timer if these conditions are met.
    if (_currentAccount == null || _currentAccount!.accountNumber == 'GUEST') {
      _balanceCheckTimer?.cancel();
      return;
    }

    try {
      final String? baseUrl = dotenv.env['GCP_BASE_URL'];
      final String? fixedPath = dotenv.env['GCP_BANK_FIXED_PATH'];
      // Validate that environment variables are loaded
      if (baseUrl == null || fixedPath == null) {
        return; // Exit if configuration is missing
      }
      final String? accountNumber =
          AccountManager.currentAccount?.accountNumber;
      // Construct the full URL with the fixed path and chatText query parameter
      // The message will be URL-encoded automatically by Uri.https
      final Uri uri = Uri.https(
        baseUrl,
        // Host (e.g., athena-adk-recash-193587434015.asia-southeast1.run.app)
        'recash-agent-get/$fixedPath$accountNumber',
      );

      // Make an HTTP GET request to the constructed URL
      final response = await http.get(uri); // Log the URL being checked


      if (response.statusCode == 200) {
        // Decode the JSON response
        final Map<String, dynamic> responseData = json.decode(response.body);
        // Assuming the API returns a 'balance' field. Adjust key as per your API.
        final double newExternalBalance = (responseData['balance'] as num?)?.toDouble() ?? _currentAccount!.balance;

        // Only update if the external balance is different from the current local balance
        // Using toStringAsFixed(2) for comparison to handle floating point precision issues
        if (_currentAccount!.balance.toStringAsFixed(2) != newExternalBalance.toStringAsFixed(2)) {
          double oldBalance = _currentAccount!.balance;
          await _updateBalance(newExternalBalance); // Update to the new external balance

          double balanceChange = newExternalBalance - oldBalance;
          String changeMessage;
          if (balanceChange > 0) {
            changeMessage = '+\$${balanceChange.toStringAsFixed(2)} added to your account!';
          } else if (balanceChange < 0) {
            changeMessage = '-\$${(-balanceChange).toStringAsFixed(2)} deducted from your account!';
          } else {
            changeMessage = 'Balance synchronized. No change.'; // Should not be reached if comparison works
          }

          print('External balance updated. New balance: \$${newExternalBalance.toStringAsFixed(2)}');
          // Show a temporary message to the user indicating the balance update.
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(changeMessage), duration: const Duration(seconds: 3)),
            );
          }
        } else {
          print('External balance is the same as local balance. No update needed.');
        }
      } else {
        // Handle non-200 status codes (e.g., 404, 500)
        print('Failed to load external balance. Status code: ${response.statusCode}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to get external balance: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      // Log any errors that occur during the external balance check (e.g., network issues).
      print('Error checking external balance: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Network error checking balance.')),
        );
      }
    }
  }

  /// Updates the current account's balance and saves the changes.
  Future<void> _updateBalance(double newBalance) async {
    if (_currentAccount == null) return;

    setState(() {
      _currentAccount!.balance = newBalance;
      AccountManager.currentAccount?.balance = newBalance; // Also update in AccountManager
    });

    await AccountManager.saveAccounts(); // Persist the updated balance
  }

  /// Logs out the current user, cancels the balance check timer,
  /// and navigates back to the login screen.
  Future<void> _logout() async {
    _balanceCheckTimer?.cancel(); // Cancel timer on logout
    AccountManager.currentAccount = null; // Clear the current account
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/',
          (Route<dynamic> route) => false, // Remove all routes from the stack
    );

    if (mounted) {
      setState(() {
        _currentAccount = null; // Clear local account state
        _isLoading = true; // Reset loading state
      });
    }
  }

  /// Shows the AI Chatbot dialog.
  void _showAIChatbotDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AIChatbotDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Bank Account'),
        actions: [
          // Show logout button only if it's not a GUEST account
          if (_currentAccount?.accountNumber != 'GUEST')
            IconButton(
              icon: Icon(Icons.logout),
              onPressed: _logout,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  /// Builds the main body of the screen based on loading state and account presence.
  Widget _buildBody() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_currentAccount == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('No active account'),
            SizedBox(height: 20),
            ElevatedButton(
              child: Text('Return to Login'),
              onPressed: _logout,
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          _buildAccountCard(),
          SizedBox(height: 30),
          _buildActionButtons(),
        ],
      ),
    );
  }

  /// Builds the card displaying account details.
  Widget _buildAccountCard() {
    return Card(
      elevation: 4, // Add a subtle shadow
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), // Rounded corners
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(
              _currentAccount!.fullName,
              style: TextStyle(
                fontSize: 22, // Slightly larger font
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey[800],
              ),
            ),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.phone, size: 18, color: Colors.grey[600]),
                SizedBox(width: 8),
                Text(
                  _currentAccount!.phoneNumber ?? '••••••••••',
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                ),
              ],
            ),
            SizedBox(height: 15),
            Divider(), // Visual separator
            SizedBox(height: 15),
            Text(
              'Account Number',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            Text(
              _currentAccount!.accountNumber,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.blueGrey[700],
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Available Balance',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            Text(
              '\$${_currentAccount!.balance.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 28, // Larger balance display
                color: Colors.green[700], // Darker green for emphasis
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the row of action buttons.
  Widget _buildActionButtons() {
    final isGuest = _currentAccount?.accountNumber == 'GUEST';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(
          icon: Icons.person_add,
          label: 'Add People',
          onPressed: () => _showAddPeopleDialog(context),
          disabled: isGuest,
        ),
        _buildActionButton(
          icon: Icons.money,
          label: 'Transfer',
          onPressed: isGuest ? null : () => _showTransferDialog(context),
          disabled: isGuest,
        ),
        _buildActionButton(
          icon: Icons.account_balance,
          label: 'Deposit',
          onPressed: isGuest ? null: () => _launchDepositUrl(context),
          disabled: isGuest,
        ),
        _buildActionButton(
          icon: Icons.chat,
          label: 'AI Assistant',
          onPressed: isGuest ? null : () => _showAIChatbotDialog(context),
          disabled: isGuest,
        ),
      ],
    );
  }

  /// Helper widget to build individual action buttons.
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool disabled = false,
  }) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: disabled ? Colors.grey[200] : Colors.blue[50],
            borderRadius: BorderRadius.circular(35),
            boxShadow: [
              if (!disabled) // Add shadow only if not disabled
                BoxShadow(
                  color: Colors.blue.withOpacity(0.2),
                  spreadRadius: 2,
                  blurRadius: 5,
                  offset: Offset(0, 3),
                ),
            ],
          ),
          child: IconButton(
            icon: Icon(icon,
                size: 30,
                color: disabled ? Colors.grey : Colors.blue),
            onPressed: disabled ? null : onPressed,
          ),
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: disabled ? Colors.grey : Colors.black87,
          ),
        ),
      ],
    );
  }

  /// Shows a dialog for adding people to the account.
  void _showAddPeopleDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add People'),
        content: Text('This feature will allow you to add authorized users to your account.'),
        actions: [
          TextButton(
            child: Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  /// Shows a dialog for transferring money.
  void _showTransferDialog(BuildContext context) {
    final amountController = TextEditingController();
    final accountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Transfer Money'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}), // Rebuild to update button state if needed
                ),
                SizedBox(height: 15),
                TextField(
                  controller: accountController,
                  decoration: InputDecoration(
                    labelText: 'Account Number',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
            actions: [
              TextButton(
                child: Text('Cancel'),
                onPressed: () => Navigator.pop(context),
              ),
              ElevatedButton( // Use ElevatedButton for primary action
                child: Text('Transfer'),
                onPressed: () async {
                  final amount = double.tryParse(amountController.text) ?? 0;
                  if (amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Please enter a valid amount')),
                    );
                    return;
                  }

                  if (_currentAccount!.balance < amount) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Insufficient funds')),
                    );
                    return;
                  }

                  await _updateBalance(_currentAccount!.balance - amount);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Transferred \$${amount.toStringAsFixed(2)}')),
                  );
                  Navigator.pop(context);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  /// Shows a dialog for depositing money.
  void _showDepositDialog(BuildContext context) {
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Deposit Money'),
        content: TextField(
          controller: amountController,
          decoration: InputDecoration(
            labelText: 'Amount',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton( // Use ElevatedButton for primary action
            child: Text('Deposit'),
            onPressed: () async {
              final amount = double.tryParse(amountController.text) ?? 0;
              if (amount > 0) {
                await _updateBalance(_currentAccount!.balance + amount);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Deposited \$${amount.toStringAsFixed(2)}')),
                );
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please enter a valid amount')),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
