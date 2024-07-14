#define ReShadeFX
//
#include "ReShade.fxh"
#include "ReShadeUI.fxh"
//----------------------------------------GrayScale-----------------------------------------------//
float4 GrayFilter(float4 colorInput : SV_Position, float2 texture_cord : TexCoord) : SV_Target
{
    float4 original_color = tex2D(ReShade::BackBuffer, texture_cord);
    float gray = (original_color.r + original_color.g + original_color.b) / 3.0;
    float4 grayscale_color = float4(gray, gray, gray, original_color.a);

    return grayscale_color;
}

technique GrayscaleTechnique
{
pass
{
    VertexShader = PostProcessVS;
    PixelShader = GrayFilter;
}
}

//----------------------------------------Mexico-----------------------------------------------//

uniform float3 mexico_tint_default < __UNIFORM_COLOR_FLOAT3
> = float3(1, 0.8, 0.6);

float4 MexicoFilter(float4 colorInput : SV_Position, float2 texture_cord : TexCoord) : SV_Target
{
    float4 original_color = tex2D(ReShade::BackBuffer, texture_cord);
    float4 tinted_color = original_color * float4(mexico_tint_default, 1.0);

    return tinted_color;
}

technique MexicoTechnique
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = MexicoFilter;
    }
}

//---------------------------------------Pixelated-----------------------------------------------//

uniform int CHARACTER_SIZE = 8;


float4 AverageColor(float2 texture_cord, float2 texel_size)
{
    float4 color_sum = float4(0, 0, 0, 0);

    for (int y = 0; y < CHARACTER_SIZE; ++y)
    {
        for (int x = 0; x < CHARACTER_SIZE; ++x)
        {
            float2 offset = float2(x, y) * texel_size;
            color_sum += tex2D(ReShade::BackBuffer, texture_cord + offset);
        }
    }

    return color_sum / (CHARACTER_SIZE * CHARACTER_SIZE);
}

float4 PixelationFilter(float4 colorInput : SV_Position, float2 texture_cord : TexCoord) : SV_Target
{
    float2 texel_size = float2(CHARACTER_SIZE, CHARACTER_SIZE) / float2(BUFFER_WIDTH, BUFFER_HEIGHT);
    float2 block_texcoord = floor(texture_cord * float2(BUFFER_WIDTH, BUFFER_HEIGHT) / float2(CHARACTER_SIZE, CHARACTER_SIZE)) * texel_size;
    float4 block_color = AverageColor(block_texcoord, texel_size);

    return block_color;
}

technique PixelationTechnique
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = PixelationFilter;
    }
}


//----------------------------------------ascii--------------------------------------------------//
uniform int ASCII_CHARACTER_SIZE = 8;
texture2D ASCII_CHARACTERS_TEXTURE < source = "ASCII_GRADIENT.png"; > { Width = 80; Height = 8; };
sampler2D ASCII_CHARACTERS{ Texture = ASCII_CHARACTERS_TEXTURE; AddressU = CLAMP; AddressV = CLAMP; };

float4 ASCII_Filter(float4 colorInput : SV_Position, float2 texture_cord : TexCoord) : SV_Target
{

    float2 texel_size = float2(CHARACTER_SIZE, CHARACTER_SIZE) / float2(BUFFER_WIDTH, BUFFER_HEIGHT);
    float2 block_texcoord = floor(texture_cord * float2(BUFFER_WIDTH, BUFFER_HEIGHT) / float2(CHARACTER_SIZE, CHARACTER_SIZE)) * texel_size;
    float4 block_color = AverageColor(block_texcoord, texel_size);
    float brightness = (block_color.r + block_color.g + block_color.b) / 3 + 0.1;

    int character_index = clamp(int(brightness * 10), 0, 9);
    float2 ascii_texcord = float2(character_index * 8 + texture_cord.x * BUFFER_WIDTH % 8, texture_cord.y * BUFFER_HEIGHT % 8);
    float4 overlay_color = tex2D(ASCII_CHARACTERS, ascii_texcord / float2(80, 8));

    if (overlay_color.r == 1.0 && overlay_color.g == 1.0 && overlay_color.b == 1.0) {
        return block_color;
    }
    else {
        return overlay_color;
    }
}

technique ASCII_Technique
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = ASCII_Filter;
    }
}


//---------------------------------Guassion_Blur--------------------------------------------------//
//https://www.rastergrid.com/blog/2010/09/efficient-gaussian-blur-with-linear-sampling/
//key terms, pascal triangle, 
uniform int STD_DEV = 3;
float PI = 3.1416;
//2 dimensional gaussion equation
float Gaussian(float x, float y, float std_dev)
{
    return exp(-(x * x + y * y) / (2.0 * std_dev * std_dev)) / (2 * PI * std_dev * std_dev);
}


float4 GaussianBlur(float2 texture_cord : TexCoord, float2 texel_size, int std_dev)
{
    float4 color_sum = float4(0.0, 0.0, 0.0, 0.0);
    float total_weight = 0.0;

    //for loops is to grab the areas around the pixel
    for (int x = -std_dev; x <= std_dev; x++)
    {
        for (int y = -std_dev; y <= std_dev; y++)
        {
            //normalize the offset to the texel_size
            float2 offset = float2(x, y) * texel_size;
            //use gaussian equation to find the weight
            float weight = Gaussian(offset.x, offset.y, std_dev);
            //color is the same as the color of the spot * its weight
            color_sum += tex2D(ReShade::BackBuffer, texture_cord + offset) * weight;
            total_weight += weight;
        }
    }
    //normalize the color so that it remains its brightness
    return color_sum / total_weight;
}

float4 GuassionBlur(float4 colorInput : SV_Position, float2 texture_cord : TexCoord) : SV_Target
{
    float2 texel_size = 1.0 / float2(BUFFER_WIDTH, BUFFER_HEIGHT); // pixel sized groups
    return GaussianBlur(texture_cord, texel_size, STD_DEV);
}

technique GaussianBlurTechnique
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = GuassionBlur;
    }
}