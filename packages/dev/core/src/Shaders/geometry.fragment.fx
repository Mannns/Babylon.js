#extension GL_EXT_draw_buffers : require

#if defined(BUMP) || !defined(NORMAL)
#extension GL_OES_standard_derivatives : enable
#endif

precision highp float;

#ifdef BUMP
varying mat4 vWorldView;
varying vec3 vNormalW;
#else
varying vec3 vNormalV;
#endif

varying vec4 vViewPos;

#if defined(POSITION) || defined(BUMP)
varying vec3 vPositionW;
#endif

#ifdef VELOCITY
varying vec4 vCurrentPosition;
varying vec4 vPreviousPosition;
#endif

#ifdef NEED_UV
varying vec2 vUV;
#endif

#ifdef BUMP
uniform vec3 vBumpInfos;
uniform vec2 vTangentSpaceParams;
#endif

#if defined(REFLECTIVITY)
varying vec2 vReflectivityUV;
varying vec2 vAlbedoUV;
uniform sampler2D reflectivitySampler;
uniform sampler2D albedoSampler;
uniform vec3 reflectivityColor;
uniform vec3 albedoColor;
uniform float metallic;
uniform float glossiness;
#endif

#ifdef ALPHATEST
uniform sampler2D diffuseSampler;
#endif

#include<mrtFragmentDeclaration>[RENDER_TARGET_COUNT]
#include<bumpFragmentMainFunctions>
#include<bumpFragmentFunctions>
#include<helperFunctions>

void main() {
    #ifdef ALPHATEST
	if (texture2D(diffuseSampler, vUV).a < 0.4)
		discard;
    #endif

    vec3 normalOutput;
    #ifdef BUMP
    vec3 normalW = normalize(vNormalW);
    #include<bumpFragment>
    normalOutput = normalize(vec3(vWorldView * vec4(normalW, 0.0)));
    #else
    normalOutput = normalize(vNormalV);
    #endif

    #ifdef PREPASS
        #ifdef PREPASS_DEPTH
        gl_FragData[DEPTH_INDEX] = vec4(vViewPos.z / vViewPos.w, 0.0, 0.0, 1.0);
        #endif

        #ifdef PREPASS_NORMAL
        gl_FragData[NORMAL_INDEX] = vec4(normalOutput, 1.0);
        #endif
    #else
    gl_FragData[0] = vec4(vViewPos.z / vViewPos.w, 0.0, 0.0, 1.0);
    gl_FragData[1] = vec4(normalOutput, 1.0);
    #endif

    #ifdef POSITION
    gl_FragData[POSITION_INDEX] = vec4(vPositionW, 1.0);
    #endif

    #ifdef VELOCITY
    vec2 a = (vCurrentPosition.xy / vCurrentPosition.w) * 0.5 + 0.5;
	vec2 b = (vPreviousPosition.xy / vPreviousPosition.w) * 0.5 + 0.5;

    vec2 velocity = abs(a - b);
    velocity = vec2(pow(velocity.x, 1.0 / 3.0), pow(velocity.y, 1.0 / 3.0)) * sign(a - b) * 0.5 + 0.5;

    gl_FragData[VELOCITY_INDEX] = vec4(velocity, 0.0, 1.0);
    #endif

    #ifdef REFLECTIVITY
        vec4 reflectivity;

        #ifdef METALLICWORKFLOW
            // Reflectivity calculus for metallic-roughness model based on:
            // https://marmoset.co/posts/pbr-texture-conversion/
            // https://substance3d.adobe.com/tutorials/courses/the-pbr-guide-part-2

            float metal = 1.0;
            float roughness = 1.0;

            #ifdef ORMTEXTURE
                // Used as if :
                // pbr.useRoughnessFromMetallicTextureAlpha = false;
                // pbr.useRoughnessFromMetallicTextureGreen = true;
                // pbr.useMetallnessFromMetallicTextureBlue = true;
                metal *= texture2D(reflectivitySampler, vReflectivityUV).b;
                roughness *= texture2D(reflectivitySampler, vReflectivityUV).g;
            #endif

            #ifdef METALLIC
                metal *= metallic;
            #endif

            #ifdef ROUGHNESS
                roughness *= (1.0 - glossiness); // roughness = 1.0 - glossiness
            #endif

            reflectivity = vec4(1.0, 1.0, 1.0, 1.0 - roughness);
                
            #ifdef ALBEDOTEXTURE // Specularity should be: mix(0.04, 0.04, 0.04, albedoTexture, metallic):
                reflectivity.rgb = mix(vec3(0.04), texture2D(albedoSampler, vAlbedoUV).rgb, metal);
            #else
                #ifdef ALBEDOCOLOR // Specularity should be: mix(0.04, 0.04, 0.04, albedoColor, metallic):
                    reflectivity.rgb = mix(vec3(0.04), albedoColor.xyz, metal);
                #else // albedo color suposed to be white   
                    reflectivity.rgb = mix(vec3(0.04), vec3(1.0), metal);   
                #endif            
            #endif
            reflectivity.rgb = toGammaSpace(reflectivity.rgb); // translate to gammaSpace to be sync with prePass reflectivity
        #else
            // SpecularGlossiness Model 
            #ifdef SPECULARGLOSSINESSTEXTURE
                reflectivity = texture2D(reflectivitySampler, vReflectivityUV); 
                #ifdef GLOSSINESSS
                    reflectivity.a *= glossiness; 
                #endif
            #else 
                #ifdef REFLECTIVITYTEXTURE 
                    reflectivity.rbg = texture2D(reflectivitySampler, vReflectivityUV).rbg;
                #else    
                    #ifdef REFLECTIVITYCOLOR
                        reflectivity.rgb = reflectivityColor.xyz;
                        reflectivity.a = 1.0;
                    // #else 
                        // We never reach this case since even if the reflectivity color is not defined
                        // by the user, there is a default reflectivity/specular color set to (1.0, 1.0, 1.0)
                    #endif          
                #endif 
                #ifdef GLOSSINESSS
                    reflectivity.a = glossiness; 
                #else
                    reflectivity.a = 1.0; // glossiness default value in Standard / SpecularGlossiness mode = 1.0
                #endif
            #endif
        #endif   
    
        gl_FragData[REFLECTIVITY_INDEX] = reflectivity; 

    #endif
}
