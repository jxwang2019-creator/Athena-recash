import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:stts/stts.dart';
import 'package:http/http.dart' as http;

import '../model/face_account.dart';

class AIChatbotDialog extends StatefulWidget {
  const AIChatbotDialog({Key? key}) : super(key: key);

  @override
  _AIChatbotDialogState createState() => _AIChatbotDialogState();
}

class _AIChatbotDialogState extends State<AIChatbotDialog> {
  final Tts _tts = Tts();
  final Stt _stt = Stt();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _textFocusNode = FocusNode();

  bool _isLoading = false;
  bool _speechAvailable = false;
  bool _isListening = false;
  String _currentSpeechResult = '';
  List<ChatMessage> _messages = [];
  bool _isButtonPressed = false;
  StreamSubscription<SttState>? _stateSubscription;
  StreamSubscription<SttRecognition>? _resultSubscription;

  @override
  void initState() {
    super.initState();
    _initSpeechServices();
    _addBotMessage('Hello! How can I help you today?');
  }

  Future<void> _initSpeechServices() async {
    try {
      bool hasPermission = await _stt.hasPermission();
      if (!hasPermission) {
        hasPermission = await _stt.hasPermission();
      }

      if (hasPermission) {
        final availableLanguages = await _stt.getLanguages();

        if (availableLanguages.isEmpty) {
          _addBotMessage("No languages available for speech recognition");
          return;
        }
        final defaultLanguage = availableLanguages.firstWhere(
          (lang) => lang.toLowerCase().contains('en-us'),
          orElse: () => availableLanguages.first,
        );
        await _stt.setLanguage(defaultLanguage);
        setState(() => _speechAvailable = true);

        _stt.onStateChanged.listen((state) {
          if (mounted) {
            setState(() {
              _isListening = state == SttState.start;
              if (!_isListening) {
                _isButtonPressed = false;
              }
            });
          }
        });

        _stt.onResultChanged.listen((recognition) {
          if (mounted) {
            setState(() {
              _currentSpeechResult = recognition.text;
              if (recognition.isFinal && _currentSpeechResult.isNotEmpty) {
                _submitSpeechResult();
              }
            });
          }
        });

        _stateSubscription = _stt.onStateChanged.listen(
          (sttState) {
            setState(() => _isListening = sttState == SttState.start);
          },
          onError: (err) {
            _addBotMessage("Speech state error: $err");
          },
        );

        _resultSubscription = _stt.onResultChanged.listen(
          (result) {
            if (mounted) {
              setState(() => _currentSpeechResult = result.text);
              if (result.isFinal && _currentSpeechResult.isNotEmpty) {
                _submitSpeechResult();
              }
            }
          },
          onError: (err) {
            _addBotMessage("Recognition error: $err");
          },
        );

        if (!await _stt.isSupported()) {
          _addBotMessage("Speech recognition not supported");
        }
      } else {
        _addBotMessage("Microphone permission not granted");
      }
    } catch (e) {
      if (mounted) {
        _addBotMessage("Speech services unavailable: ${e.toString()}");
        setState(() => _speechAvailable = false);
      }
    }
  }

  Future<void> _submitSpeechResult() async {
    if (_currentSpeechResult.isEmpty) return;

    final text = _currentSpeechResult;
    _currentSpeechResult = '';
    _addUserMessage(text);
    await _sendToAPI(text);
  }

  void _addUserMessage(String text) {
    if (mounted) {
      setState(() {
        _messages.add(ChatMessage(text: text, isUser: true));
      });
      _scrollToBottom();
    }
  }

