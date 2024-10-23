import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_application/bloC.dart/weather_bloc.dart';
import 'weather_repository.dart';
import 'package:carousel_slider/carousel_slider.dart';

// Основная функция приложения
void main() {
  runApp(
    MultiProvider(
      providers: [
        // Создайте провайдер для WeatherRepository
        Provider(
            create: (_) =>
                WeatherRepository('6a2a15757035efc9a42f7f7509936bbf')),
        // Создайте BlocProvider для WeatherBloc
        BlocProvider(
            create: (context) =>
                WeatherBloc(context.read<WeatherRepository>())),
      ],
      child: const MyApp(),
    ),
  );
}

// Основной виджет приложения
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Weather App',
      theme: ThemeData(
        useMaterial3: true,
      ),
      // Настройка локализаций
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('ru'),
      ],
      home: const WeatherScreen(),
    );
  }
}

// Класс для предложений по городам
class CitySuggestion {
  final String name;
  final String? state;
  final String country;

  CitySuggestion({required this.name, this.state, required this.country});

  factory CitySuggestion.fromJson(Map<String, dynamic> json) {
    return CitySuggestion(
      name: json['name'],
      state: json['state'],
      country: json['country'],
    );
  }

  @override
  String toString() {
    return '$name, ${state ?? country}';
  }
}

