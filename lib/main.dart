import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  runApp(const MaterialApp(
    home: TechnoEngineeringApp(),
    debugShowCheckedModeBanner: false,
  ));
}

class TechnoEngineeringApp extends StatefulWidget {
  const TechnoEngineeringApp({super.key});

  @override
  State<TechnoEngineeringApp> createState() => _TechnoEngineeringAppState();
}

class _TechnoEngineeringAppState extends State<TechnoEngineeringApp> {
  late final WebViewController controller;
  bool isOffline = false;
  bool isLoading = true;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  final ImagePicker _picker = ImagePicker();
  
  // Updated Vercel URL
  final String targetUrl = 'https://techno-engg-aktu.vercel.app/';

  @override
  void initState() {
    super.initState();
    _requestPermissions();

    final WebViewController webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFFFFFF))
      ..addJavaScriptChannel(
        'FlutterNativeShare',
        onMessageReceived: (JavaScriptMessage message) async {
          try {
            final data = jsonDecode(message.message);
            final String text = data['text'] ?? '';
            final String? base64Data = data['imageBase64'];

            if (base64Data != null && base64Data.isNotEmpty) {
              final cleanBase64 = base64Data.contains(',')
                  ? base64Data.split(',').last
                  : base64Data;
              final bytes = base64Decode(cleanBase64);
              final tempDir = await getTemporaryDirectory();
              final file = File('${tempDir.path}/share_image.png');
              await file.writeAsBytes(bytes);

              await Share.shareXFiles([XFile(file.path)], text: text);
            } else {
              await Share.share(text);
            }
          } catch (_) {}
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              isLoading = false;
              if (url.startsWith('http')) {
                isOffline = false;
              }
            });

            webController.runJavaScript('''
              if (window.FlutterNativeShare) {
                window.navigator.share = async function(shareData) {
                  let base64Image = null;
                  if (shareData.files && shareData.files.length > 0) {
                    const file = shareData.files[0];
                    base64Image = await new Promise((resolve) => {
                      const reader = new FileReader();
                      reader.onloadend = () => resolve(reader.result);
                      reader.readAsDataURL(file);
                    });
                  }
                  window.FlutterNativeShare.postMessage(JSON.stringify({
                    text: shareData.text || shareData.title || '',
                    imageBase64: base64Image
                  }));
                };
              }
            ''');
          },
          onWebResourceError: (WebResourceError error) {
            if (error.isForMainFrame ?? true) {
              setState(() {
                isOffline = true;
                isLoading = false;
              });
            }
          },
          onNavigationRequest: (NavigationRequest request) async {
            final String url = request.url;

            if (url.startsWith('whatsapp://') ||
                url.startsWith('intent://') ||
                url.startsWith('https://wa.me/') ||
                url.startsWith('https://api.whatsapp.com/') ||
                url.startsWith('tel:') ||
                url.startsWith('mailto:') ||
                url.startsWith('sms:')) {
              
              final Uri uri = Uri.parse(url);
              try {
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
                }
              } catch (_) {
                try {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } catch (_) {}
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );

    if (webController.platform is AndroidWebViewController) {
      final androidController = webController.platform as AndroidWebViewController;
      
      androidController.setOnPlatformPermissionRequest((request) {
        request.grant();
      });

      androidController.setOnShowFileSelector((FileSelectorParams params) async {
        try {
          final XFile? photo = await _picker.pickImage(source: ImageSource.gallery);
          if (photo != null) {
            return [Uri.file(photo.path).toString()];
          }
        } catch (_) {}
        return [];
      });
    }

    controller = webController;
    _checkInitialConnectivity();

    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final bool hasNoConnection = results.contains(ConnectivityResult.none);
      if (hasNoConnection) {
        setState(() {
          isOffline = true;
        });
      } else if (isOffline) {
        setState(() {
          isOffline = false;
        });
        controller.loadRequest(Uri.parse(targetUrl));
      }
    });
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.camera,
      Permission.photos,
      Permission.storage,
      Permission.microphone,
    ].request();
  }

  Future<void> _checkInitialConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    if (results.contains(ConnectivityResult.none)) {
      setState(() {
        isOffline = true;
      });
    } else {
      controller.loadRequest(Uri.parse(targetUrl));
    }
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            WebViewWidget(controller: controller),

            if (isLoading && !isOffline)
              Container(
                color: Colors.white,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.engineering_rounded, size: 80, color: Color(0xFF2563EB)),
                      SizedBox(height: 16),
                      Text(
                        'Techno Engineering',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                      SizedBox(height: 24),
                      CircularProgressIndicator(color: Color(0xFF2563EB)),
                    ],
                  ),
                ),
              ),

            if (isOffline)
              Container(
                color: Colors.white,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off_rounded, size: 50, color: Colors.grey),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() => isOffline = false);
                          _checkInitialConnectivity();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
