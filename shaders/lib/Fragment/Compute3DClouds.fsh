#define CLOUD3D_DITHER ON // [ON OFF]

float GetCloudDither(vec2 offset) {
	if (!CLOUD3D_DITHER) return 0.0;
	
	const int[16] ditherPattern = int[16] (
		 0,  8,  2, 10,
		12,  4, 14,  6,
		 3, 11,  1,  9,
		15,  7, 13,  5);
	
	ivec2 count = ivec2(mod(gl_FragCoord.st + offset * mix(vec2(-1.0), vec2(1.0), equal(ivec2(gl_FragCoord.st) % ivec2(2), ivec2(0))), vec2(4.0)));
	
	int dither = ditherPattern[count.x + count.y * 4] + 1;
	
	return float(dither) / 17.0;
}

float Get2DNoise(vec3 pos) { // 2D slices
	return texture2D(noisetex, pos.xz * noiseResInverse).x;
}

float Get2DStretchNoise(vec3 pos) {
	const float zStretch = 15.0 * noiseResInverse;
	
	vec2 coord = pos.xz * noiseResInverse + (floor(pos.y) * zStretch);
	
	return texture2D(noisetex, coord).x;
}

float Get2_5DNoise(vec3 pos) { // 2.5D
	float p = floor(pos.y);
	float f = pos.y - p;
	
	const float zStretch = 17.0 * noiseResInverse;
	
	vec2 coord = pos.xz * noiseResInverse + (p * zStretch);
	
	vec2 noise = texture2D(noisetex, coord).xy;
	
	return mix(noise.x, noise.y, f);
}

float Get3DNoise(vec3 pos) {
	float p = floor(pos.z);
	float f = pos.z - p;
	
	const float zStretch = 17.0 * noiseResInverse;
	
	vec2 coord = pos.xy * noiseResInverse + (p * zStretch);
	
	vec2 noise = vec2(texture2D(noisetex, coord).x,
	                  texture2D(noisetex, coord + zStretch).x);
	
	return mix(noise.x, noise.y, f);
}

float GetCustom3DNoise(vec3 pos) {
	float p = floor(pos.z);
	float f = pos.z - p;
	
	const float zStretch = 17.0 * noiseResInverse;
	
	vec2 coord = pos.xy * noiseResInverse + (p * zStretch);
	
	vec2 noise = texture2D(colortex7, coord).xy;
	
	return mix(noise.x, noise.y, f);
}

#define CloudNoise GetCustom3DNoise // [Get2DNoise Get2DStretchNoise Get2_5DNoise Get3DNoise GetCustom3DNoise]


#define CLOUD1_DENSITY   0.95 // [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 0.97 0.99]

float GetCoverage(float coverage, float clouds) {
	cfloat denseFactor = 1.0 / (1.0 - CLOUD1_DENSITY);
	
	return clamp01((clouds + coverage - 1.0) * denseFactor);
}

mat4x3 cloudMul = mat4x3(0.0);
mat4x3 cloudAdd = mat4x3(0.0);

vec3 directColor  = vec3(0.0);
vec3 ambientColor = vec3(0.0);
vec3 bouncedColor = vec3(0.0);

vec4 CloudColor(vec3 worldPosition, cfloat cloudLowerHeight, cfloat cloudDepth, float coverage, float sunglow) {
	cfloat cloudCenter = cloudLowerHeight + cloudDepth * 0.5;
	
	float cloudAltitudeWeight = clamp01(distance(worldPosition.y, cloudCenter) / (cloudDepth / 2.0));
	      cloudAltitudeWeight = pow(1.0 - cloudAltitudeWeight, 0.33);
	
	vec4 cloud;
	
	mat4x3 p;
	
	cfloat[5] weights = float[5](1.3, -0.7, -0.255, -0.105, 0.04);
	
	vec3 w = worldPosition / 100.0;
	
	p[0] = w * cloudMul[0] + cloudAdd[0];
	p[1] = w * cloudMul[1] + cloudAdd[1];
	
	cloud.a  = CloudNoise(p[0]) * weights[0];
	cloud.a += CloudNoise(p[1]) * weights[1] - weights[1];
	
	if (GetCoverage(coverage, (cloud.a - weights[1]) * cloudAltitudeWeight) < 1.0)
		return vec4(0.0);
	
	p[2] = w * cloudMul[2] + cloudAdd[2];
	p[3] = w * cloudMul[3] + cloudAdd[3];
	
	cloud.a += CloudNoise(p[2]) * weights[2] - weights[2];
	cloud.a += CloudNoise(p[3]) * weights[3] - weights[3];
	cloud.a += CloudNoise(p[3] * cloudMul[3] / 6.0 + cloudAdd[3]) * weights[4];
	
	cloud.a /= 2.15;
	
	cloud.a = GetCoverage(coverage, cloud.a * cloudAltitudeWeight);
	
	float sunlight  = pow5((worldPosition.y - cloudLowerHeight) / (cloudDepth - 25.0)) + sunglow * 0.005;
	      sunlight *= 1.0 + sunglow * 5.0 + pow(sunglow, 0.25);
	
	cloud.rgb = mix(ambientColor, directColor, sunlight) + bouncedColor;
	
	return cloud;
}

