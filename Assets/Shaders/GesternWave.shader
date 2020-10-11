﻿Shader "Unlit/GesternWave"
{
    Properties
    {
        //_Color ("Color", Color) = (1,1,1,1)
		//_MainTex ("Albedo (RGB)", 2D) = "white" {}
		//_Glossiness ("Smoothness", Range(0,1)) = 0.5
		//_Metallic ("Metallic", Range(0,1)) = 0.0

		_Wavelength1 ("Wavelength Wave A", Float) = 10
		_Amplitude1 ("Amplitude Wave A", Float) = 1
		_Speed1 ("Speed Wave A", Float) = 1		
		_Steepnes1 ("Steepnes Wave A", Range(0,1)) = 0.5
		_Direction1 ("Direction Wave A (2D)", Vector) = (1,0,0,0)	

		_Wavelength2 ("Wavelength Wave B", Float) = 10
		_Amplitude2 ("Amplitude Wave B", Float) = 1
		_Speed2 ("Speed Wave B", Float) = 1		
		_Steepnes2 ("Steepnes Wave B", Range(0,1)) = 0.5
		_Direction2 ("Direction Wave B (2D)", Vector) = (1,0,0,0)	

		_NormalMapScrollSpeed ("Normal Map Scroll Speed", Vector) = (1,1,1,1)

		[NoScaleOffset] _NormalMap1("Normal Map 1", 2D) = "white" {}
        [NoScaleOffset] _DuDvMap1("Normal Map 1 Distortion", 2D) = "white" {}
		
        [NoScaleOffset] _NormalMap2("Normal Map 2", 2D) = "white" {}		
		[NoScaleOffset] _DuDvMap2("Normal Map 2 Distortion", 2D) = "white" {}
		
		_DistortionFactor("Distortion Factor", Range(0, 0.5)) =  0.15
        _WaterFog("Water Fog", Range(0, 1)) =  0.5
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent"}
 		 
        Pass
        {              		
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag                        

            #include "UnityCG.cginc"            

            struct v2f 
            {
                float4 pos : SV_POSITION;

                half3 tspace0 : TEXCOORD0; // tangent.x, bitangent.x, normal.x
                half3 tspace1 : TEXCOORD1; // tangent.y, bitangent.y, normal.y
                half3 tspace2 : TEXCOORD2; // tangent.z, bitangent.z, normal.z

                float2 uv : TEXCOORD3;
                float4 uvGrab : TEXCOORD4;

                float3 worldPos : TEXCOORD5;
                float4 screenPos : TEXCOORD6;
            };                        

            struct WaveInfo 
            {
                float wavelength; 	// (W)
                float amplitude; 	// (A)
                float speed; 		// (phi)
                float2 direction;	// (D)
                float steepnes; 	// (Q)
            };

		    struct TangentSpace 
    		{
			    float3 binormal;
			    float3 tangent;
			    float3 normal;
		    };

            /*
            sampler2D _MainTex;
            float4 _MainTex_ST;

            half _Glossiness;
            half _Metallic;
            fixed4 _Color;
            */
            
            float _Wavelength1, _Amplitude1, _Speed1, _Steepnes1;
            float _Wavelength2, _Amplitude2, _Speed2, _Steepnes2;
            
            float _DistortionFactor, _WaterFog;
                
            float4 _Direction1, _Direction2;
            float4 _NormalMapScrollSpeed;            
            
            sampler2D _NormalMap1, _NormalMap2;
            sampler2D _DuDvMap1, _DuDvMap2;                        
            sampler2D _CameraOpaqueTexture, _CameraDepthTexture;
            float4 _CameraDepthTexture_TexelSize;            

            float3 gesternWave(WaveInfo wave, inout TangentSpace tangentSpace, float3 p, float t)
            {
                float w = sqrt( 9.81 * ( (2*UNITY_PI) / wave.wavelength ) );
                //float w = 2 * UNITY_PI / wave.wavelength;
                float PHI_t = wave.speed * w * t;
                float2 D = normalize(wave.direction.xy);
                float Q = wave.steepnes / (w * wave.amplitude * 2);			

                float f1 = w * dot ( D, p.xz ) + PHI_t;		
                float S = sin(f1);
                float C = cos(f1);

                float WA = w * wave.amplitude;
                float WAS = WA * S;
                float WAC = WA * C;						

                tangentSpace.binormal += float3
                (
                    Q * (D.x * D.x) * WAS,
                    D.x * WAC,
                    Q * (D.x * D.y) * WAS
                );

                tangentSpace.tangent += float3
                (
                    Q * (D.x * D.y) * WAS,
                    D.y * WAC,
                    Q * (D.y * D.y) * WAS
                );

                tangentSpace.normal += float3
                (
                    D.x * WAC,
                    Q * WAS,
                    D.y * WAC
                );			

                float f3 = cos(f1);
                float f4 =  Q * wave.amplitude * f3;

                return float3
                (
                    f4 * D.x,					// X
                    wave.amplitude * sin(f1),	// Y
                    f4 * D.y					// Z
                );
            }

            TangentSpace calculateTangentSpace(TangentSpace tangentSpace)
            {
                tangentSpace.binormal = float3(
                    1 - tangentSpace.binormal.x,
                    tangentSpace.binormal.y,
                    -tangentSpace.binormal.z
                );
                tangentSpace.tangent = float3(
                    -tangentSpace.tangent.x,
                    tangentSpace.tangent.y,
                    1 - tangentSpace.tangent.z
                );
                tangentSpace.normal = float3(
                    -tangentSpace.normal.x,
                    1 - tangentSpace.normal.y,
                    -tangentSpace.normal.z
                );
                
                return tangentSpace;
            }	

            v2f vert (float4 vertex : POSITION, float3 normal : NORMAL, float4 tangent : TANGENT, float2 uv : TEXCOORD0)
            {               
                v2f o;

                float3 p = vertex.xyz;
			    float t = _Time.y;

                WaveInfo wave1 = {_Wavelength1, _Amplitude1, _Speed1, _Direction1.xy, _Steepnes1};
                WaveInfo wave2 = {_Wavelength2, _Amplitude2, _Speed2, _Direction2.xy, _Steepnes2};

			    TangentSpace tangentSpace = { float3(0,0,0), float3(0,0,0), float3(0,0,0) };

			    p += gesternWave(wave1, tangentSpace, p, t);
			    p += gesternWave(wave2, tangentSpace, p, t);
						
			    vertex.xyz = p;

                tangentSpace = calculateTangentSpace(tangentSpace);	

                o.screenPos = ComputeScreenPos(UnityObjectToClipPos(vertex));
                o.pos = UnityObjectToClipPos(vertex); 
                o.worldPos = mul(unity_ObjectToWorld, vertex).xyz;
              
                o.tspace0 = half3(tangentSpace.tangent.x, tangentSpace.binormal.x, tangentSpace.normal.x);
                o.tspace1 = half3(tangentSpace.tangent.y, tangentSpace.binormal.y, tangentSpace.normal.y);
                o.tspace2 = half3(tangentSpace.tangent.z, tangentSpace.binormal.z, tangentSpace.normal.z);

                o.uvGrab = ComputeGrabScreenPos(UnityObjectToClipPos(vertex));
                o.uv = uv;

                return o;
            }

            float2 AlignWithGrabTexel (float2 uv)
            {
	            #if UNITY_UV_STARTS_AT_TOP
		        if (_CameraDepthTexture_TexelSize.y < 0) 
                {
    			    uv.y = 1 - uv.y;
		        }
	            #endif

                return (floor(uv * _CameraDepthTexture_TexelSize.zw) + 0.5) * abs(_CameraDepthTexture_TexelSize.xy);
            } 
            
            fixed4 frag (v2f i) : SV_Target
            {
                float2 normalMapCoords1 = i.uv + (_Time.x * _NormalMapScrollSpeed.x) * _Direction1.xy;
    			float2 normalMapCoords2 = i.uv + (_Time.x * _NormalMapScrollSpeed.y) * _Direction2.xy;                

                float3 normalMap1 = UnpackNormal(tex2D(_NormalMap1, normalMapCoords1));			
			    float3 normalMap2 = UnpackNormal(tex2D(_NormalMap2, normalMapCoords2));
                float3 normalMapSum = normalMap1 + normalMap1;
			   
                half3 worldNormal;
                worldNormal.x = dot(i.tspace0, normalMapSum);
                worldNormal.y = dot(i.tspace1, normalMapSum);
                worldNormal.z = dot(i.tspace2, normalMapSum);                
             
                half3 worldViewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
                half3 worldRefl = reflect(-worldViewDir,  worldNormal );
                half4 skyData = UNITY_SAMPLE_TEXCUBE(unity_SpecCube0, worldRefl);
                half3 skyColor = DecodeHDR (skyData, unity_SpecCube0_HDR);                                

                float3 duDvMap1 = UnpackNormal(tex2D(_DuDvMap1, normalMapCoords1));
                float3 duDvMap2 = UnpackNormal(tex2D(_DuDvMap2, normalMapCoords2));
                float3 duDVMapSum = duDvMap1 + duDvMap2; 

                half3 worldDuDvMap;
                worldDuDvMap.x = dot(i.tspace0, duDVMapSum);
                worldDuDvMap.y = dot(i.tspace1, duDVMapSum);
                worldDuDvMap.z = dot(i.tspace2, duDVMapSum);
                half3 distortion =  worldDuDvMap * _DistortionFactor;

                distortion.y *= _CameraDepthTexture_TexelSize.z * abs(_CameraDepthTexture_TexelSize.y);
	            float2 uv = AlignWithGrabTexel((i.screenPos.xy + distortion) / i.screenPos.w);

                float backgroundDepth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv));
	            float surfaceDepth = UNITY_Z_0_FAR_FROM_CLIPSPACE(i.screenPos.z);
	            float depthDifference = backgroundDepth - surfaceDepth;

                distortion *= saturate(depthDifference);
                uv = AlignWithGrabTexel((i.screenPos.xy + distortion) / i.screenPos.w);
	            backgroundDepth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv));
	            depthDifference = backgroundDepth - surfaceDepth;

                float3 underwaterColor = tex2D(_CameraOpaqueTexture, uv).rgb;                
                
                half4 depthFactor = saturate(_WaterFog * depthDifference);          
                float3 surfaceColor = lerp(underwaterColor, skyColor, depthFactor);

                fixed4 c = 0;
                c.rgb = surfaceColor;
                return c;                 
            }
            ENDCG
        }
    }
}
