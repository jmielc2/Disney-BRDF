Shader "Custom/Disney BRDF"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _Roughness("Roughness", Float) = 0.5
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

            float SchlickFresnelWeight(float a) {
                a = saturate(1.0f - a);
                const float a2 = a * a;
                return a2 * a2 * a;
            }

            float4 DisneyDiffuseModel(const float4 albedo, const float roughness, const float3 lightDir, const float3 viewDir, const float3 halfDir, const float3 normal) {
                const float dotNL = dot(normal, lightDir);
                const float dotNV = dot(normal, viewDir);
                const float dotHV = saturate(dot(halfDir, viewDir));

                const float fl = SchlickFresnelWeight(dotNL);
                const float fv = SchlickFresnelWeight(dotNV);
                const float retro = 0.5f + 2.0f * roughness * dotHV * dotHV;
                return albedo * UNITY_INV_PI * (1 + (retro - 1) * fl) * (1 + (retro - 1) * fv);
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
                const float3 halfDir = normalize(lightDir + viewDir);

                const float4 diffuse = DisneyDiffuseModel(_Color, _Roughness, lightDir, viewDir, halfDir, normal);
                return diffuse * saturate(dot(normal, lightDir));
            }

            ENDCG
        }
    }
    FallBack "Diffuse"
}
