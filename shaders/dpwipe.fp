
void main()
{
	vec2 Pos	= TexCoord ;
	ivec2 Dim	= textureSize( InputTexture, 0 );
	ivec2 Txl	= ivec2( Pos * vec2(Dim) );
	vec3 Col	= texture( InputTexture, Pos ).rgb ;
	
	int i ;
	float j ;
	for( i = 1; i < min( timer, Dim.y - Txl.y ); i++ )
	{
		Txl.y	+= min( i, 6 );
		j		= 1.0 / float(i)  ;
		Col		= mix( Col, texelFetch( InputTexture, Txl, 0 ).rgb, j );
	}
	//Col.r	= max( max( Col.r, Col.g ), Col.b );
	
	if (j > 0.0)
	{
		Col.gb	*= sqrt( j );
	}
	
	Col.r = clamp(Col.r, 0.0, 1.0);
	Col.g = clamp(Col.g, 0.0, 1.0);
	Col.b = clamp(Col.b, 0.0, 1.0);
	
	FragColor = vec4( Col, 1.0 );
}
