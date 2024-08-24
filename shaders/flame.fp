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
	
	float tpfEnabled = 1.0 - texture(tex, texCoord).a;
	
	#ifdef FLIP
	texCoord.y *= -1;
	#endif
	
	#ifdef CLASSIC
	
	texCoord.y *= 0.7;
	
	#ifdef SKY
	texCoord.xy *= vec2(0.9,-0.9);
	#else
	texCoord.y += 0.25;
	#endif
	
	vec4 fragColor = Filter3Point(tex, texCoord, tpfEnabled);
	
	#else
	
	#ifndef STRETCH
	texCoord.x *= 2.0;
	#endif
	
	vec2 uv = texCoord;
	
	texCoord.x += fract(timer * 0.05);
	texCoord.y += fract(timer * 0.2);
	
	float grad = mix(0.0, 2.0, uv.y - 0.35);
	
	vec4 d = texture(distortiontexture, uv);
	vec4 d1 = d * 0.2;
	vec4 n = texture(noisetexture, texCoord.xy + d1.rg);
	n += grad;
	
	vec4 fragColor = vec4(n.r, n.r, n.r, 1.0);
	
	#endif
	
	#ifndef HIGH_COLOR
		vec3 highColor = vec3(0xF0, 0xF0, 0xF0);
	#else
		vec3 highColor = vec3(HIGH_COLOR);
	#endif

	#ifndef LOW_COLOR
		vec3 lowColor = vec3(0x00, 0x00, 0x00);
	#else
		vec3 lowColor = vec3(LOW_COLOR);
	#endif

	//vec2 ratio = pixelpos.xy / pixelpos.w;
	highColor.r /= 255.0;
	highColor.g /= 255.0;
	highColor.b /= 255.0;
	lowColor.r /= 255.0;
	lowColor.g /= 255.0;
	lowColor.b /= 255.0;
	
	#ifdef CLASSIC
	
	fragColor.rgb *= mix(highColor, lowColor, fragColor.y);
	
	vec3 gray = vec3( dot( fragColor.rgb , vec3( 0.2126 , 0.7152 , 0.0722 ) ) );
	fragColor = vec4( mix( fragColor.rgb , gray, 0.15) , 1.0 );
	
	#else
	
	fragColor *= mix(vec4(highColor,1.0), vec4(lowColor,1.0), uv.y / 0.55);
	
	#endif
	
	material.Base = fragColor;
}
