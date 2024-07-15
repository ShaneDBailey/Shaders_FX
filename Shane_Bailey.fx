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

uniform int PIXEL_GROUP_SIZE = 8;


float4 AverageColor(float2 texture_cord, float2 texel_size)
{
    float4 color_sum = float4(0, 0, 0, 0);

    for (int y = 0; y < PIXEL_GROUP_SIZE; ++y)
    {
        for (int x = 0; x < PIXEL_GROUP_SIZE; ++x)
        {
            float2 offset = float2(x, y) * texel_size;
            color_sum += tex2D(ReShade::BackBuffer, texture_cord + offset);
        }
    }

    return color_sum / (PIXEL_GROUP_SIZE * PIXEL_GROUP_SIZE);
}

float4 PixelationFilter(float4 colorInput : SV_Position, float2 texture_cord : TexCoord) : SV_Target
{
    float2 texel_size = float2(PIXEL_GROUP_SIZE, PIXEL_GROUP_SIZE) / float2(BUFFER_WIDTH, BUFFER_HEIGHT);
    float2 block_texcoord = floor(texture_cord * float2(BUFFER_WIDTH, BUFFER_HEIGHT) / float2(PIXEL_GROUP_SIZE, PIXEL_GROUP_SIZE)) * texel_size;
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

    float2 texel_size = float2(ASCII_CHARACTER_SIZE, ASCII_CHARACTER_SIZE) / float2(BUFFER_WIDTH, BUFFER_HEIGHT);
    float2 block_texcoord = floor(texture_cord * float2(BUFFER_WIDTH, BUFFER_HEIGHT) / float2(ASCII_CHARACTER_SIZE, ASCII_CHARACTER_SIZE)) * texel_size;
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
uniform int STD_DEV <  
ui_min = 1; 
ui_max = 16; 
> 
= 16;

uniform float PI = 3.1416;
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


//----------------------Sobel_Filter--------------------------------------------------//

//sobel kernel in the x direction
uniform float x_gradient[9] = {
    1, 0, -1,
    2, 0, -2,
    1, 0, -1
};

uniform float y_gradient[9] = {
    1, 2, 1,
    0, 0, 0,
    -1,-2,-1
};

float getElement(float arr[9], int row, int col, int size)
{
    return arr[row * size + col];
}


float4 SobelFilter(float4 colorInput : SV_Position, float2 texture_cord : TexCoord) : SV_Target
{
    float2 texel_size = 1.0 / float2(BUFFER_WIDTH, BUFFER_HEIGHT);
    float3 gradient_x = 0;
    float3 gradient_y = 0;

    // Apply Sobel filter in x direction
    for (int i = -1; i <= 1; i++)
    {
        for (int j = -1; j <= 1; j++)
        {
            float2 offset = float2(i, j) * texel_size;
            float weight = getElement(x_gradient, i + 1, j + 1, 3); // 3 is the size of each row
            gradient_x += tex2D(ReShade::BackBuffer, texture_cord + offset).rgb * weight;
        }
    }

    // Apply Sobel filter in y direction
    for (int i = -1; i <= 1; i++)
    {
        for (int j = -1; j <= 1; j++)
        {
            float2 offset = float2(i, j) * texel_size;
            float weight = getElement(y_gradient, i + 1, j + 1, 3); // 3 is the size of each row
            gradient_y += tex2D(ReShade::BackBuffer, texture_cord + offset).rgb * weight;
        }
    }

    // Combine gradients to get magnitude
    float3 gradient_magnitude = sqrt(gradient_x * gradient_x + gradient_y * gradient_y);

    // Optionally, output grayscale or edge map
    return float4(gradient_magnitude, 1.0);
}


technique SobelFilterTechnique
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = SobelFilter;
    }
}

//-------------------------------------------Invert_Colors--------------------------------//
float4 InvertColors(float4 colorInput : SV_Position, float2 texture_cord : TexCoord) : SV_Target
{
    float4 original_color = tex2D(ReShade::BackBuffer, texture_cord);
    float4 inverted_color = 1.0 - original_color; 

    return inverted_color;
}

    technique InvertTechnique
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = InvertColors;
    }
}
//------------------------------------------Contrast_Enhancement----------------------------//
float4 ContrastAdjustment(float4 colorInput : SV_Position, float2 texture_cord : TexCoord) : SV_Target
{
    float4 original_color = tex2D(ReShade::BackBuffer, texture_cord);
    float contrast = 2.0; 
    float4 adjusted_color = (original_color - 0.5) * contrast + 0.5;

    return adjusted_color;
}

    technique ContrastTechnique
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = ContrastAdjustment;
    }
}


//-------------------------------------------Double_Vision-----------------------------------//

uniform float double_vision_offset = 10.0;
float4 DoubleVision(float4 colorInput : SV_Position, float2 texture_cord : TexCoord) : SV_Target
{
    float2 texel_size = 1.0 / float2(BUFFER_WIDTH, BUFFER_HEIGHT);
    float4 color1 = tex2D(ReShade::BackBuffer, texture_cord - double_vision_offset * texel_size); // Adjust offset as needed
    float4 color2 = tex2D(ReShade::BackBuffer, texture_cord + double_vision_offset * texel_size); // Adjust offset as needed

    // Interpolate between the two samples to create the double vision effect
    float4 double_vision_color = lerp(color1, color2, 0.5); // Adjust blend ratio if needed

    return double_vision_color;
}

    technique DoubleVisionTechnique
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = DoubleVision;
    }
}
//double vision
//solarize above
//solarize below
//cell shade