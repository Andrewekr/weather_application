abstract class WeatherState {}

class WeatherInitial extends WeatherState {}

class WeatherLoading extends WeatherState {}

class WeatherLoaded extends WeatherState {
  final Map<String, dynamic> weatherData;
  WeatherLoaded(this.weatherData);
}

class WeatherError extends WeatherState {
  final String message;
  WeatherError(this.message);
}
