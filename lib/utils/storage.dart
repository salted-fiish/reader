import 'package:shared_preferences/shared_preferences.dart';

class Storage {
  static Future<void> saveLastPage(String pdfPath, int page) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(pdfPath, page);
  }

  static Future<int> getLastPage(String pdfPath) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt(pdfPath) ?? 0;
  }
}