// Экран прогноза погоды
class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final TextEditingController _cityController = TextEditingController();
  String? _cityName;
  Map<String, dynamic>? _currentWeatherData;
  List<dynamic>? _forecastData;
  String? _errorMessage;
  bool _isLoading = false;
  List<CitySuggestion>? _citySuggestions;
  Locale _currentLocale = const Locale('en');

  @override
  void initState() {
    super.initState();
    _loadSavedCity();
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  // Загрузка сохранённого города
  Future<void> _loadSavedCity() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedCity = prefs.getString('savedCity');
    if (savedCity != null && savedCity.isNotEmpty) {
      _cityController.text = savedCity;
      _fetchWeather();
    }
  }

  // Сохранение города
  Future<void> _saveCity(String city) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('savedCity', city);
  }

  // Получение предложений по городам
  Future<void> _fetchCitySuggestions(String query) async {
    if (query.isEmpty) {
      setState(() {
        _citySuggestions = null;
      });
      return;
    }

    final uri = Uri.https(
        'api.openweathermap.org', '/geo/1.0/direct', <String, String>{
      'q': query,
      'limit': '5',
      'appid': '6a2a15757035efc9a42f7f7509936bbf'
    });

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> jsonList =
            json.decode(response.body) as List<dynamic>;
        setState(() {
          _citySuggestions =
              jsonList.map((json) => CitySuggestion.fromJson(json)).toList();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Не удалось загрузить предложения по городам: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки предложений по городам: $e')),
      );
    }
  }

  // Получение данных о погоде
  Future<void> _fetchWeather() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _citySuggestions = null;
    });

    _cityName = _cityController.text;

    try {
      final currentWeatherUri = Uri.https(
          'api.openweathermap.org', '/data/2.5/weather', <String, String>{
        'q': _cityName!,
        'appid': '6a2a15757035efc9a42f7f7509936bbf',
        'units': 'metric'
      });
      final forecastUri = Uri.https(
          'api.openweathermap.org', '/data/2.5/forecast', <String, String>{
        'q': _cityName!,
        'appid': '6a2a15757035efc9a42f7f7509936bbf',
        'units': 'metric'
      });

      final currentWeatherResponse = await http.get(currentWeatherUri);
      final forecastResponse = await http.get(forecastUri);

      if (currentWeatherResponse.statusCode == 200 &&
          forecastResponse.statusCode == 200) {
        setState(() {
          _currentWeatherData =
              json.decode(currentWeatherResponse.body) as Map<String, dynamic>;
          _forecastData = (json.decode(forecastResponse.body)
              as Map<String, dynamic>)['list'];
          _saveCity(_cityName!);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Не удалось загрузить данные о погоде';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка: $e';
        _isLoading = false;
      });
    }
  }

  // Форматирование даты и времени
  String _formatDateTime(int dt) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(dt * 1000);
    return DateFormat('HH:mm').format(dateTime);
  }

  // Форматирование дня
  String _formatDay(int dt) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(dt * 1000);
    return DateFormat('EEEE').format(dateTime);
  }

  // Получение ежедневного прогноза
  List<dynamic> _getDailyForecasts() {
    final Map<String, dynamic> dailyForecasts = {};
    if (_forecastData != null) {
      for (final forecast in _forecastData!) {
        final dateKey = DateFormat('yyyy-MM-dd')
            .format(DateTime.fromMillisecondsSinceEpoch(forecast['dt'] * 1000));
        dailyForecasts[dateKey] = forecast;
      }
    }
    return dailyForecasts.values.toList();
  }

  // Получение почасового прогноза
  List<dynamic> _getHourlyForecasts() {
    if (_forecastData == null) return [];
    return _forecastData!
        .where((item) => DateTime.fromMillisecondsSinceEpoch(item['dt'] * 1000)
            .isBefore(DateTime.now().add(const Duration(days: 1))))
        .toList();
  }

  // Переключение локализации
  void _toggleLocale() {
    setState(() {
      _currentLocale = _currentLocale.languageCode == 'en'
          ? const Locale('ru')
          : const Locale('en');
    });
  }

  // Получение переведённой строки
  String _getTranslatedString(String en, String ru) {
    return _currentLocale.languageCode == 'en' ? en : ru;
  }

  // Получение иконки погоды
  Widget getWeatherIcon(int code) {
    if (code >= 200 && code < 300) {
      return Image.asset('assets/1.png');
    } else if (code >= 300 && code < 400) {
      return Image.asset('assets/2.png');
    } else if (code >= 500 && code < 600) {
      return Image.asset('assets/3.png');
    } else if (code >= 600 && code < 700) {
      return Image.asset('assets/4.png');
    } else if (code >= 700 && code < 800) {
      return Image.asset('assets/5.png');
    } else if (code == 800) {
      return Image.asset('assets/6.png');
    } else if (code > 800 && code <= 804) {
      return Image.asset('assets/7.png');
    } else {
      return Image.asset('assets/7.png');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getTranslatedString('Weather App', 'Прогноз погоды')),
        actions: [
          IconButton(
            icon: Icon(
              _currentLocale.languageCode == 'en'
                  ? Icons.language
                  : Icons.language,
            ),
            onPressed: _toggleLocale,
          ),
        ],
        backgroundColor: Colors.purple.shade700,
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          bool isWideScreen = constraints.maxWidth > 600;

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: _currentWeatherData != null
                    ? [Colors.orange.shade200, Colors.purple.shade700]
                    : [Colors.grey.shade300, Colors.blueGrey.shade700],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Autocomplete<CitySuggestion>(
                          optionsBuilder:
                              (TextEditingValue textEditingValue) async {
                            if (textEditingValue.text.isNotEmpty) {
                              await _fetchCitySuggestions(
                                  textEditingValue.text);
                              return _citySuggestions ??
                                  const Iterable<CitySuggestion>.empty();
                            } else {
                              return const Iterable<CitySuggestion>.empty();
                            }
                          },
                          displayStringForOption: (CitySuggestion option) =>
                              option.toString(),
                          fieldViewBuilder: (BuildContext context,
                              TextEditingController fieldTextEditingController,
                              FocusNode fieldFocusNode,
                              VoidCallback onFieldSubmitted) {
                            return TextField(
                              controller: fieldTextEditingController,
                              focusNode: fieldFocusNode,
                              decoration: InputDecoration(
                                  hintText: _getTranslatedString(
                                      'Введите название города',
                                      'Enter city name')),
                              onChanged: (value) {
                                _fetchCitySuggestions(value);
                              },
                              onSubmitted: (_) {
                                _fetchWeather();
                                onFieldSubmitted();
                              },
                            );
                          },
                          onSelected: (CitySuggestion selection) {
                            _cityController.text = selection.name;
                            _fetchWeather();
                          },
                        ),
                        const SizedBox(height: 20),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                    _cityName ??
                                        _getTranslatedString(
                                            "Ваш город", "Your city"),
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 32)),
                                Text(
                                  _getTranslatedString(
                                      "Доброе утро", "Good Morning"),
                                  style: const TextStyle(
                                      fontSize: 24, color: Colors.white),
                                ),
                              ],
                            ),
                            const SizedBox(height: 40),
                            if (_currentWeatherData != null)
                              Column(
                                children: [
                                  Text(
                                      '${_currentWeatherData!['main']['temp']}°C',
                                      style: const TextStyle(
                                          fontSize: 64,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white)),
                                  getWeatherIcon(
                                      _currentWeatherData!['weather'][0]['id']),
                                  Text(
                                      _currentWeatherData!['weather'][0]
                                          ['description'],
                                      style: const TextStyle(
                                          fontSize: 20, color: Colors.white)),
                                  Text(
                                      DateFormat('EEEE dd - HH:mm a')
                                          .format(DateTime.now()),
                                      style:
                                          const TextStyle(color: Colors.white)),
                                ],
                              )
                            else
                              Text(
                                _getTranslatedString(
                                    "Загрузка данных о погоде...",
                                    "Loading weather data..."),
                                style: const TextStyle(
                                    fontSize: 20, color: Colors.white),
                              ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    const Icon(Icons.wb_sunny,
                                        color: Colors.orange),
                                    Text(
                                        _getTranslatedString(
                                            "Восход", "Sunrise"),
                                        style: const TextStyle(
                                            color: Colors.white)),
                                    Text(
                                        _currentWeatherData != null
                                            ? _formatDateTime(
                                                _currentWeatherData!['sys']
                                                    ['sunrise'])
                                            : "5:34 am",
                                        style: const TextStyle(
                                            color: Colors.white)),
                                  ],
                                ),
                                Column(
                                  children: [
                                    const Icon(Icons.nightlight_round,
                                        color: Colors.blue),
                                    Text(
                                        _getTranslatedString("Закат", "Sunset"),
                                        style: const TextStyle(
                                            color: Colors.white)),
                                    Text(
                                        _currentWeatherData != null
                                            ? _formatDateTime(
                                                _currentWeatherData!['sys']
                                                    ['sunset'])
                                            : "6:34 pm",
                                        style: const TextStyle(
                                            color: Colors.white)),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            if (_forecastData != null)
                              Column(
                                children: [
                                  Text(
                                    _getTranslatedString(
                                        "Почасовой прогноз", "Hourly Forecast"),
                                    style: const TextStyle(
                                        fontSize: 20, color: Colors.white),
                                  ),
                                  const SizedBox(height: 10),
                                  CarouselSlider(
                                    options: CarouselOptions(
                                      height: 350,
                                      enlargeCenterPage: true,
                                      autoPlay: true,
                                      autoPlayInterval:
                                          const Duration(seconds: 2),
                                    ),
                                    items: _getHourlyForecasts()
                                        .map((forecastItem) {
                                      return Builder(
                                        builder: (BuildContext context) {
                                          return Card(
                                            color:
                                                Colors.white.withOpacity(0.8),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(1.0),
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    _formatDateTime(
                                                        forecastItem['dt']),
                                                    style: const TextStyle(
                                                        fontSize: 18),
                                                  ),
                                                  getWeatherIcon(
                                                      forecastItem['weather'][0]
                                                          ['id']),
                                                  Text(
                                                    'Темп: ${forecastItem['main']['temp'].round()}°C',
                                                    style: const TextStyle(
                                                        fontSize: 16),
                                                  ),
                                                  Text(
                                                    'Влажность: ${forecastItem['main']['humidity']}%',
                                                    style: const TextStyle(
                                                        fontSize: 16),
                                                  ),
                                                  Text(
                                                    'Ветер: ${forecastItem['wind']['speed']} м/с',
                                                    style: const TextStyle(
                                                        fontSize: 16),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 20),
                                  if (_forecastData != null)
                                    Column(
                                      children: _getDailyForecasts()
                                          .take(7)
                                          .map((forecastItem) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8.0),
                                          child: Card(
                                            child: ListTile(
                                              leading: getWeatherIcon(
                                                  forecastItem['weather'][0]
                                                      ['id']),
                                              title: Text(
                                                _formatDay(forecastItem['dt']),
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                              subtitle: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                      'Темп: ${forecastItem['main']['temp'].round()}°C'),
                                                  Text(
                                                      'Ветер: ${forecastItem['wind']['speed']} м/с'),
                                                  Text(
                                                      'Влажность: ${forecastItem['main']['humidity']}%'),
                                                  Text(
                                                      'Дождь: ${forecastItem['rain'] != null ? forecastItem['rain']['3h'] ?? 0 : 0} мм'),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        if (_isLoading)
                          const Center(child: CircularProgressIndicator())
                        else if (_errorMessage != null)
                          Center(child: Text(_errorMessage!)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
