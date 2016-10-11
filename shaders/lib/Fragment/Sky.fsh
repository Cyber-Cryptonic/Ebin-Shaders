float CalculateSunglow(vec3 worldSpaceVector) {
	float sunglow = max0(dot(worldSpaceVector, worldLightVector) - 0.01);
	      sunglow = pow(sunglow, 8.0);
	
	return sunglow;
}

vec3 CalculateSkyGradient(vec3 worldSpacePosition, float sunglow) {
#ifdef CUSTOM_HORIZON_HEIGHT
	float radius = max(176.0, far * sqrt(2.0));
	
	worldSpacePosition   *= radius / length(worldSpacePosition.xz); // Reproject the world vector to have a consistent horizon height
	worldSpacePosition.y += cameraPosition.y - HORIZON_HEIGHT;
#endif
	
	
	float gradientCoeff = pow(1.0 - abs(normalize(worldSpacePosition).y) * 0.5, 4.0);
	
	vec3 primaryHorizonColor  = SetSaturationLevel(skylightColor, mix(1.0, 0.5, gradientCoeff * timeDay));
	     primaryHorizonColor  = SetSaturationLevel(primaryHorizonColor, mix(1.0, 1.1, timeDay));
	     primaryHorizonColor *= (1.0 + gradientCoeff * 0.5);
	     primaryHorizonColor  = mix(primaryHorizonColor, sunlightColor, gradientCoeff * sunglow * timeDay);
	
	vec3 sunglowColor = mix(skylightColor, sunlightColor * 0.5, gradientCoeff * sunglow) * sunglow;
	
	vec3 color  = primaryHorizonColor * gradientCoeff * 8.0;
	     color *= 1.0 + sunglowColor * 2.0;
	     color += sunglowColor * 5.0;
	
	return color * 0.9;
}

vec3 CalculateSunspot(vec3 worldSpaceVector) {
	float sunspot  = max0(dot(worldSpaceVector, worldLightVector) - 0.01);
	      sunspot  = pow(sunspot, 350.0);
	      sunspot  = pow(sunspot + 1.0, 400.0) - 1.0;
	      sunspot  = min(sunspot, 20.0);
	      sunspot += 100.0 * float(sunspot == 20.0);
	
	return sunspot * sunlightColor * sunlightColor * vec3(1.0, 0.8, 0.6);
}

vec3 CalculateAtmosphereScattering(vec3 position) {
	float factor = pow(length(position), 1.4) * 0.0001 * ATMOSPHERIC_SCATTERING_AMOUNT;
	
	return pow(skylightColor, vec3(2.5)) * factor;
}

#include "/lib/Fragment/Clouds.fsh"

#include "/lib/Fragment/Atmosphere.fsh"

vec3 CalculateAtmosphericSky(vec3 worldSpacePosition) {
	vec3 worldPosition = vec3(0.0, planetRadius + 1.061e3 + max0(cameraPosition.y - HORIZON_HEIGHT) * 400.0, 0.0);
	
	return ComputeAtmosphericSky(worldSpacePosition, worldPosition, sunVector, 2.0);
}


vec3 CalculateSky(mat2x3 position, vec3 rayPosition, float alpha, cbool reflection, float sunlight) {
	float visibility = CalculateFogFactor(position[0], FOG_POWER);
	if (  visibility < 0.001 && !reflection) return vec3(0.0);
	
	
	vec3 worldSpaceVector = normalize(position[1]);
	
	float sunglow = CalculateSunglow(worldSpaceVector);
	
	vec3 clouds = Compute2DCloudPlane(position[1], worldSpaceVector, rayPosition, sunglow);
	
#ifdef PHYSICAL_ATMOSPHERE
	vec3 gradient = CalculateAtmosphericSky(position[1]);
	vec3 sunspot  = vec3(0.0);
#else
	vec3 gradient = CalculateSkyGradient(position[1], sunglow);
	vec3 sunspot  = CalculateSunspot(worldSpaceVector) * (reflection ? sunlight : pow(visibility, 25) * alpha);
#endif
	
	return (gradient + sunspot + clouds) * SKY_BRIGHTNESS;
}