  void _addBotMessage(String text) {
    if (mounted) {
      setState(() {
        _messages.add(ChatMessage(text: text, isUser: false));
      });
      _scrollToBottom();
      if (_speechAvailable) {
        _tts.start(text);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && mounted) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _startListening() async {
    if (!_speechAvailable) {
      _addBotMessage("Microphone permission not granted");
      await _initSpeechServices();
      return;
    }

    try {
      setState(() {
        _isButtonPressed = true;
        _currentSpeechResult = '';
      });
      Future.delayed(Duration(milliseconds: 1000), () {
        // Now try to start listening
        // ... your listen call ...
      });
      await _stt.start();
    } catch (e) {
      if (mounted) {
        setState(() => _isButtonPressed = false);
        _addBotMessage("Speech recognition error: ${e.toString()}");
      }
    }
  }

  Future<void> _stopListening() async {
    try {
      await _stt.stop();
      if (_currentSpeechResult.isNotEmpty) {
        await _submitSpeechResult();
      }
    } catch (e) {
      if (mounted) {
        _addBotMessage("Error stopping speech recognition: ${e.toString()}");
      }
    } finally {
      if (mounted) {
        setState(() => _isButtonPressed = false);
      }
    }
  }

  Future<void> _handleTextSubmit() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    _textFocusNode.unfocus();
    _addUserMessage(text);
    await _sendToAPI(text);
  }

  Future<void> _sendToAPI(String message) async {
    // Ensure the widget is still mounted before proceeding
    if (!mounted) return;

    // Set loading state to true to show a loading indicator
    setState(() => _isLoading = true);

    try {
      // Retrieve base URL and fixed path from environment variables
      // Make sure these keys (GCP_BASE_URL, GCP_FIXED_PATH) match your .env file
      final String? baseUrl = dotenv.env['GCP_BASE_URL'];
      final String? fixedPath = dotenv.env['GCP_AGENT_FIXED_PATH'];

      // Validate that environment variables are loaded
      if (baseUrl == null || fixedPath == null) {
        _addBotMessage(
          "Configuration Error: GCP_BASE_URL or GCP_FIXED_PATH not found in .env",
        );
        return; // Exit if configuration is missing
      }
      final String? accountNumber =
          AccountManager.currentAccount?.accountNumber;
      // Construct the full URL with the fixed path and chatText query parameter
      // The message will be URL-encoded automatically by Uri.https
      final Uri uri = Uri.https(
        baseUrl,
        // Host (e.g., athena-adk-recash-193587434015.asia-southeast1.run.app)
        '/$fixedPath/ASDF$accountNumber',
        // Unencoded path (e.g., recash-agent-get/ASDF5000)
        {'chatText': message}, // Query parameters (chatText=Hello)
      );

      // Make an HTTP GET request to the constructed URL
      final response = await http.get(uri);

      // Check the response status code
      if (response.statusCode == 200) {
        // If the request was successful, add the bot's response
        try {
          // Decode the JSON response body
          final Map<String, dynamic> jsonResponse = json.decode(response.body);

          // Extract the 'chatText' part from the JSON response
          final String? aiChatText = jsonResponse['chatText'];

          if (aiChatText != null) {
            _addBotMessage("AI response: $aiChatText");
          } else {
            _addBotMessage(
              "API Response: 'chatText' not found in response. Full response: ${response.body}",
            );
          }
        } catch (e) {
          _addBotMessage(
            "API Error: Failed to parse JSON response. Full response: ${response.body}. Error: $e",
          );
        }
      } else {
        // If the request failed, add an error message with the status code
        _addBotMessage(
          "API Error: Status code ${response.statusCode}. Response body: ${response.body}",
        );
      }
    } catch (e) {
      // Catch any network or other errors and display them
      _addBotMessage("Network error: ${e.toString()}");
    } finally {
      // Ensure the loading state is reset, only if the widget is still mounted
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _textFocusNode.dispose();
    _stt.dispose();
    _tts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('AI Assistant'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Chat messages
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _messages.length,
                itemBuilder: (context, index) => ChatBubble(
                  text: _messages[index].text,
                  isUser: _messages[index].isUser,
                ),
              ),
            ),

            // Speech recognition indicator
            if (_currentSpeechResult.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Listening: "$_currentSpeechResult"',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

            // Input row
            Container(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Text field with multi-line support
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      focusNode: _textFocusNode,
                      maxLines: 5,
                      minLines: 1,
                      keyboardType: TextInputType.multiline,
                      decoration: InputDecoration(
                        hintText: 'Type your message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        suffixIcon: _textController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.send),
                                onPressed: _handleTextSubmit,
                              )
                            : null,
                      ),
                      onChanged: (text) {
                        setState(() {}); // Rebuild to show/hide send button
                      },
                      onSubmitted: (_) => _handleTextSubmit(),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Mic button with press-and-hold functionality
                  if (!_isLoading && _textController.text.isEmpty)
                    GestureDetector(
                      onTapDown: (_) => _startListening(),
                      onTapUp: (_) => _stopListening(),
                      onTapCancel: () => _stopListening(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _isButtonPressed
                              ? Colors.red.withOpacity(0.2)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isListening ? Icons.mic_off : Icons.mic,
                          color: _speechAvailable
                              ? (_isListening ? Colors.red : Colors.blue)
                              : Colors.grey,
                          size: 28,
                        ),
                      ),
                    )
                  else if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
}

class ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;

  const ChatBubble({Key? key, required this.text, required this.isUser})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser
              ? Theme.of(context).primaryColor.withOpacity(0.1)
              : Colors.grey[200],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isUser ? Theme.of(context).primaryColor : Colors.black87,
          ),
        ),
      ),
    );
  }
}
