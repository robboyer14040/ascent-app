//LatLong- UTM conversion..h
//definitions for lat/long to UTM and UTM to lat/lng conversions

#ifndef LATLONGCONV
#define LATLONGCONV

void LLtoUTM(int ReferenceEllipsoid, const double Lat, const double Long, 
			 double *UTMNorthing, double *UTMEasting, char* UTMZone, int* zoneAsInt);
void UTMtoLL(int ReferenceEllipsoid, const double UTMNorthing, const double UTMEasting, const char* UTMZone,
			  double* Lat,  double* Long );
char UTMLetterDesignator(double Lat);


#endif
