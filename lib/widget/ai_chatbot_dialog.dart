import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_speech/flutter_speech.dart';

class AIChatbotDialog extends StatefulWidget {
  const AIChatbotDialog({Key? key}) : super(key: key);

  @override
  _AIChatbotDialogState createState() => _AIChatbotDialogState();
}

class _AIChatbotDialogState extends State<AIChatbotDialog> {
  final TextEditingController _messageController = TextEditingController();
  final FlutterTts _tts = FlutterTts();
  late SpeechRecognition _speech;
  bool _isListening = false;
  bool _isLoading = false;
  bool _speechRecognitionAvailable = false;
  String _lastResponse = 'Hello! I\'m your banking assistant. How can I help you today?';
  final List<Map<String, String>> _conversationHistory = [
    {'role': 'system', 'content': 'You are a helpful banking assistant. Provide concise, accurate answers about banking services.'}
  ];

  @override
  void initState() {
    super.initState();
    _initSpeechRecognition();
    _initTTS();
    _speakInitialGreeting();
  }

  void _initSpeechRecognition() {
    _speech = SpeechRecognition();

    _speech.setAvailabilityHandler((bool result) => setState(() {
      _speechRecognitionAvailable = result;
      if (!result) _isListening = false;
    }));

    _speech.setRecognitionStartedHandler(() =>
        setState(() => _isListening = true));

    _speech.setRecognitionResultHandler((String text) =>
        setState(() => _messageController.text = text));

    _speech.setRecognitionCompleteHandler((String text) =>
        setState(() => _isListening = false));

    _speech.setErrorHandler(() => setState(() {
      _isListening = false;
      _speechRecognitionAvailable = false;
    }));

    // Activate speech recognition with default locale
    _speech.activate("en_US").then((result) =>
        setState(() => _speechRecognitionAvailable = result));
  }

  Future<void> _initTTS() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);
  }

  Future<void> _speakInitialGreeting() async {
    await _tts.speak(_lastResponse);
  }

  Future<void> _sendMessageToAI(String message) async {
    if (message.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _conversationHistory.add({'role': 'user', 'content': message});
    });

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      final String aiResponse = _generateMockResponse(message);

      setState(() {
        _lastResponse = aiResponse;
        _conversationHistory.add({'role': 'assistant', 'content': aiResponse});
        _isLoading = false;
      });

      await _tts.speak(aiResponse);
    } catch (e) {
      setState(() {
        _lastResponse = "Sorry, I encountered an error processing your request.";
        _isLoading = false;
      });
      debugPrint("Error in _sendMessageToAI: $e");
    } finally {
      _messageController.clear();
    }
  }

  String _generateMockResponse(String message) {
    final String lowerMessage = message.toLowerCase();

    if (lowerMessage.contains('balance')) {
      return "Your current account balance is \$2,450.67. Would you like to know about recent transactions?";
    } else if (lowerMessage.contains('transfer')) {
      if (lowerMessage.contains('how') || lowerMessage.contains('process')) {
        return "To transfer money:\n1. Go to Transfers section\n2. Enter recipient details\n3. Enter amount\n4. Confirm and submit\nWould you like to start a transfer now?";
      }
      return "I can help you with money transfers. You'll need the recipient's account number and the amount. Ready to proceed?";
    } else if (lowerMessage.contains('deposit')) {
      if (lowerMessage.contains('mobile') || lowerMessage.contains('app')) {
        return "For mobile deposits:\n1. Select 'Deposit Check' in the app\n2. Take photos of the check\n3. Enter amount\n4. Submit\nMaximum mobile deposit is \$5,000 per day.";
      }
      return "You can deposit funds at ATMs, branches, or via mobile check deposit. Which method would you like to use?";
    } else if (lowerMessage.contains('account') || lowerMessage.contains('number')) {
      return "Your account number ends with 4567. For security, I can't share the full number here. Please check your statement or visit a branch for full details.";
    } else if (lowerMessage.contains('help') || lowerMessage.contains('support')) {
      return "I can assist with:\n- Account balances\n- Funds transfer\n- Deposits\n- Bill payments\n- Account statements\nWhat would you like help with?";
    }

    return "I'm your banking assistant. I can help with account balances, transfers, deposits, and more. Please ask me a specific banking question.";
  }

  void _toggleListening() {
    if (_isListening) {
      _speech.stop().then((result) => setState(() => _isListening = false));
    } else {
      if (_speechRecognitionAvailable) {
        _speech.listen().then((result) {
          if (!result) {
            setState(() => _isListening = false);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _tts.stop();
    _speech.cancel();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: const [
          Icon(Icons.chat, color: Colors.blue),
          SizedBox(width: 10),
          Text('Banking Assistant'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            height: 150,
            width: double.infinity,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
              child: Text(
                _lastResponse,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _messageController,
            decoration: InputDecoration(
              labelText: 'Type your message',
              suffixIcon: IconButton(
                icon: Icon(
                  _isListening ? Icons.mic_off : Icons.mic,
                  color: _isListening ? Colors.red :
                  _speechRecognitionAvailable ? Colors.blue : Colors.grey,
                ),
                onPressed: _speechRecognitionAvailable ? _toggleListening : null,
              ),
            ),
            onSubmitted: _sendMessageToAI,
          ),
        ],
      ),
      actions: [
        TextButton(
          child: const Text('Speak Again'),
          onPressed: () => _tts.speak(_lastResponse),
        ),
        TextButton(
          child: const Text('Send'),
          onPressed: () => _sendMessageToAI(_messageController.text),
        ),
      ],
    );
  }
}