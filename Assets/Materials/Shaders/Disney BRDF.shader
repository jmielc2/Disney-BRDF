Shader "Custom/Disney BRDF"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _Roughness("Roughness", Float) = 0.5
        _Specular("Specular", Float) = 0.3
        _Anisotropic("Anisotropic", Float) = 0.1
    }
    SubShader
    {
        Tags {
            "RenderType"="Opaque"
            "LightMode" = "ForwardBase"
            "Queue" = "Geometry"
        }
        LOD 200

        Pass {
            CGPROGRAM
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _METALLICSPECGLOSSMAP
            #pragma shader_feature_local _OCCLUSIONMAP
            
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 normal : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
            };

            float4 _Color;
            float _Roughness;
            float _Specular;
            float _Anisotropic;

            float Pow5(float a) {
                const float a2 = a * a;
                return a2 * a2 * a;
            }

            // 
            float3 DisneyDiffuseLobe(const float cos_ln, const float cos_vn, const float cos_vh) {
                const float fd90 = 0.5f + 2.0f * cos_vh * cos_vh * saturate(_Roughness);
                const float diffuse_l = lerp(1.0f, fd90 - 1.0f, Pow5(1.0f - cos_ln));
                const float diffuse_v = lerp(1.0f, fd90 - 1.0f, Pow5(1.0f - cos_vn));
                // TODO: Replace constant color with texture look up
                return UNITY_INV_PI * diffuse_l * diffuse_v * _Color.xyz;
            }

            // Isotropic GTR distribution function with lambda 2 as described in Burley's paper on Disney's BRDF
            // Given an input microfacet angle (cos between halfway vector and normal), gives the proportion of
            // microfacets that align with that angle.
            float GTR_2(const float cos_hn) {
                const float roughness = saturate(_Roughness);
                float alpha = 0.5 + roughness * 0.5;
                alpha *= alpha;
                const float alpha2 = alpha * alpha;
                const float denom = 1.0f + (alpha2 - 1.0f) * cos_hn * cos_hn;
                return UNITY_INV_PI * alpha2 / (denom * denom);
            }

            // Anisotropic GTR distribution function with lambda 2 as described in Burley's paper on Disney's BRDF
            // Given an input microfacet angle (cos between halfway vector and normal) and surface rotation (cos
            // of rotation around normal axis), gives the proportion of microfacets that align with that angle.
            float GTR_aniso2(const float cos_hn, const float cos_ph) {
                const float anisotropic = saturate(_Anisotropic);
                const float roughness = saturate(_Roughness);
                const float aspect = sqrt(1.0f - 0.9f * anisotropic);
                const float a_x = roughness * roughness / aspect;
                const float a_y = roughness * roughness * aspect;
                const float sin_h = sqrt(1.0f - cos_hn * cos_hn);
                const float sin_ph = sqrt(1.0f - cos_ph * cos_ph);
                
                const float denom = cos_hn * cos_hn + sin_h * sin_h * (cos_ph * cos_ph / (a_x * a_x) + sin_ph * sin_ph / (a_y * a_y));
                return UNITY_INV_PI / (a_x * a_y * denom * denom);
            }

            float GGX_G1(const float cos_vn, const float cos_vh) {
                const float roughness = saturate(_Roughness);
                float alpha = 0.5 + roughness * 0.5;
                alpha *= alpha;
                if (cos_vh / cos_vn > 0) {
                    const float sin_v = 1.0 - cos_vn * cos_vn;
                    const float tan_v = sin_v / cos_vn;
                    const float a = 2.0 / (1.0 + sqrt(1 + alpha * alpha * tan_v * tan_v));
                    return float3(a, a, a);
                }
                return float3(0, 0, 0);
            }

            float3 DisneyMicrofacetDistribution(const float cos_hn, const float cos_ph) {
                const float baseLobe = GTR_2(cos_hn);
                // const float baseLobe = GTR_2(cos_hn, cos_ph);
                return float3(baseLobe, baseLobe, baseLobe);
            }

            float3 DisneyFresnel(const float cos_vh) {
                const float specular = saturate(_Specular);
                float incident_reflection = lerp(0.0f, 0.08f, specular);
                float reflectance = incident_reflection + (1.0f - incident_reflection) * Pow5(1.0f - cos_vh);
                return float3(reflectance, reflectance, reflectance);
            }

            float3 DisneyMicrofacetMasking(const float cos_vn, const float cos_ln, const float cos_vh) {
                const float g1_v = GGX_G1(cos_vn, cos_vh);
                const float g1_l = GGX_G1(cos_ln, cos_vh);
                return g1_v * g1_l;
            }

            float3 DisneyMicrofacetLobe(const float cos_ln, const float cos_vn, const float cos_vh, const float cos_hn, const float cos_ph) {
                return DisneyMicrofacetDistribution(cos_hn, cos_ph) * DisneyFresnel(cos_vh) * DisneyMicrofacetMasking(cos_vn, cos_ln, cos_vh);
            }
            
            float3 DisneyBRDF(const float3 lightDir, const float3 viewDir, const float3 normal, const v2f i) {
                const float3 halfDir = normalize(lightDir + viewDir);
                
                const float cos_ln = dot(lightDir, normal);
                const float cos_vn = dot(viewDir, normal);
                const float cos_hn = dot(halfDir, normal);
                const float cos_vh = dot(viewDir, halfDir);

                const float3 dpdx = ddx(i.worldPos);  // derivative of position in screen-space x
                const float3 dpdy = ddy(i.worldPos);  // derivative of position in screen-space y
                const float2 dudx = ddx(i.uv);  // derivative of UV in screen-space x  
                const float2 dudy = ddy(i.uv);  // derivative of UV in screen-space y

                // Solve for dp/du and dp/dv
                const float det = dudx.x * dudy.y - dudy.x * dudx.y;
                const float3 dpdu = (dudy.y * dpdx - dudx.y * dpdy) / det;
                const float3 dpdv = (dudx.x * dpdy - dudy.x * dpdx) / det;

                const float3 tangent = normalize(dpdu);
                // const float3 bitangent = normalize(dpdv);
                const float cos_ph = dot(tangent, halfDir);

                const float recip_denom = 0.25f / (cos_ln * cos_vn);
                // return DisneyDiffuseLobe(cos_ln, cos_vn, cos_vh);
                // return DisneyMicrofacetLobe(cos_ln, cos_vn, cos_vh, cos_hn, cos_ph);
                // return DisneyFresnel(cos_vh);
                // return DisneyMicrofacetMasking(cos_vn, cos_ln, cos_vh);
                return DisneyDiffuseLobe(cos_ln, cos_vn, cos_vh) + DisneyMicrofacetLobe(cos_ln, cos_vn, cos_vh, cos_hn, cos_ph) * recip_denom;
            }

            v2f vert(appdata i) {
                v2f o;
                o.vertex = UnityObjectToClipPos(i.vertex);
                // o.uv = TRANSFORM_TEX(i.uv);
                o.uv = i.uv;
                o.normal = UnityObjectToWorldNormal(i.normal);
                o.worldPos = mul(unity_ObjectToWorld, i.vertex).xyz;
                return o;
            }

            float4 frag(v2f i) : SV_Target {
                const float3 normal = normalize(i.normal);
                const float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);
                const float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos);

                // TODO: Replace const light color with real world value
                const float4 lightColor = float4(1.0f, 1.0f, 1.0f, 1.0f);
                const float3 brdf = DisneyBRDF(lightDir, viewDir, normal, i);
                return float4(brdf * saturate(dot(lightDir, normal)) * lightColor.xyz, 1.0f);
            }

            ENDCG
        }
    }
    FallBack "Diffuse"
}
