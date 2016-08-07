Shader "Panoramic/PanoramicShader"
{
	Properties
	{
		_FrontTex ("Front", 2D) = "white" {}
		_LeftTex ("Left", 2D) = "white" {}
		_RightTex ("Right", 2D) = "white" {}
		_BackTex ("Back", 2D) = "white" {}
		_TopTex ("Top", 2D) = "white" {}
		_BottomTex ("Bottom", 2D) = "white" {}
	}
	SubShader
	{
		// No culling or depth
		Cull Off ZWrite Off ZTest Always

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
			};

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = mul(UNITY_MATRIX_MVP, v.vertex);
				o.uv = v.uv;
				return o;
			}
			
			sampler2D _FrontTex;
			sampler2D _LeftTex;
			sampler2D _RightTex;
			sampler2D _BackTex;
			sampler2D _TopTex;
			sampler2D _BottomTex;

			float3 merc_lens(float2 uv, float fov)
			{
				const float pi = 3.14159265359;
				float aspect = _ScreenParams.x / _ScreenParams.y;
				uv = (uv - .5)*2;
				uv.y *= 1/aspect;
				if((uv.x < -1. || uv.x > 1.) ||
				   (uv.y < -.5 || uv.y > .5))
				{
					discard;
				}
				float theta = -(uv.y * (pi*(fov/360))) - (pi/2);
				float phi = (uv.x * ((pi)*(fov/360))) - (pi/2);

				return float3(	sin(theta)*cos(phi),
								sin(theta)*sin(phi),
								cos(theta));
			}

			float4 fish_lens(float2 uv, float fov)
			{
				const float pi = 3.14159265359;
				float aspect = _ScreenParams.x / _ScreenParams.y;
				uv = (uv - .5)*2;
				if(aspect > 1)
				{
					uv.x *= aspect;
				}
				else
				{
					uv.y *= 1/aspect;
				}
				float r = sqrt((uv.x*uv.x) + (uv.y*uv.y));
				float a = atan2(uv.y, uv.x);
				//if(r * (pi*(fov/360)) > pi)
				//if(r > 1)
				//{
				//	discard;
				//}

				float theta = -r * (pi*(fov/360));
				float phi = a;

				float t = clamp(-theta, (fov/360)*pi, pi);
				t -= (fov/360)*pi;
				t *= 1/(pi-((fov/360)*pi));
				//float l = 1-t;
				float l = 1-pow(r,16.);

				return float4(	sin(theta)*cos(phi),
								cos(theta),
								sin(theta)*sin(phi),
								l);
			}

			float4 fish2_lens(float2 uv, float fov)
			{
				const float pi = 3.14159265359;
				float aspect = _ScreenParams.x / _ScreenParams.y;
				uv = (uv - .5)*2;
				if(aspect > 1)
				{
					uv.x *= aspect;
				}
				else
				{
					uv.y *= 1/aspect;
				}
				float r = sqrt((uv.x*uv.x) + (uv.y*uv.y));
				r /= sqrt((aspect*aspect+1));
				float a = atan2(uv.y, uv.x);

				float theta = -r * (pi*(fov/360));
				float phi = a;

				float l = 1;
				if(r > sqrt((aspect*aspect)+1))
				{
					l = 0;
				}

				return float4(	sin(theta)*cos(phi),
								cos(theta),
								sin(theta)*sin(phi),
								l);
			}

			float3 latlon_to_ray(float2 latlon)
			{
				float clat = cos(latlon.x);
				return float3(	-sin(latlon.y)*clat,
								cos(latlon.y)*clat,
								-sin(latlon.x));
			}

			// code based on: https://github.com/shaunlebron/blinky/blob/master/game/lua-scripts/lenses/panini.lua
			float4 panini_lens(float2 uv)
			{
				float aspect = _ScreenParams.x / _ScreenParams.y;
				uv = (uv - .5)*2;
				if(aspect > 1)
				{
					uv.x *= aspect;
				}
				else
				{
					uv.y *= 1/aspect;
				}
				//
				float d = 1;
				float k = uv.x*uv.x/((d+1)*(d+1));
				float dscr = k*k*d*d - (k+1)*(k*d*d-1);
				float clon = (-k*d+sqrt(dscr))/(k+1);
				float s = (d+1)/(d+clon);
				float lon = atan2(uv.x,s*clon);
				float lat = atan2(uv.y,s);
				return float4(	latlon_to_ray(float2(lat, lon)),
								1);
			}

			// code based on: https://github.com/shaunlebron/blinky/blob/master/game/lua-scripts/lenses/stereographic.lua
			float4 stereographic_lens(float2 uv)
			{
				float aspect = _ScreenParams.x / _ScreenParams.y;
				uv = (uv - .5)*2;
				if(aspect > 1)
				{
					uv.x *= aspect;
				}
				else
				{
					uv.y *= 1/aspect;
				}
				//
				float angleScale = 0.5;
				float r = sqrt((uv.x*uv.x) + (uv.y*uv.y));
				float theta = atan(r) / angleScale;
				float s = sin(theta);
				return(float4(	-uv.x/r*s,
								cos(theta),
								-uv.y/r*s,
								1));
			}

			fixed4 frag (v2f i) : SV_Target
			{
				float4 cart = panini_lens(i.uv);

				int texid;
				float u;
				float v;
				if(length(cart.x) >= length(cart.y) && length(cart.x) >= length(cart.z)) // X Major
				{
					if(cart.x < 0)
					{
						texid = 3;
						u = (((-cart.y/length(cart.x)) + 1)/2);
						v = ((-cart.z/length(cart.x)) + 1)/2;
					}
					else
					{
						texid = 1;
						u = 1-(((-cart.y/length(cart.x)) + 1)/2);
						v = ((-cart.z/length(cart.x)) + 1)/2;
					}
					
				}
				else if(length(cart.y) >= length(cart.x) && length(cart.y) >= length(cart.z)) // Y Major
				{
					if(cart.y < 0)
					{
						texid = 4;
						u = 1-((-cart.x/length(cart.y)) + 1)/2;
						v = ((-cart.z/length(cart.y)) + 1)/2;
					}
					else
					{
						texid = 2;
						u = ((-cart.x/length(cart.y)) + 1)/2;
						v = ((-cart.z/length(cart.y)) + 1)/2;
					}
				}
				else // Z Major
				{
					if(cart.z < 0)
					{
						texid = 6;
						u = ((-cart.x/length(cart.z)) + 1)/2;
						v = ((-cart.y/length(cart.z)) + 1)/2;
					}
					else
					{
						texid = 5;
						u = ((-cart.x/length(cart.z)) + 1)/2;
						v = 1-((-cart.y/length(cart.z)) + 1)/2;
					}
				}

				float2 uv = float2(u,1-v);
				fixed4 col = fixed4(0,0,0,1);
				if(texid > 0)
				{
					if(texid == 1)
					{
						col = tex2D(_LeftTex, uv);
						//col = fixed4(1,0,0,1);
					}
					else if(texid == 2)
					{
						col = tex2D(_FrontTex, uv);
						//col = fixed4(0,1,0,1);
					}
					else if(texid == 3)
					{
						col = tex2D(_RightTex, uv);
						//col = fixed4(0,0,1,1);
					}
					else if(texid == 4)
					{
						col = tex2D(_BackTex, uv);
						//col = fixed4(1,0,0,1);
					}
					else if(texid == 5)
					{
						col = tex2D(_TopTex, uv);
						//col = fixed4(0,1,0,1);
					}
					else if(texid == 6)
					{
						col = tex2D(_BottomTex, uv);
						//col = fixed4(0,0,1,1);
					}
				}
				//i.uv.y = 1 - i.uv.y;
				//i.uv.x = i.uv.x * 3;
				//float y = i.uv.y;
				//float x = frac(i.uv.x);
				////float theta = atan(1. / ((x*2.)-1.));
				//float2 uv2 = float2(x, y);
				//fixed4 col;
				//if(i.uv.x > 2)
				//{
				//	col = tex2D(_RightTex, uv2);
				//} 
				//else if(i.uv.x > 1)
				//{
				//	col = tex2D(_FrontTex, uv2);
				//}
				//else
				//{
				//	col = tex2D(_LeftTex, uv2);
				//}
				//col.xy = i.uv;
				//col.z = 0;
				col.xyz = col.xyz * cart.w;
				return col;
			}
			ENDCG
		}
	}
}
