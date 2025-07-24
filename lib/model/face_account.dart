import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'dart:math';

class FaceAccount {
  final String accountNumber;
  final String accountId;
  final String fullName;
  final String? phoneNumber;
  double balance;
  final List<List<double>> embeddings;
  final DateTime createdAt;
  DateTime lastAccessed;

  FaceAccount({
    required this.accountNumber,
    required this.accountId,
    required this.fullName,
    this.phoneNumber,
    this.balance = 0.0,
    required this.embeddings,
    DateTime? createdAt,
    DateTime? lastAccessed,
  })  : createdAt = createdAt ?? DateTime.now(),
        lastAccessed = lastAccessed ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'accountNumber': accountNumber,
    'accountId': accountId,
    'fullName': fullName,
    'phoneNumber': phoneNumber,
    'balance': balance,
    'embeddings': embeddings,
    'createdAt': createdAt.toIso8601String(),
    'lastAccessed': lastAccessed.toIso8601String(),
  };

  factory FaceAccount.fromJson(Map<String, dynamic> json) => FaceAccount(
    accountNumber: json['accountNumber'],
    accountId: json['accountId'],
    fullName: json['fullName'],
    phoneNumber: json['phoneNumber'],
    balance: json['balance'],
    embeddings: List<List<double>>.from(
        json['embeddings'].map((e) => List<double>.from(e))),
    createdAt: DateTime.parse(json['createdAt']),
    lastAccessed: DateTime.parse(json['lastAccessed']),
  );
}

class AccountManager {
  static const double matchingThreshold = 0.80;
  static const int maxEmbeddingsPerAccount = 5;
  static const int maxAccountsInMemory = 500;

  static final List<FaceAccount> accounts = [];
  static final Map<String, FaceAccount> _accountIdIndex = {};
  static final Map<String, List<String>> _embeddingHashIndex = {};
  static FaceAccount? currentAccount;
  static late SharedPreferences _prefs;
  static final Uuid _uuid = Uuid();

