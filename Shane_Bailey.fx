#define ReShadeFX
//
#include "ReShade.fxh"
#include "ReShadeUI.fxh"
//----------------------------------------GrayScale-----------------------------------------------//
float4 GrayFilter(float4 colorInput : SV_Position, float2 texture_cord : TexCoord) : SV_Target
{
    float4 originalColor = tex2D(ReShade::BackBuffer, texture_cord);
    float gray = (originalColor.r + originalColor.g + originalColor.b) / 3.0;
    float4 grayscaleColor = float4(gray, gray, gray, originalColor.a);

    return grayscaleColor;
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
    float2 blockTexcoord = floor(texture_cord * float2(BUFFER_WIDTH, BUFFER_HEIGHT) / float2(CHARACTER_SIZE, CHARACTER_SIZE)) * texel_size;
    float4 blockColor = AverageColor(blockTexcoord, texel_size);

    return blockColor;
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
    float2 blockTexcoord = floor(texture_cord * float2(BUFFER_WIDTH, BUFFER_HEIGHT) / float2(CHARACTER_SIZE, CHARACTER_SIZE)) * texel_size;
    float4 blockColor = AverageColor(blockTexcoord, texel_size);
    float brightness = (blockColor.r + blockColor.g + blockColor.b) / 3 + 0.1;

    int character_index = clamp(int(brightness * 10), 0, 9);
    float2 ascii_texcord = float2(character_index * 8 + texture_cord.x* BUFFER_WIDTH % 8, texture_cord.y*BUFFER_HEIGHT% 8);
    float4 overlayColor = tex2D(ASCII_CHARACTERS, ascii_texcord / float2(80, 8));

    if (overlayColor.r == 1.0 && overlayColor.g == 1.0 && overlayColor.b == 1.0) {
        return blockColor;
    }
    else {
        return overlayColor;
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