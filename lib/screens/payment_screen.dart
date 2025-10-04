import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/payment_service.dart';

class PaymentScreen extends StatefulWidget {
  final double amount;
  final String orderId;
  final String customerName;
  final String customerEmail;
  final String customerMobile;
  final String description;

  const PaymentScreen({
    Key? key,
    required this.amount,
    required this.orderId,
    required this.customerName,
    required this.customerEmail,
    required this.customerMobile,
    required this.description,
  }) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late WebViewController _webViewController;
  bool _isLoading = true;
  bool _paymentInitiated = false;
  String? _basketId;
  final PaymentService _paymentService = PaymentService();

  @override
  void initState() {
    super.initState();
    _initializeWebView();
    _initiatePayment();
  }

  void _initializeWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading bar if needed
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
            _checkIfPaymentComplete(url);
          },
          onNavigationRequest: (NavigationRequest request) {
            _checkIfPaymentComplete(request.url);
            return NavigationDecision.navigate;
          },
        ),
      );
  }

  void _checkIfPaymentComplete(String url) {
    // Check if URL contains success or failure indicators
    if (url.contains('payment/success') || url.contains('success')) {
      _handlePaymentSuccess(url);
    } else if (url.contains('payment/failure') || url.contains('failure')) {
      _handlePaymentFailure(url);
    }
  }

  void _handlePaymentSuccess(String url) async {
    // Extract payment details from URL if available
    final uri = Uri.parse(url);
    final transactionId = uri.queryParameters['transaction_id'];

    if (_basketId != null) {
      // Verify payment status from backend
      final statusResponse = await _paymentService.checkPaymentStatus(
        basketId: _basketId!,
      );

      if (statusResponse['success'] == true) {
        _showPaymentResult(
          success: true,
          message: 'Payment completed successfully!',
          transactionId: transactionId ?? statusResponse['transaction_id'],
        );
      } else {
        _showPaymentResult(
          success: false,
          message: 'Payment verification failed',
        );
      }
    }
  }

  void _handlePaymentFailure(String url) {
    final uri = Uri.parse(url);
    final errorMessage = uri.queryParameters['err_msg'] ?? 'Payment failed';

    _showPaymentResult(
      success: false,
      message: errorMessage,
    );
  }

  void _showPaymentResult({
    required bool success,
    required String message,
    String? transactionId,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(success ? 'Payment Successful' : 'Payment Failed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error,
              color: success ? Colors.green : Colors.red,
              size: 60,
            ),
            const SizedBox(height: 16),
            Text(message),
            if (transactionId != null) ...[
              const SizedBox(height: 8),
              Text(
                'Transaction ID: $transactionId',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context)
                  .pop(success); // Return result to previous screen
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _initiatePayment() async {
    try {
      final response = await _paymentService.initiatePayment(
        amount: widget.amount,
        customerName: widget.customerName,
        customerEmail: widget.customerEmail,
        customerMobile: widget.customerMobile,
        orderId: widget.orderId,
        description: widget.description,
      );

      if (response['success'] == true) {
        _basketId = response['basket_id'];
        final formData = response['form_data'] as Map<String, dynamic>;
        final paymentUrl = response['payment_url'] as String;

        _loadPaymentForm(paymentUrl, formData);
      } else {
        _showError(response['message'] ?? 'Failed to initiate payment');
      }
    } catch (e) {
      _showError('Error initiating payment: $e');
    }
  }

  void _loadPaymentForm(String paymentUrl, Map<String, dynamic> formData) {
    final formHtml = _buildFormHtml(paymentUrl, formData);

    _webViewController.loadHtmlString(formHtml);

    setState(() {
      _paymentInitiated = true;
    });
  }

  String _buildFormHtml(String paymentUrl, Map<String, dynamic> formData) {
    final formBuilder = StringBuffer();
    formBuilder.write('''
      <html>
      <body onload="document.getElementById('payfast_form').submit();">
      <div style="text-align: center; padding: 20px;">
        <h3>Redirecting to Payment Gateway...</h3>
        <p>Please wait while we redirect you to the payment page.</p>
      </div>
      <form id="payfast_form" action="$paymentUrl" method="POST">
    ''');

    formData.forEach((key, value) {
      formBuilder.write('<input type="hidden" name="$key" value="$value"/>');
    });

    formBuilder.write('''
      </form>
      </body>
      </html>
    ''');

    return formBuilder.toString();
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(false);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Gateway'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            Navigator.of(context).pop(false);
          },
        ),
      ),
      body: Stack(
        children: [
          if (_paymentInitiated)
            WebViewWidget(controller: _webViewController)
          else
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Initializing Payment...'),
                ],
              ),
            ),
          if (_isLoading && _paymentInitiated)
            Container(
              color: Colors.white.withOpacity(0.8),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading Payment Page...'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
