//
//  WeatherAPI.h
//  Ascent
//  MRC (non-ARC)
//

#import <Cocoa/Cocoa.h>
#import <CoreLocation/CoreLocation.h>

@class Track;

NS_ASSUME_NONNULL_BEGIN

/// Result keys
extern NSString * const kWXSource;         // @"Open-Meteo ERA5"
extern NSString * const kWXTempC;          // NSNumber(double) average °C
extern NSString * const kWXWindKph;        // NSNumber(double) average km/h
extern NSString * const kWXHumidityPct;    // NSNumber(double) average %
extern NSString * const kWXPrecipMm;       // NSNumber(double) total mm over activity window
extern NSString * const kWXCode;           // NSNumber(int) modal WMO code
extern NSString * const kWXDesc;           // NSString description for WMO code
extern NSString * const kWXStartLocal;     // NSString ISO8601 local (derived using secondsFromGMT)
extern NSString * const kWXEndLocal;       // NSString ISO8601 local
extern NSString * const kWXStartUTC;       // NSString ISO8601 Z
extern NSString * const kWXEndUTC;         // NSString ISO8601 Z
extern NSString * const kWXNumSamples;     // NSNumber(int) count of spatial samples used

@interface WeatherAPI : NSObject

/// Fetch weather for a Track by sampling valid lat/lon points along the route.
/// Performs synchronous network I/O; call from a background queue.
///
/// @param track The Track instance (uses creationTime, secondsFromGMT, duration, and points).
/// @param outError NSError** populated on failure.
/// @return NSDictionary with keys above, or nil on error.
+ (nullable NSDictionary *)fetchWeatherForTrack:(Track *)track
                                          error:(NSError * _Nullable * _Nullable)outError;

// Per-hour item keys (for timeline)
FOUNDATION_EXPORT NSString * const kWXTimeUTC;     // NSString "yyyy-MM-dd'T'HH:mm:ss'Z'"
FOUNDATION_EXPORT NSString * const kWXTItems;      // NSArray<NSDictionary*>, each element uses kWXTimeUTC, kWXTempC, kWXWindKph, kWXHumidityPct, kWXPrecipMm, kWXCode

/// Returns an hourly timeline (averaged across sampled locations) for the activity window.
/// Synchronous; call off the main thread.
+ (nullable NSArray *)fetchWeatherTimelineForTrack:(Track *)track
                                             error:(NSError * _Nullable * _Nullable)outError;


/// Public utility: convert WMO weather_code to a readable label.
+ (NSString *)stringForWeatherCode:(NSInteger)code;



#
// Reuse existing kGeo* keys for each location dictionary
FOUNDATION_EXPORT NSString * const kGeoCity;         // @"city"
FOUNDATION_EXPORT NSString * const kGeoCountry;      // @"country"
FOUNDATION_EXPORT NSString * const kGeoCountryCode;  // @"country_code"
FOUNDATION_EXPORT NSString * const kGeoAdmin;        // @"admin"
FOUNDATION_EXPORT NSString * const kGeoLatitude;     // @"lat"
FOUNDATION_EXPORT NSString * const kGeoLongitude;    // @"lon"

// Container keys
FOUNDATION_EXPORT NSString * const kGeoStart;        // @"start" -> NSDictionary (kGeoCity, ...)
FOUNDATION_EXPORT NSString * const kGeoEnd;          // @"end"   -> NSDictionary (kGeoCity, ...)

/// Synchronous (blocks); call off the main thread.
/// Returns @{ kGeoStart: <dict>, kGeoEnd: <dict> } or nil + error.
+ (nullable NSDictionary *)startEndCityCountryForTrack:(Track *)track
                                                error:(NSError * _Nullable * _Nullable)outError;


@end

NS_ASSUME_NONNULL_END