  // Initialization
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadAccounts();
    _buildIndices();
  }

  static Future<FaceAccount?> handleFaceAuthentication(
      List<List<double>> newEmbeddings,
      ) async {
    if (newEmbeddings.isEmpty) {
      return null;
    }

    // Try to find matching account
    final newEmbedding = newEmbeddings.first;
    final account = await findBestMatchingAccount(newEmbedding);

    if (account != null) {
      // Update existing account (last accessed time, embeddings, etc.)
      account.lastAccessed = DateTime.now();
      _addEmbeddingsToAccount(account, newEmbeddings);
      currentAccount = account;
      await _cleanupOldAccounts();
      await saveAccounts();
      return account;
    }

    // No matching account found → return null (instead of creating a new one)
    return null;
  }

  static Future<FaceAccount> registerNewAccount({
    required List<List<double>> embeddings,
    required String fullName,
    String? phoneNumber,
  }) async {
    final account = FaceAccount(
      accountNumber: _generateAccountNumber(),
      accountId: _uuid.v4(),
      fullName: fullName,
      phoneNumber: phoneNumber,
      embeddings: embeddings.take(maxEmbeddingsPerAccount).toList(),
    );

    // Add to storage and indices
    accounts.add(account);
    _accountIdIndex[account.accountId] = account;
    for (var embedding in account.embeddings) {
      final hash = _embeddingHash(embedding);
      _embeddingHashIndex.putIfAbsent(hash, () => []).add(account.accountId);
    }

    currentAccount = account;
    await saveAccounts();
    return account;
  }

  // Login-specific method
  static Future<FaceAccount?> authenticateUser(
      List<double> newEmbedding,
      ) async {
    final account = await findBestMatchingAccount(newEmbedding);
    if (account != null) {
      account.lastAccessed = DateTime.now();
      currentAccount = account;
      await saveAccounts();
    }
    return account;
  }


  // Private Helpers
  static Future<void> _loadAccounts() async {
    final accountsJson = _prefs.getStringList('face_accounts') ?? [];
    accounts.clear();
    accounts.addAll(accountsJson
        .map((json) => FaceAccount.fromJson(jsonDecode(json)))
        .take(maxAccountsInMemory));
  }

  static void _buildIndices() {
    _accountIdIndex.clear();
    _embeddingHashIndex.clear();

    for (var account in accounts) {
      _accountIdIndex[account.accountId] = account;
      for (var embedding in account.embeddings) {
        final hash = _embeddingHash(embedding);
        _embeddingHashIndex.putIfAbsent(hash, () => []).add(account.accountId);
      }
    }
  }

  static Future<void> saveAccounts() async {
    // Only called during registration or explicit updates
    accounts.sort((a, b) => b.lastAccessed.compareTo(a.lastAccessed));
    await _prefs.setStringList(
      'face_accounts',
      accounts.map((acc) => jsonEncode(acc.toJson())).toList(),
    );
  }


  static String _generateAccountNumber() {
    final random = Random();
    return List.generate(10, (_) => random.nextInt(10)).join();
  }

  static String _embeddingHash(List<double> embedding) {
    const precision = 3;
    final hashString =
    embedding.map((v) => v.toStringAsFixed(precision)).join(',');
    return sha256.convert(utf8.encode(hashString)).toString();
  }

  static Future<FaceAccount?> findBestMatchingAccount(
      List<double> newEmbedding) async {
    final newHash = _embeddingHash(newEmbedding);
    FaceAccount? bestMatch;
    double highestSimilarity = 0.0;

    // 1. Check hash index for potential matches
    final candidateAccountIds = _embeddingHashIndex[newHash] ?? [];
    for (var accountId in candidateAccountIds) {
      final account = _accountIdIndex[accountId];
      if (account != null) {
        final similarity = _bestEmbeddingSimilarity(account, newEmbedding);
        if (similarity > highestSimilarity) {
          highestSimilarity = similarity;
          bestMatch = account;
        }
      }
    }

    // 2. If no hash matches, check recent accounts
    if (bestMatch == null && accounts.length < 1000) {
      for (var account in accounts.take(100)) {
        final similarity = _bestEmbeddingSimilarity(account, newEmbedding);
        if (similarity > highestSimilarity) {
          highestSimilarity = similarity;
          bestMatch = account;
        }
      }
    }

    return highestSimilarity >= matchingThreshold ? bestMatch : null;
  }

  static Future<FaceAccount> createAccount({
    required List<List<double>> embeddings,
    required String fullName,
    String? phoneNumber,
  }) async {
    final account = FaceAccount(
      accountNumber: _generateAccountNumber(),
      accountId: _uuid.v4(),
      fullName: fullName,
      phoneNumber: phoneNumber,
      embeddings: embeddings.take(maxEmbeddingsPerAccount).toList(),
    );

    accounts.add(account);
    _accountIdIndex[account.accountId] = account;

    for (var embedding in account.embeddings) {
      final hash = _embeddingHash(embedding);
      _embeddingHashIndex.putIfAbsent(hash, () => []).add(account.accountId);
    }

    await saveAccounts();
    return account;
  }

  static double _bestEmbeddingSimilarity(
      FaceAccount account, List<double> newEmbedding) {
    double highest = 0.0;
    for (var embedding in account.embeddings) {
      final similarity = _cosineSimilarity(newEmbedding, embedding);
      if (similarity > highest) {
        highest = similarity;
        if (highest > matchingThreshold) break; // Early exit if good match found
      }
    }
    return highest;
  }

  static double _cosineSimilarity(List<double> a, List<double> b) {
    double dot = 0.0, normA = 0.0, normB = 0.0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    return dot / (sqrt(normA) * sqrt(normB));
  }

  static void _addEmbeddingsToAccount(
      FaceAccount account, List<List<double>> newEmbeddings) {
    // Rotate embeddings (FIFO)
    final current = account.embeddings;
    final toAdd = newEmbeddings.take(maxEmbeddingsPerAccount).toList();

    // Remove oldest hashes from index
    for (var embedding in current) {
      final hash = _embeddingHash(embedding);
      _embeddingHashIndex[hash]?.remove(account.accountId);
      if (_embeddingHashIndex[hash]?.isEmpty ?? false) {
        _embeddingHashIndex.remove(hash);
      }
    }

    // Update embeddings
    account.embeddings
      ..clear()
      ..addAll(toAdd);

    // Add new hashes to index
    for (var embedding in account.embeddings) {
      final hash = _embeddingHash(embedding);
      _embeddingHashIndex.putIfAbsent(hash, () => []).add(account.accountId);
    }
  }

  static Future<void> _cleanupOldAccounts() async {
    if (accounts.length <= maxAccountsInMemory) return;

    // Sort by last accessed (oldest first)
    accounts.sort((a, b) => a.lastAccessed.compareTo(b.lastAccessed));

    while (accounts.length > maxAccountsInMemory) {
      final removed = accounts.removeAt(0);
      _accountIdIndex.remove(removed.accountId);

      // Clean up embedding hashes
      for (var embedding in removed.embeddings) {
        final hash = _embeddingHash(embedding);
        _embeddingHashIndex[hash]?.remove(removed.accountId);
        if (_embeddingHashIndex[hash]?.isEmpty ?? false) {
          _embeddingHashIndex.remove(hash);
        }
      }
    }

    await saveAccounts();
  }

  // Public API
  static Future<void> logout() async {
    currentAccount = null;
  }

  static Future<bool> transferFunds(
      String toAccountNumber, double amount) async {
    if (currentAccount == null) return false;
    if (currentAccount!.balance < amount) return false;

    // Find recipient (in a real app, this would be a database query)
    final recipient = accounts.firstWhere(
          (acc) => acc.accountNumber == toAccountNumber,
      orElse: () => throw Exception('Account not found'),
    );

    // Update balances
    currentAccount!.balance -= amount;
    recipient.balance += amount;

    await saveAccounts();
    return true;
  }
}