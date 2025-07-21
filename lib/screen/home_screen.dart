import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/face_account.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  FaceAccount? _currentAccount;

  @override
  void initState() {
    super.initState();
    _initializeAccount();
  }

  Future<void> _initializeAccount() async {
    try {
      await AccountManager.init();
      await Future.delayed(Duration(milliseconds: 100));

      _currentAccount = AccountManager.currentAccount;

      if (_currentAccount == null && mounted) {
        Navigator.pushReplacementNamed(context, '/');
        return;
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) Navigator.pushReplacementNamed(context, '/');
    }
  }

  Future<void> _updateBalance(double newBalance) async {
    if (_currentAccount == null) return;

    setState(() {
      _currentAccount!.balance = newBalance;
      AccountManager.currentAccount?.balance = newBalance;
    });

    await AccountManager.saveAccounts();
  }

  Future<void> _logout() async {
    AccountManager.currentAccount = null;
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/',
          (Route<dynamic> route) => false,
    );

    if (mounted) {
      setState(() {
        _currentAccount = null;
        _isLoading = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Bank Account'),
        actions: [
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

  Widget _buildAccountCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Display full name
            Text(
              _currentAccount!.fullName,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),

            // Display phone number or ••••••••••
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.phone, size: 16),
                SizedBox(width: 5),
                Text(
                  _currentAccount!.phoneNumber ?? '••••••••••',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
            SizedBox(height: 10),

            // Existing account info
            Text('Account Number'),
            Text(
              _currentAccount!.accountNumber,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text('Available Balance'),
            Text(
              '\$${_currentAccount!.balance.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 24,
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Keep all existing methods exactly as they were
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
          onPressed: isGuest ? null : () => _showDepositDialog(context),
          disabled: isGuest,
        ),
      ],
    );
  }

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
          ),
          child: IconButton(
            icon: Icon(icon,
                size: 30,
                color: disabled ? Colors.grey : Colors.blue),
            onPressed: disabled ? null : onPressed,
          ),
        ),
        SizedBox(height: 8),
        Text(label, style: TextStyle(fontSize: 14)),
      ],
    );
  }

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
                  decoration: InputDecoration(labelText: 'Amount'),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
                TextField(
                  controller: accountController,
                  decoration: InputDecoration(labelText: 'Account Number'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
            actions: [
              TextButton(
                child: Text('Cancel'),
                onPressed: () => Navigator.pop(context),
              ),
              TextButton(
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

  void _showDepositDialog(BuildContext context) {
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Deposit Money'),
        content: TextField(
          controller: amountController,
          decoration: InputDecoration(labelText: 'Amount'),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
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