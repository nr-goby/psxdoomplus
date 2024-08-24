#define ENABLE_LIGHT_PSX

const float BRIGHTNESS_LEVEL = 1.0;

#ifndef WARP_SPEED
	#define WARP_SPEED 1.0
#endif

void SetMaterialPropsPsx(inout Material material, vec2 texCoord);

vec2 WarpTexCoord(vec2 texCoord);
vec4 getLightColor(vec4 color);
float R_DoomLightingEquationPSX(float light);

mat3 GetTBN(vec2 texcoord);
vec3 GetBumpedNormal(mat3 tbn, vec2 texcoord);
vec2 ParallaxMap(mat3 tbn, vec2 texCoord);

vec4 getTexel64(vec2 st);

float hash12(vec2 p);
float perlinNoise(vec2 x);
float perlinFbm (vec2 uv, float freq);
vec2 rhash(vec2 uv);
float voronoi2d(const in vec2 point);
vec4 getFire(in vec2 texcoord);

#define TEX_OFFSET(tex, texCoord, off) texture(tex, texCoord - (off)/texSize)
vec4 Filter3Point(sampler2D tex, vec2 texCoord, float enabled)
{
	if (enabled > 0.0)
	{
		precision mediump float;
		precision mediump int;
		mediump vec2 texSize = vec2(textureSize(tex,0));
		mediump vec2 offset = fract(texCoord*texSize - vec2(0.5));
		offset -= step(1.0, offset.x + offset.y);
		lowp vec4 c0 = TEX_OFFSET(tex, texCoord, offset);
		lowp vec4 c1 = TEX_OFFSET(tex, texCoord, vec2(offset.x - sign(offset.x), offset.y));
		lowp vec4 c2 = TEX_OFFSET(tex, texCoord, vec2(offset.x, offset.y - sign(offset.y)));
		lowp vec4 tex3Point = c0 + abs(offset.x)*(c1-c0) + abs(offset.y)*(c2-c0);
		return tex3Point;
	}
	else
	{
		return texture(tex, texCoord);
	}
}

void SetupMaterial(inout Material material)
{
	vec2 texCoord = vTexCoord.st;
	#if defined(WARP)
		texCoord = WarpTexCoord(texCoord);
	#endif
	SetMaterialPropsPsx(material, texCoord);
	#if defined(PBR)
		if ((uTextureMode & TEXF_Brightmap) != 0) {
			material.Metallic = texture(metallictexture, texCoord).r - (texture(brighttexture, texCoord).r * 0.5);
		} else {
			material.Metallic = texture(metallictexture, texCoord).r;
		}
		material.Roughness = texture(roughnesstexture, texCoord).r;
		material.AO = texture(aotexture, texCoord).r;
	#endif
	#if defined(SPECULAR)
		material.Specular = texture(speculartexture, texCoord).rgb;
		material.Glossiness = uSpecularMaterial.x;
		material.SpecularLevel = uSpecularMaterial.y;
	#endif
	
	#if defined(FLAME)
		material.Base = getFire(texCoord);
	#endif
}

