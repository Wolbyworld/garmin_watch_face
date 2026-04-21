# Watch Face TODO

## Future Enhancements

### Day/Night Band Improvement
- Current thin bar (6px) may be too subtle
- Options to consider:
  - Make taller (10-15px)
  - Add gradient transition between day/night
  - Extend color into chart background area
  - Add sun/moon icons at sunrise/sunset

### WeatherService Retry on Failure
- Add retry logic when Open-Meteo API requests fail
- Consider exponential backoff for repeated failures
- Track consecutive failures and surface to user if persistent

### General Visual Polish
- Consistent spacing throughout all elements
- Color refinements based on real device testing
- Font size adjustments for readability

### Location Setting
- Add configurable default location (currently falls back to Pozuelo de Alarcon)
- Allow lat/lon entry or city selection
