/// Plain label for a WMO weather code (as used by Open-Meteo).
String weatherLabel(int code) => switch (code) {
  0 => 'Clear',
  1 => 'Mostly clear',
  2 => 'Partly cloudy',
  3 => 'Cloudy',
  45 || 48 => 'Fog',
  >= 51 && <= 57 => 'Drizzle',
  >= 61 && <= 67 => 'Rain',
  >= 71 && <= 77 => 'Snow',
  >= 80 && <= 82 => 'Showers',
  >= 95 => 'Thunderstorm',
  _ => 'Unknown',
};
