//const String baseUrl = 'http://192.168.2.4:8000';
//const String baseUrl = 'http://10.17.123.176:8000';
//const String baseUrl = 'https://310cf0598f91.ngrok-free.app';

import 'package:flutter_dotenv/flutter_dotenv.dart';



class AppConfig {
  static String get baseUrl {
    return dotenv.env['BASE_URL'] ??
           'http://10.17.123.176:8000';
  }
}
