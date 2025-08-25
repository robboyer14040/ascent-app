/*
 *  OverrideDefs.h - values that can overridden in a track by the user, effectively causing data 
 *    retieved from track points (if any) to be ignored
 *  Ascent
 *
 *  Created by Rob Boyer on 9/1/07.
 *  Copyright 2007 __MyCompanyName__. All rights reserved.
 *
 */

enum
{
   kOD_ElapsedTime   = 0,
   kOD_MovingTime,
   kOD_Distance,        
   kOD_Climb,
   kOD_Descent,
   kOD_AltitudeMax,     // 5
   kOD_AltitudeMin,             
   kOD_HeartRateMax,
   kOD_HeartRateAvg,
   kOD_SpeedMax,
   kOD_SpeedAvg,        // 10
   kOD_PaceMin,                  
   kOD_PaceAvg,
   kOD_CadenceMax,
   kOD_CadenceAvg,
   kOD_GradientMax,     // 15
   kOD_GradientMin,              
   kOD_GradientAvg,
   kOD_TemperatureMax,
   kOD_TemperatureMin,
   kOD_TemperatureAvg,  // 20
   kOD_Calories,
   // add new override items here
   
   kOD_NumValues     // MUST BE LAST
};

