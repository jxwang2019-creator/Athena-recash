import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class DepositQrWidget extends StatefulWidget {
  final String url;

  const DepositQrWidget({
    required this.url,
    Key? key,
  }) : super(key: key);

  @override
  State<DepositQrWidget> createState() => _DepositQrWidgetState();
}

class _DepositQrWidgetState extends State<DepositQrWidget> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Deposit')),
      body: WebViewWidget(controller: _controller)
    );
  }
}
