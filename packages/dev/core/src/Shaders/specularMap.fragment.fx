uniform sampler2D reflectivityTexture;
uniform sampler2D ORMTexture;
uniform sampler2D albedoTexture;
uniform sampler2D specularGlossinessTexture;
uniform sampler2D occlusionTexture;

uniform vec3 reflectivityColor;
uniform vec3 albedoColor;

uniform float roughness;
uniform float metallic;
uniform float glossiness;

varying vec2 vUV;

uniform mat4 specTextureMatrix;
uniform mat4 albedoTextureMatrix;

void main(void) { // we compute Specularity in .rgb  and shininess in .a

    #ifdef ORMTEXTURE
        // Used as if :
        // pbr.useRoughnessFromMetallicTextureAlpha = false;
        // pbr.useRoughnessFromMetallicTextureGreen = true;
        // pbr.useMetallnessFromMetallicTextureBlue = true;

        vec2 specUV = vec2(specTextureMatrix * vec4(vUV, 1.0, 0.0));

        float metal = texture2D(ORMTexture, specUV).b;

        #ifdef METALLIC
            metal *= metallic;
        #endif


        gl_FragColor.a = texture2D(ORMTexture, specUV).g;

        #ifdef ROUGHNESS
            gl_FragColor.a *= roughness;
        #endif

        gl_FragColor.r = 1.0; 
        gl_FragColor.g = 1.0;  
        gl_FragColor.b = 1.0; 
        
        #ifdef ALBEDOTEXTURE // Specularity should be: mix(0.04, 0.04, 0.04, albedoTexture, metallic):
            vec2 albedoUV = vec2(albedoTextureMatrix * vec4(vUV, 1.0, 0.0));
            gl_FragColor.rgb = mix(vec3(0.04), texture2D(albedoTexture, albedoUV).rgb, metal);
        #else
            #ifdef ALBEDOCOLOR // Specularity should be: mix(0.04, 0.04, 0.04, albedoColor, metallic)::
                gl_FragColor.rgb = mix(vec3(0.04), albedoColor.xyz, metal);
            #else // albedo color suposed to be white   
                gl_FragColor.rgb = mix(vec3(0.04), vec3(1.0), metal);   
            #endif            
        #endif
    #else
        #ifdef METALLIC // already added 
            // should be a PBRMaterial
            float metal = metallic;

            #ifdef ROUGHNESS
                gl_FragColor.a = roughness;
            #else 
                gl_FragColor.a = 1.0;
            #endif    

            #ifdef ALBEDOTEXTURE // Specularity should be: mix(0.04, 0.04, 0.04, albedoTexture, metallic):
                vec2 albedoUV = vec2(albedoTextureMatrix * vec4(vUV, 1.0, 0.0));
                gl_FragColor.rgb = mix(vec3(0.04), texture2D(albedoTexture, albedoUV).rgb, metal);
            #else
                #ifdef ALBEDOCOLOR // Specularity should be: mix(0.04, 0.04, 0.04, albedoColor, metallic):
                    gl_FragColor.rgb = mix(vec3(0.04), albedoColor.xyz, metal);    
                #else // albedo color suposed to be white   
                    gl_FragColor.rgb = mix(vec3(0.04), vec3(1.0), metal);   
                #endif          
            #endif
        #else
            #ifdef ROUGHNESS
                gl_FragColor.a = roughness;
                gl_FragColor.r = 1.0; // metallic supposed to be 1.0
                gl_FragColor.g = 1.0;
                gl_FragColor.b = 1.0;

                #ifdef ALBEDOTEXTURE // Specularity should be: mix(0.04, 0.04, 0.04, albedoTexture, 1.0):
                    vec2 albedoUV = vec2(albedoTextureMatrix * vec4(vUV, 1.0, 0.0));
                    gl_FragColor.rgb = texture2D(albedoTexture, albedoUV).rgb; 
                #else
                    #ifdef ALBEDOCOLOR // Specularity should be:mix(0.04, 0.04, 0.04, albedoColor, 1.0):
                        gl_FragColor.rgb = albedoColor.xyz;   
                    // else : albedo color suposed to be white   
                    #endif          
                #endif
            #else // SpecularGlossiness Model 
                #ifdef SPECULARGLOSSINESSTEXTURE
                    vec2 specUV = vec2(specTextureMatrix * vec4(vUV, 1.0, 0.0));
                    gl_FragColor.rgb = texture2D(specularGlossinessTexture, specUV).rbg; 
                    gl_FragColor.a = 1.0 - texture2D(specularGlossinessTexture, specUV).a; // roughness = 1.0 - glossiness
                    #ifdef GLOSSINESSS
                        gl_FragColor.a = 1.0 - (texture2D(specularGlossinessTexture, specUV).a * glossiness); 
                    #endif
                #else 
                    #ifdef REFLECTIVITYTEXTURE 
                        vec2 specUV = vec2(specTextureMatrix * vec4(vUV, 1.0, 0.0));
                        gl_FragColor.rbg = texture2D(reflectivityTexture, specUV).rbg;
                    #else    
                        #ifdef REFLECTIVITYCOLOR
                            gl_FragColor.rgb = reflectivityColor.xyz;
                            gl_FragColor.a = 0.0;
                            // by default we put the shininess to the mean of specular values
                            // if it is not a StandardMaterial, the shininess will be next defined according to the roughness/glossiness
                        #else 
                            // We never reach this case since even if the reflectivity color is not defined
                            // by the user, there is a default reflectivity/specular color set to (1.0, 1.0, 1.0)
                            gl_FragColor.rgba = vec4(1.0, 1.0, 1.0, 0.0);            
                        #endif          
                    #endif 
                    #ifdef GLOSSINESSS
                        gl_FragColor.a = 1.0 - glossiness; // roughness = 1.0 - glossiness
                    #else
                        gl_FragColor.a = 0.0; // glossiness default value in SpecularGlossiness mode = 1.0
                    #endif
                #endif
            #endif    
        #endif   
    #endif   
    gl_FragColor.a = 1.0 - gl_FragColor.a; // to return shininess insted of roughness
}
