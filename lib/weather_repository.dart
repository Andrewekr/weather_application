import 'package:http/http.dart' as http;
import 'dart:convert';

class WeatherRepository {
  final String apiKey;

  WeatherRepository(this.apiKey);

  Future<Map<String, dynamic>> fetchWeather(String cityName) async {
    final uri = Uri.https('api.openweathermap.org', '/data/2.5/weather',
        {'q': cityName, 'appid': apiKey, 'units': 'metric'});

    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Error fetching weather data');
    }
  }
}
