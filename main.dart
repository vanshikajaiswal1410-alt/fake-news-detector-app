import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(FakeNewsApp());
}

class FakeNewsApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI Fake News Detector',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget { 
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  TextEditingController controller = TextEditingController();

  String result = "";
  String explanation = "";
  bool loading = false;

  List articles = [];

  late stt.SpeechToText speech;
  bool isListening = false;

  // 🔑 ADD YOUR KEYS HERE
  final String openRouterKey = "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";
  final String newsApiKey = "26a690bdb2914934affc228a3cabe791";

  @override
  void initState() {
    super.initState();
    speech = stt.SpeechToText();
    fetchNews();
  }

  // 🎙️ Voice Input
  void startListening() async {
    bool available = await speech.initialize();
    if (available) {
      setState(() => isListening = true);
      speech.listen(onResult: (val) {
        controller.text = val.recognizedWords;
      });
    }
  }

  void stopListening() {
    speech.stop();
    setState(() => isListening = false);
  }

  // 🧠 AI Detection
  Future<void> analyzeNews(String text) async {
    if (text.isEmpty) return;

    setState(() => loading = true);

    try {
      final response = await http.post(
        Uri.parse(
          "https://cors-anywhere.herokuapp.com/https://openrouter.ai/api/v1/chat/completions",
        ),
        headers: {
          "Authorization": "Bearer $openRouterKey",
          "Content-Type": "application/json",
          "HTTP-Referer": "http://localhost",
          "X-Title": "Fake News Detector App"
        },
        body: jsonEncode({
          "model": "openai/gpt-3.5-turbo",
          "messages": [
            {
              "role": "user",
              "content":
                  "Check if this news is Fake or Real and explain shortly:\n$text"
            }
          ]
        }),
      );

      print(response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        String aiText =
            data['choices'][0]['message']['content'];

        setState(() {
          result = aiText.toLowerCase().contains("fake")
              ? "❌ Fake News"
              : "✅ Real News";
          explanation = aiText;
        });
      } else {
        setState(() {
          result = "❌ API Error (${response.statusCode})";
          explanation = response.body;
        });
      }
    } catch (e) {
      setState(() {
        result = "❌ Error";
        explanation = e.toString();
      });
    }

    setState(() => loading = false);
  }

  // 🌐 URL Checker
  void checkUrlNews() {
    String url = controller.text;

    if (!url.startsWith("http")) {
      setState(() {
        result = "❌ Invalid URL";
        explanation = "Enter valid URL (http/https)";
      });
      return;
    }

    analyzeNews("Analyze this news from URL:\n$url");
  }

  // 📰 Live News
  Future<void> fetchNews() async {
    try {
      final response = await http.get(
        Uri.parse(
          "https://cors-anywhere.herokuapp.com/https://newsapi.org/v2/top-headlines?country=in&apiKey=$newsApiKey",
        ),
      );

      final data = jsonDecode(response.body);

      setState(() {
        articles = data['articles'] ?? [];
      });
    } catch (e) {
      print(e);
    }
  }

  // 🔗 Open URL
  void openUrl(String url) async {
    await launchUrl(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("AI Fake News Detector"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [

            // INPUT
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: "Paste news text or URL...",
                border: OutlineInputBorder(),
              ),
            ),

            SizedBox(height: 10),

            // BUTTONS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: () => analyzeNews(controller.text),
                  child: Text("Check AI"),
                ),
                ElevatedButton(
                  onPressed: checkUrlNews,
                  child: Text("Check URL"),
                ),
                IconButton(
                  icon: Icon(
                    isListening ? Icons.mic : Icons.mic_none,
                    color: Colors.red,
                  ),
                  onPressed:
                      isListening ? stopListening : startListening,
                )
              ],
            ),

            SizedBox(height: 20),

            // RESULT
            loading
                ? CircularProgressIndicator()
                : Column(
                    children: [
                      Text(result,
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                      SizedBox(height: 10),
                      Text(explanation),
                    ],
                  ),

            SizedBox(height: 20),
            Divider(),

            // NEWS
            Text("📰 Live News",
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),

            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: articles.length,
              itemBuilder: (_, i) {
                return Card(
                  child: ListTile(
                    title: Text(articles[i]['title'] ?? ""),
                    subtitle:
                        Text(articles[i]['source']['name'] ?? ""),
                    onTap: () =>
                        openUrl(articles[i]['url']),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}