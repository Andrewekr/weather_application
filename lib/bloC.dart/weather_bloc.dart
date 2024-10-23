import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:weather_application/bloC.dart/weather_event.dart';
import 'package:weather_application/weather_repository.dart';
import 'package:weather_application/bloC.dart/weather_state.dart';

class WeatherBloc extends Bloc<WeatherEvent, WeatherState> {
  final WeatherRepository weatherRepository;

  WeatherBloc(this.weatherRepository) : super(WeatherInitial()) {
    on<FetchWeather>((event, emit) async {
      emit(WeatherLoading());
      try {
        final weatherData =
            await weatherRepository.fetchWeather(event.cityName);
        emit(WeatherLoaded(weatherData));
      } catch (e) {
        emit(WeatherError("Failed to load weather"));
      }
    });
  }
}
