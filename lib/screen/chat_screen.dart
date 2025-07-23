import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ChatScreen extends StatefulWidget {
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {

  List<String> _messages = []; //Store messages
  final TextEditingController _inputController = TextEditingController();
  bool _isLoading = false; //spinner

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    final loadedMessages = await ChatStorage.loadMessages();
    setState(() {
      _messages = loadedMessages;
    });
  }

  Future<void> _saveMessages() async {
    await ChatStorage.saveMessages(_messages);
  }

  void _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) {
      // TO ADD: STILL CALL API?
      return;
    }

    setState(() {
      _messages.add("You: $text");
      _isLoading = true;
    });

    _inputController.clear();

    try {
      final response = await fetchChatbotResponse(text);
      setState(() {
        _messages.add("Athena: $response");
        _isLoading = false;
      });
      await _saveMessages();
    } catch (e) {
      setState(() {
        _messages.add("Error: Could not get response");
        _isLoading = false;
      });
      await _saveMessages();
    }
  }

  Future<String> fetchChatbotResponse(String query) async {
    //TO ADD: CALL API
    await Future.delayed(Duration(seconds: 1));
    return "This is a simulated response to: $query";
  }


  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.6, // Takes up 60% of screen height
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text("Athena AI Assistant", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            SizedBox(height: 10),
            Expanded(
              child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : ListView.builder(
                  controller: ScrollController(),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    // You can customize message bubbles here
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Align(
                        alignment: message.startsWith("You:")
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: message.startsWith("You:")
                                ? Colors.black12
                                : Colors.blue[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(message),
                        ),
                      ),
                    );
                  }
                )
            ),
            // Input field with send button
            TextField(
              controller: _inputController,
              decoration: InputDecoration(
                hintText: 'Ask a question...',
                suffixIcon: IconButton(
                  icon: Icon(Icons.send),
                  onPressed: () {
                    _sendMessage(); // Implement this function to handle sending
                  },
                ),
              ),
              onSubmitted: (_) => _sendMessage(), // Optional: send on keyboard submit
            )
          ],
        ),
      ),
    );
  }
}


class ChatStorage {
  static const _storageKey = 'chat_messages';

  // Save messages list to shared_preferences
  static Future<void> saveMessages(List<String> messages) async {
    final prefs = await SharedPreferences.getInstance();
    // Store messages as JSON string list
    await prefs.setString(_storageKey, jsonEncode(messages));
  }

  // Load messages from shared_preferences
  static Future<List<String>> loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);
    if (jsonString == null) return [];
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((e) => e.toString()).toList();
  }

  // Optionally, clear saved messages
  static Future<void> clearMessages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}