void CloudFBM1(cfloat speed) {
	float t = TIME * 0.07 * speed;
	
	cloudMul[0] = vec3(0.5, 0.5, 0.1);
	cloudAdd[0] = vec3(t * 1.0, 0.0, 0.0);
	
	cloudMul[1] = vec3(1.0, 2.0, 1.0);
	cloudAdd[1] = vec3(t * 0.577, 0.0, 0.0);
	
	cloudMul[2] = vec3(6.0, 6.0, 6.0);
	cloudAdd[2] = vec3(t * 5.272, 0.0, t * 0.905);
	
	cloudMul[3] = vec3(18.0);
	cloudAdd[3] = vec3(t * 19.721, 0.0, t * 6.62);
}

void CloudLighting1(float sunglow) {
	directColor  = sunlightColor;
	directColor *= 8.0 * (1.0 + pow4(sunglow) * 10.0) * (1.0 - rainStrength * 0.8);
	
	ambientColor  = mix(sqrt(skylightColor), sunlightColor, 0.15);
	ambientColor *= 2.0 * mix(vec3(1.0), vec3(0.6, 0.8, 1.0), timeNight);
	
	bouncedColor = mix(skylightColor, sunlightColor, 0.5);
}

void CloudLighting2(float sunglow) {
	directColor  = sunlightColor;
	directColor *= 100.0 * (1.0 + pow2(sunglow) * 2.0) * mix(1.0, 0.2, rainStrength);
	
	ambientColor  = mix(sqrt(skylightColor), sunlightColor, 0.5);
	ambientColor *= 1.7 + timeHorizon * 1.0;
	
	directColor += ambientColor * 20.0 * timeHorizon;
	
	bouncedColor = vec3(0.0);
}

void CloudLighting3(float sunglow) {
	directColor  = sunlightColor;
	directColor *= 140.0 * mix(1.0, 0.5, timeNight);
	
	ambientColor = mix(skylightColor, sunlightColor, 0.15) * 7.0;
	
	bouncedColor = vec3(0.0);
}

void swap(io vec3 a, io vec3 b) {
	vec3 swap = a;
	a = b;
	b = swap;
}

#define CLOUDS_3D ON // [ON OFF]

#define CLOUD3D_START_HEIGHT 400 // [260 300 350 400 450 500 550 600 650 700 750 800 850 900 950 1000]
#define CLOUD3D_DEPTH   150 // [50 100 150 200 250 300 350 400 450 500]
#define CLOUD3D_SAMPLES  10 // [3 4 5 6 7 8 9 10 15 20 25 30 40 50 100]
#define CLOUD3D_COVERAGE  0.5 // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9]
#define CLOUD3D_SPEED     1.0 // [0.25 0.5 1.0 2.5 5.0 10.0]
#define Cloud3DFBM CloudFBM1 // [CloudFBM1]
#define Cloud3DLighting CloudLighting2 // [CloudLighting1 CloudLighting2 CloudLighting3]

#define SKY_BRIGHTNESS 1.0 // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.1 2.2 2.3 2.4 2.5 2.6 2.7 2.8 2.9 3.0 3.1 3.2 3.3 3.4 3.5 3.6 3.7 3.8 3.9 4.0]

vec4 Compute3DClouds(vec3 position, vec3 rayPos, const bool reflection) {
	if (!CLOUDS_3D) return vec4(0.0);
	
	cfloat cloudDepth = CLOUD3D_DEPTH;
	cfloat cloudLowerHeight = CLOUD3D_START_HEIGHT;
	cfloat cloudUpperHeight = cloudLowerHeight + cloudDepth;
	
	float samples = CLOUD3D_SAMPLES;
	
	vec3 a, b, rayPosition, rayIncrement;
	
	rayPos += cameraPosition;
	
	a = position * ((cloudUpperHeight - rayPos.y) / position.y);
	b = position * ((cloudLowerHeight - rayPos.y) / position.y);
	
	if (rayPos.y < cloudLowerHeight) {
		if (position.y <= 0.0) return vec4(0.0);
		
		swap(a, b);
	} else if (cloudLowerHeight <= rayPos.y && rayPos.y <= cloudUpperHeight) {
		if (position.y < 0.0) swap(a, b);
		
		samples *= abs(a.y) / cloudDepth;
		b = vec3(0.0);
		
		swap(a, b);
	} else if (position.y >= 0.0) return vec4(0.0);
	
	rayIncrement = (b - a) / (samples + 1.0);
	rayPosition = a + rayPos + rayIncrement * (1.0 + GetCloudDither(vec2(0.0)));
	
	float coverage  = CLOUD3D_COVERAGE + rainStrength * 0.335;
	      coverage *= clamp01(1.0 - length2((rayPosition.xz - rayPos.xz) / 15000.0));
	if (  coverage <= 0.1) return vec4(0.0);
	
	float sunglow = pow8(clamp01(dotNorm(position, worldLightVector) - 0.01)) * pow4(max(timeDay, timeNight));
	
	Cloud3DFBM(CLOUD3D_SPEED);
	Cloud3DLighting(sunglow);
	
	vec4 cloudSum = vec4(0.0);
	
	for (float i = 0.0; i < samples && cloudSum.a < 1.0; i++, rayPosition += rayIncrement) {
		vec4 cloud = CloudColor(rayPosition, cloudLowerHeight, cloudDepth, coverage, sunglow);
		
		cloudSum.rgb += cloud.rgb * (1.0 - cloudSum.a) * cloud.a;
		cloudSum.a += cloud.a;
	}
	
	cloudSum.a = clamp01(cloudSum.a);
	
	return cloudSum;
}