vec3 rgb2hsv(in vec3 c)
{
   vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
   vec4 p = c.g < c.b ? vec4(c.bg, K.wz) : vec4(c.gb, K.xy);
   vec4 q = c.r < p.x ? vec4(p.xyw, c.r) : vec4(c.r, p.yzx);

   float d = q.x - min(q.w, q.y);
   float e = 1.0e-10;
   return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(in vec3 c)
{
   vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
   vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
   return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

vec3 R_SetLightFactor(in vec3 color)
{
	//brightness level is always 100%
	float f = 1.0 + BRIGHTNESS_LEVEL;
	vec3 hsv = rgb2hsv(color);
	hsv.z = min(hsv.z * f, 1.0);
	color = hsv2rgb(hsv);
	
	//another hack to compensate for Retribution's lower light levels
	f = 2.0 - rgb2hsv(vColor.rgb).z;
	color *= f;
	
	return color;
}

vec4 ProcessLight(Material mat, vec4 color)
{
	#ifndef SKIP_GRADIENT_LIGHT
	if ((uTextureMode & 0xffff) == 0)
	{
		vec4 c = uObjectColor;
		c.rgb = R_SetLightFactor(c.rgb);
		vec4 c2 = uObjectColor2;
		if (c2.a == 0.0)
		{
			color *= c;
		}
		else
		{
			vec4 c2 = uObjectColor2;
			c2.rgb = R_SetLightFactor(c2.rgb);
			color *= mix(c, c2, gradientdist.z);
		}
		color = desaturate(color);
		
		#if defined(SPRITE_PSX) || defined(WEAPON_PSX) || defined(SWITCH_PSX)
		color.rgb = min(color.rgb + mat.Bright.rgb, 1.0);
		#endif
	}
	#endif
	
	#if defined(ENABLE_LIGHT_PSX)
		#if defined (SKIP_LIGHT_BOOST)
			color.rgb *= 0.67;
		#endif
	#endif
	
	return color;
}

vec4 getLightColor(vec4 color)
{
	//float lightLevel = 2.0 - rgb2hsv(vColor.rgb).z;
	float lightLevel = 1.0;
	float newlightlevel = R_DoomLightingEquationPSX(lightLevel);
	color.rgb *= clamp(vec3(newlightlevel), 0.0, 1.0);
	//color.rgb *= clamp(vec3(newlightlevel), 0.0, 1.25);
	return color;
}

float R_DoomLightingEquationPSX(float light)
{
	float Lightscale;
	
	float Dist = (gl_FragCoord.z / gl_FragCoord.w);
	#if defined(WEAPON_PSX)
		float Factor = (16.0/255.0);
	#elif defined(WALL_PSX)
		float Factor = (400.0 - Dist)/(1000.0);
	#elif defined(FLAT_PSX)
		float Factor = (200.0 - (Dist))/(1040.0);
	#elif (defined(SPRITE_PSX))
		float Factor = (36.0/255.0);
	#else
		float Factor = (400.0 - Dist)/(1000.0);
	#endif
	
	Factor = clamp(Factor, 0.0, (50.0/255.0)) * 255.0;

	float L = (light * 255.0);
	L = clamp(L - 8.0, 0.0, 255.0)/2.0;
	
	float Shade = clamp((L * (32.0 + Factor) + 32.0 / 2.0) / 32.0, L, 255.0);
	//float Shade = max((L * (32.0 + Factor) + 32.0 / 2.0) / 32.0, L);
	
	//Lightscale = clamp((float(int(abs(Shade / 4.0))) * 4.0)/ 255.0, 0.0, 1.0);
	Lightscale = clamp(Shade / 255.0, 0.0, 1.0);
	//Lightscale = clamp(Shade / 255.0, 0.0, 1.25);
	
	return Lightscale;
}

vec2 WarpTexCoord(vec2 texCoord)
{
	const float pi = 3.14159265358979323846;
	vec2 offset = vec2(0.0,0.0);

	offset.y = 0.5 + sin(pi * 2.0 * (texCoord.y + timer * WARP_SPEED * 0.61 + 900.0/8192.0)) + sin(pi * 2.0 * (texCoord.x * 2.0 + timer * WARP_SPEED * 0.36 + 300.0/8192.0));
	offset.x = 0.5 + sin(pi * 2.0 * (texCoord.y + timer * WARP_SPEED * 0.49 + 700.0/8192.0)) + sin(pi * 2.0 * (texCoord.x * 2.0 + timer * WARP_SPEED * 0.49 + 1200.0/8192.0));

	return texCoord + offset * 0.025;
}

void SetMaterialPropsPsx(inout Material material, vec2 texCoord)
{
#ifdef NPOT_EMULATION
	if (uNpotEmulation.y != 0.0)
	{
		float period = floor(texCoord.t / uNpotEmulation.y);
		texCoord.s += uNpotEmulation.x * floor(mod(texCoord.t, uNpotEmulation.y));
		texCoord.t = period + mod(texCoord.t, uNpotEmulation.y);
	}
#endif	

	#if defined(RELIEF_PARALLAX) || defined(NORMAL_PARALLAX)
		mat3 tbn = GetTBN(texCoord);
		vec2 st = ParallaxMap(tbn, texCoord);
	#else
		vec2 st = texCoord.st;
	#endif

	#ifndef SKIP_GRADIENT_LIGHT
		material.Base = getTexel64(st); 
	#else
		material.Base = getTexel(st);
	#endif
	
	#if defined(RELIEF_PARALLAX) || defined(NORMAL_PARALLAX)
		material.Normal = GetBumpedNormal(tbn, texCoord);
	#else
		material.Normal = ApplyNormalMap(st);
	#endif

// OpenGL doesn't care, but Vulkan pukes all over the place if these texture samplings are included in no-texture shaders, even though never called.
#ifndef NO_LAYERS
	if ((uTextureMode & TEXF_Brightmap) != 0)
	{
		material.Bright = desaturate(texture(brighttexture, texCoord.st));
	}
		
	if ((uTextureMode & TEXF_Detailmap) != 0)
	{
		vec4 Detail = texture(detailtexture, texCoord.st * uDetailParms.xy) * uDetailParms.z;
		material.Base.rgb *= Detail.rgb;
	}
	
	if ((uTextureMode & TEXF_Glowmap) != 0)
		material.Glow = desaturate(texture(glowtexture, texCoord.st));
#endif
}

// Tangent/bitangent/normal space to world space transform matrix
mat3 GetTBN(vec2 tc)
{
    vec3 n = normalize(vWorldNormal.xyz);
    vec3 p = pixelpos.xyz;
    vec2 uv = tc;

    // get edge vectors of the pixel triangle
    vec3 dp1 = dFdx(p);
    vec3 dp2 = dFdy(p);
    vec2 duv1 = dFdx(uv);
    vec2 duv2 = dFdy(uv);

    // solve the linear system
    vec3 dp2perp = cross(n, dp2); // cross(dp2, n);
    vec3 dp1perp = cross(dp1, n); // cross(n, dp1);
    vec3 t = dp2perp * duv1.x + dp1perp * duv2.x;
    vec3 b = dp2perp * duv1.y + dp1perp * duv2.y;

    // construct a scale-invariant frame
    float invmax = inversesqrt(max(dot(t,t), dot(b,b)));
    return mat3(t * invmax, b * invmax, n);
}

vec3 GetBumpedNormal(mat3 tbn, vec2 texcoord)
{
#if defined(NORMALMAP)
    vec3 map = texture(normaltexture, texcoord).xyz;
    map = map * 255./127. - 128./127.; // Math so "odd" because 0.5 cannot be precisely described in an unsigned format
    map.xy *= vec2(0.5, -0.5); // Make normal map less strong and flip Y
    return normalize(tbn * map);
#else
    return normalize(vWorldNormal.xyz);
#endif
}

#if defined(NORMAL_PARALLAX) || defined(RELIEF_PARALLAX)
float GetDisplacementAt(vec2 currentTexCoords)
{
    return 0.5 - texture(displacement, currentTexCoords).r;
}
#endif

#if defined(NORMAL_PARALLAX)
vec2 ParallaxMap(mat3 tbn, vec2 texCoord)
{
    const float parallaxScale = 0.5;

    // Calculate fragment view direction in tangent space
    mat3 invTBN = transpose(tbn);
    vec3 V = normalize(clamp(0.0, 1.0)(invTBN * (uCameraPos.xyz - pixelpos.xyz));

    vec2 texCoords = texCoord.st;
    vec2 p = V.xy / abs(V.z) * GetDisplacementAt(texCoords) * parallaxScale;
    return texCoords - p;
}

#elif defined(RELIEF_PARALLAX)
vec2 ParallaxMap(mat3 tbn, vec2 texCoord)
{
    const float parallaxScale = 0.4;
    const float minLayers = 14.0;
    const float maxLayers = 16.0;

    // Calculate fragment view direction in tangent space
    mat3 invTBN = transpose(tbn);
    vec3 V = normalize(invTBN * (uCameraPos.xyz - pixelpos.xyz));
    vec2 T = texCoord.st;

    float numLayers = mix(maxLayers, minLayers, clamp(abs(V.z), 0.0, 1.0)); // clamp is required due to precision loss

    // calculate the size of each layer
    float layerDepth = 1.0 / numLayers;

    // depth of current layer
    float currentLayerDepth = 0.0;

    // the amount to shift the texture coordinates per layer (from vector P)
    vec2 P = V.xy * parallaxScale;
    vec2 deltaTexCoords = P / numLayers;
    vec2 currentTexCoords = T + (P * 0.07);
    float currentDepthMapValue = GetDisplacementAt(currentTexCoords);

    while (currentLayerDepth < currentDepthMapValue)
    {
        // shift texture coordinates along direction of P
        currentTexCoords -= deltaTexCoords;

        // get depthmap value at current texture coordinates
        currentDepthMapValue = GetDisplacementAt(currentTexCoords);

        // get depth of next layer
        currentLayerDepth += layerDepth;
    }


	deltaTexCoords *= 0.5;
	layerDepth *= 0.5;

	currentTexCoords += deltaTexCoords;
	currentLayerDepth -= layerDepth;


	const int _reliefSteps = 14;
	int currentStep = _reliefSteps;
	while (currentStep > 0) {
	float currentGetDisplacementAt = GetDisplacementAt(currentTexCoords);
		deltaTexCoords *= 0.5;
		layerDepth *= 0.5;


		if (currentGetDisplacementAt > currentLayerDepth) {
			currentTexCoords -= deltaTexCoords;
			currentLayerDepth += layerDepth;
		}

		else {
			currentTexCoords += deltaTexCoords;
			currentLayerDepth -= layerDepth;
		}
		currentStep--;
	}

	return currentTexCoords - (P * 0.01);
}

#endif

vec4 getTexel64(vec2 st)
{
	#ifndef FIRESKY
		#if defined (FilterEnabled)
			float tpfEnabled = texture(FilterEnabled, st).r;
		#else
			float tpfEnabled = 0.0;
		#endif
	#else
		float a = (texture(tex, st).a) * 255.0;
		float tpfEnabled = 0.0;
		if (a == 254.0 || a == 252.0)
		{
			tpfEnabled = 1.0;
		}
	#endif
	
	#ifndef WEAPON_PSX
		vec4 texel = Filter3Point(tex, st, tpfEnabled);
	#else
		vec4 texel = texture(tex, st);
	#endif
	
	#if defined (LightBoostEnabled)
		if (texture(LightBoostEnabled, st).r > 0.0)
		{
			texel.rgb *= 0.67;
		}
	#endif
	
	#ifdef FIRESKY
		if (a == 253.0 || a == 252.0)
		{
			texel.rgb *= 0.67;
		}
	#endif
	
	bool applyGradient = false;
	
	//
	// Apply texture modes
	//
	switch (uTextureMode & 0xffff)
	{
		case 1:	// TM_STENCIL
			texel.rgb = vec3(1.0,1.0,1.0);
			applyGradient = true;
			break;
			
		case 2:	// TM_OPAQUE
			texel.a = 1.0;
			applyGradient = true;
			break;
			
		case 3:	// TM_INVERSE
			texel = vec4(1.0-texel.r, 1.0-texel.b, 1.0-texel.g, texel.a);
			applyGradient = true;
			break;
			
		case 4:	// TM_ALPHATEXTURE
		{
			float gray = grayscale(texel);
			texel = vec4(1.0, 1.0, 1.0, gray*texel.a);
			applyGradient = true;
			break;
		}
		
		case 5:	// TM_CLAMPY
			if (st.t < 0.0 || st.t > 1.0)
			{
				texel.a = 0.0;
			}
			applyGradient = true;
			break;
						
		case 6: // TM_OPAQUEINVERSE
			texel = vec4(1.0-texel.r, 1.0-texel.b, 1.0-texel.g, 1.0);
			applyGradient = true;
			break;
			
		case 7: //TM_FOGLAYER 
			return texel;

	}
	
	if ((uTextureMode & TEXF_ClampY) != 0)
	{
		if (st.t < 0.0 || st.t > 1.0)
		{
			texel.a = 0.0;
		}
	}
	
	// Apply the texture modification colors.
	int blendflags = int(uTextureAddColor.a);	// this alpha is unused otherwise
	if (blendflags != 0)	
	{
		// only apply the texture manipulation if it contains something.
		texel = ApplyTextureManipulation(texel, blendflags);
	}
	
	#ifndef SKIP_ADDITIVE_LIGHT
		texel.rgb += uAddColor.rgb;
	#endif
	if (applyGradient)
	{
		// Apply the Doom64 style material colors on top of everything from the texture modification settings.
		// This may be a bit redundant in terms of features but the data comes from different sources so this is unavoidable.
		//if (uObjectColor2.a == 0.0) texel *= uObjectColor;
		//else texel *= mix(uObjectColor, uObjectColor2, gradientdist.z);
		
		vec4 c = uObjectColor;
		c.rgb = R_SetLightFactor(c.rgb);
		vec4 c2 = uObjectColor2;
		if (c2.a == 0.0)
		{
			texel *= c;
		}
		else
		{
			vec4 c2 = uObjectColor2;
			c2.rgb = R_SetLightFactor(c2.rgb);
			texel *= mix(c, c2, gradientdist.z);
		}
	}
	
	#if defined(ENABLE_LIGHT_PSX) && !defined(SKIP_LIGHT_PSX)
		texel = getLightColor(texel);
	#endif
	
	// Last but not least apply the desaturation from the sector's light.
	return desaturate(texel);
}

// Hash function by Dave_Hoskins
float hash12(vec2 p)
{
	uvec2 q = uvec2(ivec2(p)) * uvec2(1597334673U, 3812015801U);
	uint n = (q.x ^ q.y) * 1597334673U;
	return float(n) * (1.0 / float(0xffffffffU));
}

float perlinNoise(vec2 x) {
    vec2 i = floor(x);
    vec2 f = fract(x);

	float a = hash12(i);
    float b = hash12(i + vec2(1.0, 0.0));
    float c = hash12(i + vec2(0.0, 1.0));
    float d = hash12(i + vec2(1.0, 1.0));

    vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float perlinFbm (vec2 uv, float freq)
{
    uv *= freq;
    float amp = 0.5f;
    float noise = 0.0f;
    for (int i = 0; i < 8; ++i)
    {
        noise += amp * perlinNoise(uv);
        uv *= 2.0f;
        amp *= 0.5f;
    }
    return noise;
}

vec2 rhash(vec2 uv) {
    const mat2 myt = mat2(.12121212, .13131313, -.13131313, .12121212);
    const vec2 mys = vec2(1e4, 1e6);
    uv *= myt;
    uv *= mys;
    return fract(fract(uv / mys) * uv);
}

float voronoi2d(const in vec2 point) {
  vec2 p = floor(point);
  vec2 f = fract(point);
  float res = 0.0;
  for (int j = -1; j <= 1; j++) {
    for (int i = -1; i <= 1; i++) {
      vec2 b = vec2(i, j);
      vec2 r = vec2(b) - f + rhash(p + b);
      res += 1. / pow(dot(r, r), 8.);
    }
  }
  return pow(1. / res, 0.0625);
}

vec4 getFire(in vec2 texcoord)
{
    //don't touch ;)
    const vec3 lumCoeff = vec3(0.2126f,0.7152f,0.0722f);
    
    //can touch :(
    const vec2 perlinNoiseDirection = vec2(0.0f, 0.5f);
    const float perlinNoiseScale = 7.5f;
    
    const vec2 voronoNoiseDirection = vec2(0.1f, 0.5f);
    const float voronoNoiseScale = 2.0f;
    const float voronoNoiseDistortionAmount = 0.4;//1.51f;
    
    const float mixTexAndNoiseAmount = 0.2f;
    //
    vec2 pNoiseDirection = perlinNoiseDirection * timer;
    vec2 vNoiseDirection = voronoNoiseDirection * timer;
    float p_noise = perlinFbm(texcoord + pNoiseDirection, perlinNoiseScale);
    float v_noise = voronoi2d(texcoord * voronoNoiseScale + vNoiseDirection);
    v_noise = pow(v_noise, voronoNoiseDistortionAmount);
    
    //from [0,1] to [-1,1]
    p_noise = (p_noise - 0.5f) * 2.0f;
    
    float finalNoise = p_noise * v_noise;
    
    vec2 mixTexAndNoise = mix(texcoord, vec2(finalNoise), mixTexAndNoiseAmount);
    vec4 baseTexture = getTexel(vec2(mixTexAndNoise));
    baseTexture.rgb *= v_noise;

    float fireLuminance = dot(baseTexture.rgb, lumCoeff);
    
	#ifndef HIGH_COLOR
		vec3 highColor = vec3(0xFF, 0xFF, 0xFF);
	#else
		vec3 highColor = vec3(HIGH_COLOR);
	#endif

	#ifndef LOW_COLOR
		vec3 lowColor = vec3(0x0, 0x0, 0x0);
	#else
		vec3 lowColor = vec3(LOW_COLOR);
	#endif

	#ifndef BASE_COLOR
		vec3 baseColor = vec3(0x90, 0x90, 0x90);
	#else
		vec3 baseColor = vec3(BASE_COLOR);
	#endif
	highColor.r /= 255.0;
	highColor.g /= 255.0;
	highColor.b /= 255.0;
	lowColor.r /= 255.0;
	lowColor.g /= 255.0;
	lowColor.b /= 255.0;
	baseColor.r /= 255.0;
	baseColor.g /= 255.0;
	baseColor.b /= 255.0;
	
    //vec4 colorRamp = texture(tex_colorRamp, vec2(fireLuminance, 0.0f));
	vec4 colorRamp = vec4(baseColor, 1.0);
	colorRamp *= vec4(mix(lowColor, highColor, fireLuminance),1.0);
    colorRamp *= 1.55;
    vec4 fire = baseTexture * colorRamp;
    return fire;
}