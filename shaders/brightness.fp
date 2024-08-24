void main()
{
	vec3 colour = texture(InputTexture, TexCoord).rgb;
	colour *= strength;	
	colour *= infraredfactor;
	colour = max(vec3(0.0), colour );
	FragColor = vec4(colour, 1.0);
}