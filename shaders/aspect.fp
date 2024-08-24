void main()
{	
	vec2 screendims	= textureSize( InputTexture, 0 );
	vec2 pos			= TexCoord ;
	
	pos		-= 0.5 ;
	pos.y   *= pixelstretch;
	pos		+= 0.5 ;
	
	vec3 A = texelFetch( InputTexture, ivec2( pos * screendims ), 0 ).rgb ;
	
	FragColor = vec4( A, 1.0 );
}
