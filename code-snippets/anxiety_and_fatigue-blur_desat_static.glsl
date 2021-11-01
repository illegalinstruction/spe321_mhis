//--------------------- FRAGMENT SHADER --------------------------------
//----------------------------------------------------------------------
precision lowp float;  // some mobile devices might be happier with this

// textures
uniform 	sampler2D 	backdrop;		// artwork of the current room
uniform 	sampler2D 	blur_vignette;	// b&w image used to tell us how much to blur edges

// arguments passed from javascript via glUniform1f()
attribute	float		spoon_lvl;		// how much energy does the player have?
attribute	float		max_spoons;		
attribute	float		stress_lvl;		// how stressed/anxious is the player right now?
attribute	float		max_stress; 
attribute	float		anim_clock;		// used to control the static effect

// 'magic' argument passed from vertex shader
varying 	vec2 		tex_coord;

//----------------------------------------------------------------------
// unoptimized to keep me from confusing myself whilst I write it - will
// fix/tune at the end if there's time. 


void main()
{
	float	neighbour_offset = 0.05;
	
	float 	blurriness;
	
	vec4 	source_texel; 
	vec4	neighbour_north, 
			neighbour_south, 
			neighbour_east, 
			neighbour_west;
	vec4	control_texel; 
	
	//------------ BLUR EDGES OF BACKDROP ------------------------------		
	// this blurring works by applying a convolution kernel whose matrix
	// looks like so:         [0  y  0]
	//                  (1/5)*[y  x  y] 
	//                        [0  y  0]
	// ...where 'x' is (1 - blurriness) and 'y' is blurriness, and both
	// values are clamped between 0 & 1.
	// we make it look even more unsettling by moving where the 
	// neighbouring texels are sampled from by the 'blurriness' factor.
	//
	// blurriness is obtained by 'blur_vignette * (stress_lvl / max_stress)'.		 
	
	blurriness 			= clamp(texture2d(blur_vignette, tex_coord).g * (stress_lvl / max_stress),0,1);
	neighbour_offset	= neighbour_offset * blurriness;
	
	// fetch original texel
	source_texel 	= texture2d(backdrop, tex_coord);
	
	// fetch neighbours
	neighbour_north	= texture2d(backdrop, vec2(tex_coord.x, tex_coord.y - neighbour_offset));
	neighbour_south	= texture2d(backdrop, vec2(tex_coord.x, tex_coord.y + neighbour_offset));
	neighbour_west	= texture2d(backdrop, vec2(tex_coord.x - neighbour_offset, tex_coord.y));
	neighbour_east	= texture2d(backdrop, vec2(tex_coord.x + neighbour_offset, tex_coord.y));
	
	vec4 blurred_pixel = (source_texel +
							neighbour_north +
							neighbour_south +
							neighbour_east +
							neighbour_west) / 5.0;
							
	// ----- DESATURATE BLURRED BACKDROP -------------------------------
	// this one's just arithmetic mean between the red, grn and blue
	// channels, multiplied by (spoon_lvl/max_spoons), then
	// added to the original colour multiplied by 1 - (spoon_lvl/max_spoons)
	float 	b_and_w 	= (blurred_pixel.r + blurred_pixel.g + blurred_pixel.b) / 3.0;
	vec4	desat_pixel;
	
	float stress = clamp(stress_lvl / max_stress, 0.0, 1.0);
	
	desat_pixel.r = ((b_and_w * stress) + (blurred_pixel.r * (1 - stress))) / 2.0;  
	desat_pixel.g = ((b_and_w * stress) + (blurred_pixel.g * (1 - stress))) / 2.0;  
	desat_pixel.b = ((b_and_w * stress) + (blurred_pixel.b * (1 - stress))) / 2.0;  
	desat_pixel.a = 1.0;
	
	// --------- STATIC ------------------------------------------------
	// just uses GLSL's built-in noise() method.
	vec4 	staticky_pixel;
	float 	noise_val = noise(anim_clock) * (stress / 2.0);
	
	staticky_pixel.r	=	clamp(desat_pixel.r + noise_val, 0.0, 1.0);
	staticky_pixel.r	=	clamp(desat_pixel.g + noise_val, 0.0, 1.0);
	staticky_pixel.r	=	clamp(desat_pixel.b + noise_val, 0.0, 1.0);
	staticky_pixel.a	=	1.0;
	
    // 'magic' variable that controls the colour that gets drawn to the
    // actual canvas								
	gl_FragColor		=	staticky_pixel;
}

//----------------------------------------------------------------------
//------------------ END FRAGMENT SHADER -------------------------------
